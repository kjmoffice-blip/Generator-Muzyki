"""Import a human-readable music collection; never execute document content."""
from pathlib import Path
import re
import unicodedata
import uuid
import zipfile
import xml.etree.ElementTree as ET
from validation import validate_request

MAX_TEXT = 5_000_000
MAX_SONGS = 1000

def plain(value):
    value = str(value).replace("ł", "l").replace("Ł", "L")
    return "".join(c for c in unicodedata.normalize("NFKD", value) if not unicodedata.combining(c)).strip().lower()

KEYS = {
    "tytul": "title", "brzmienie i styl": "caption", "styl": "caption", "tekst": "lyrics",
    "dlugosc": "duration", "jezyk": "language", "wokal": "voice", "bpm": "bpm",
    "format": "format", "jakosc mp3": "bitrate", "kroki": "steps", "ziarno": "seed",
    "planowanie": "thinking", "wzorzec": "reference_audio", "kolekcja": "collection",
}
LANGUAGES = {"polski": "pl", "angielski": "en", "niemiecki": "de", "hiszpanski": "es",
             "francuski": "fr", "wloski": "it"}

def duration_seconds(value):
    text = str(value).strip()
    if ":" in text:
        parts = text.split(":")
        if len(parts) != 2 or not all(p.isdigit() for p in parts) or int(parts[1]) >= 60:
            raise ValueError("Długość zapisz jako minuty:sekundy, np. 03:00.")
        return int(parts[0]) * 60 + int(parts[1])
    return float(text)

def normalize_song(fields, base_dir=None):
    raw = dict(fields)
    voice = plain(raw.pop("voice", "dowolny"))
    voices = {"meski": "Warm expressive male lead vocal, clear diction.",
              "kobiecy": "Expressive female lead vocal, clear diction.",
              "mlody meski": "Bright youthful adult male lead vocal, clear diction.",
              "dowolny": "", "tak": "", "nie": "", "bez": "", "instrumentalny": ""}
    if voice not in voices:
        raise ValueError("Wokal: wybierz męski, kobiecy, młody męski, dowolny lub instrumentalny.")
    raw["instrumental"] = voice in {"nie", "bez", "instrumentalny"}
    if not str(raw.get("caption", "")).strip():
        raise ValueError("Brakuje opisu brzmienia i stylu.")
    raw["caption"] = (raw.get("caption", "") + " " + voices[voice]).strip()
    raw["duration"] = duration_seconds(raw.get("duration", 90))
    if raw["duration"] > 300:
        raise ValueError("Ta wersja obsługuje utwory do 05:00.")
    raw["language"] = LANGUAGES.get(plain(raw.get("language", "pl")), plain(raw.get("language", "pl")))
    if "thinking" in raw:
        value = plain(raw["thinking"])
        if value not in {"tak", "nie", "true", "false"}:
            raise ValueError("Planowanie: wpisz tak albo nie.")
        raw["thinking"] = value in {"tak", "true"}
    if raw.get("reference_audio"):
        path = Path(raw["reference_audio"].strip().strip('"')).expanduser()
        if not path.is_absolute() and base_dir is not None:
            path = Path(base_dir) / path
        raw["reference_audio"] = str(path)
    if not str(raw.get("title", "")).strip():
        raise ValueError("Brakuje tytułu.")
    if not raw["instrumental"] and not str(raw.get("lyrics", "")).strip():
        raise ValueError("Brakuje tekstu piosenki. Dla utworu bez wokalu wpisz WOKAL: instrumentalny.")
    normalized = validate_request(raw)
    normalized["voice"] = voice
    return normalized

def parse_plan_text(text, base_dir=None):
    if not isinstance(text, str) or len(text) > MAX_TEXT:
        raise ValueError("Lista jest za duża (maksymalnie 5 milionów znaków).")
    lines = text.lstrip("\ufeff").replace("\r\n", "\n").splitlines()
    if not lines or lines[0].strip() != "SOS MUSIC PLAN 1":
        raise ValueError("Lista musi zaczynać się od SOS MUSIC PLAN 1. Użyj dołączonego wzoru.")
    defaults, blocks = {}, []
    current = None
    multiline = None
    collection = "Moja kolekcja"
    for number, line in enumerate(lines[1:], 2):
        marker = plain(line)
        if re.fullmatch(r"===\s*utwor(?:\s+\d+)?\s*===", marker):
            if current is not None:
                raise ValueError(f"Wiersz {number}: poprzedni utwór nie ma znacznika końca.")
            if len(blocks) >= MAX_SONGS:
                raise ValueError("Jedna lista może zawierać do 1000 utworów.")
            current = {}; multiline = None
            continue
        if marker == "=== koniec utworu ===":
            if current is None:
                raise ValueError(f"Wiersz {number}: znacznik końca bez początku utworu.")
            blocks.append(current); current = None; multiline = None
            continue
        if not line.strip() and multiline is None:
            continue
        target = current if current is not None else defaults
        if multiline == "lyrics":
            target[multiline] += "\n" + line
            continue
        match = re.match(r"^([^:]+):\s*(.*)$", line)
        key = KEYS.get(plain(match.group(1))) if match else None
        if key:
            value = match.group(2)
            if current is None and blocks:
                raise ValueError(f"Wiersz {number}: ustawienia wspólne umieść przed pierwszym utworem.")
            if key == "collection":
                if current is not None:
                    raise ValueError(f"Wiersz {number}: nazwę kolekcji umieść na początku pliku.")
                collection = value.strip() or collection
                continue
            if key in target:
                raise ValueError(f"Wiersz {number}: powtórzone pole {match.group(1)}.")
            target[key] = value
            multiline = key if key in {"caption", "lyrics"} else None
        elif multiline == "caption":
            target["caption"] += "\n" + line
        elif line.strip():
            raise ValueError(f"Wiersz {number}: nierozpoznana sekcja. Sprawdź instrukcję formatu listy.")
    if current is not None:
        raise ValueError("Ostatni utwór nie ma znacznika === KONIEC UTWORU ===.")
    if not blocks:
        raise ValueError("Lista nie zawiera żadnego utworu.")
    songs, titles = [], set()
    for index, block in enumerate(blocks, 1):
        try:
            fields = {**defaults, **block}
            normalized = normalize_song(fields, base_dir)
            title = normalized["title"].casefold()
            if title in titles:
                raise ValueError("Tytuł powtarza się w tej kolekcji. Nadaj utworom różne tytuły.")
            titles.add(title)
            songs.append({"id": str(uuid.uuid4()), "spec": normalized, "state": "waiting", "attempts": 0})
        except (ValueError, TypeError) as error:
            raise ValueError(f"Utwór {index}: {error}") from None
    return {"id": str(uuid.uuid4()), "title": collection, "items": songs}

def load_plan_file(filename):
    path = Path(filename).expanduser().resolve()
    if not path.is_file() or path.stat().st_size > 20_000_000:
        raise ValueError("Wybierz dostępny plik TXT lub DOCX o rozmiarze do 20 MB.")
    if path.suffix.lower() == ".docx":
        try:
            with zipfile.ZipFile(path) as archive:
                member = archive.getinfo("word/document.xml")
                if member.file_size > 10_000_000:
                    raise ValueError("Dokument Word jest za duży.")
                document = ET.fromstring(archive.read(member))
            ns = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
            paragraphs = []
            for paragraph in document.iter(ns + "p"):
                paragraphs.append("".join(node.text or "" if node.tag == ns + "t" else "\n" if node.tag in {ns + "br", ns + "cr"} else "\t" if node.tag == ns + "tab" else "" for node in paragraph.iter()))
            text = "\n".join(paragraphs)
        except (zipfile.BadZipFile, KeyError, ET.ParseError):
            raise ValueError("Nie można odczytać dokumentu Word. Zapisz listę jako TXT UTF-8 lub poprawny DOCX.") from None
    elif path.suffix.lower() == ".txt":
        try:
            text = path.read_text(encoding="utf-8-sig")
        except UnicodeError:
            raise ValueError("Zapisz plik TXT w kodowaniu UTF-8.") from None
    else:
        raise ValueError("Obsługiwane są pliki TXT i DOCX.")
    return parse_plan_text(text, path.parent)

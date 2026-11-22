import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile
from xml.sax.saxutils import escape

BRIDGE = Path(__file__).resolve().parents[1] / "Bridge"
sys.path.insert(0, str(BRIDGE))
from plan import parse_plan_text, load_plan_file
from library import save_song, find_completed_job
from generator import generate
from validation import validate_request

def document(count=2):
    prefix = "SOS MUSIC PLAN 1\nKOLEKCJA: Kolekcja testowa\nDŁUGOŚĆ: 03:00\nWOKAL: instrumentalny\nJĘZYK: polski\nBPM: 128\n"
    return prefix + "\n".join(f"=== UTWÓR {i:03d} ===\nTYTUŁ: Utwór {i}\nBRZMIENIE I STYL:\nClub dance, deep bass\nTEKST:\n=== KONIEC UTWORU ===" for i in range(1, count+1))

class PlanTests(unittest.TestCase):
    def test_hundred_songs_inherit_defaults_and_override(self):
        text = document(100).replace("TYTUŁ: Utwór 2\n", "TYTUŁ: Utwór 2\nDŁUGOŚĆ: 05:00\n")
        result = parse_plan_text(text)
        self.assertEqual(len(result["items"]), 100)
        self.assertEqual(result["items"][0]["spec"]["duration"], 180)
        self.assertEqual(result["items"][1]["spec"]["duration"], 300)
        self.assertEqual(len({item["id"] for item in result["items"]}), 100)

    def test_vocal_lyrics_and_sections_preserved(self):
        text = document(1).replace("WOKAL: instrumentalny", "WOKAL: kobiecy").replace("TEKST:\n", "TEKST:\n[Verse 1]\nTo jest nasz tekst\n\n[Chorus]\nNasz refren\n")
        spec = parse_plan_text(text)["items"][0]["spec"]
        self.assertFalse(spec["instrumental"])
        self.assertIn("female lead", spec["caption"])
        self.assertIn("[Chorus]\nNasz refren", spec["lyrics"])
        self.assertEqual(spec["language"], "pl")

    def test_invalid_plan_is_not_partly_imported(self):
        cases = [document().replace("TYTUŁ: Utwór 2", "TYTUŁ: Utwór 1"),
                 document().replace("03:00", "05:01"), document().replace("03:00", "03:99"),
                 document().replace("=== KONIEC UTWORU ===", "", 1),
                 document().replace("WOKAL: instrumentalny", "WOKAL: męski"),
                 document().replace("BPM: 128", "BPM: 128\nBPM: 90"),
                 document().replace("BRZMIENIE I STYL:\nClub dance, deep bass", "BRZMIENIE I STYL:\n"),
                 "not a collection"]
        for text in cases:
            with self.subTest(text=text[:80]), self.assertRaises(ValueError): parse_plan_text(text)

    def test_word_and_text_produce_same_specs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); text = document()
            txt = root / "plan.txt"; txt.write_text(text)
            paragraphs = "".join("<w:p><w:r><w:t>"+escape(line)+"</w:t></w:r></w:p>" for line in text.splitlines())
            docx = root / "plan.docx"
            with zipfile.ZipFile(docx, "w") as z:
                z.writestr("word/document.xml", '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>'+paragraphs+'</w:body></w:document>')
            self.assertEqual([i["spec"] for i in load_plan_file(txt)["items"]], [i["spec"] for i in load_plan_file(docx)["items"]])

    def test_relative_reference_and_cli_large_import(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); (root / "ref.mp3").write_bytes(b"audio")
            p = root / "plan.txt"; p.write_text(document(100).replace("BPM: 128", "BPM: 128\nWZORZEC: ref.mp3"))
            self.assertEqual(load_plan_file(p)["items"][0]["spec"]["reference_audio"], str((root / "ref.mp3").resolve()))
            # Larger than the old single-song bridge limit of 100 KB.
            text = document(100).replace("Club dance, deep bass", "Club dance, deep bass " * 100)
            self.assertGreater(len(text), 100000)
            result = subprocess.run([sys.executable, str(BRIDGE / "bridge.py"), "--root", temporary],
                input=json.dumps({"command":"import_plan", "text":text})+"\n", capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout)
            event = json.loads(result.stdout.removeprefix("ACE_EVENT "))
            self.assertEqual(len(event["plan"]["items"]), 100)

    def test_committed_queue_job_is_recovered_without_engine(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); audio = root / "generated.mp3"; audio.write_bytes(b"completed audio")
            request = validate_request({"title":"Recovered", "caption":"Club", "job_id":"job-123"})
            saved = save_song(root, request, audio)
            self.assertEqual(find_completed_job(root, "job-123")["id"], saved["id"])
            with patch("generator.fetch_schema", side_effect=AssertionError("Engine must not be contacted")):
                recovered = generate(root, "http://127.0.0.1:7861", request, lambda **kw: None)
            self.assertEqual(recovered["id"], saved["id"])
            self.assertEqual(len(list((root / "Piosenki").glob("*/song.json"))), 1)
            Path(saved["audioPath"]).unlink()
            self.assertIsNone(find_completed_job(root, "job-123"))

if __name__ == "__main__": unittest.main()

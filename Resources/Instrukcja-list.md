# Listy do Generatora Muzyki · SOS DIGITAL . PRO

To instrukcja dla użytkownika i asystenta przygotowującego kolekcje. Generator 3 zawiera silnik ACE-Step i modele wewnątrz aplikacji. Format list pozostaje zgodny z wersją 2.

## Jak przygotować plik

Zapisz zwykły tekst UTF-8 z rozszerzeniem .txt albo dokument .docx zawierający ten sam tekst. W Wordzie wystarczą zwykłe akapity. Nie używaj pliku .doc, PDF ani tabel zamiast opisanej struktury.

Pierwszy wiersz musi brzmieć dokładnie `SOS MUSIC PLAN 1`. Kolejne ustawienia przed pierwszym utworem są wspólne dla całej kolekcji. Każdy utwór może nadpisać je swoimi ustawieniami. Wszystkie ustawienia utworu umieść przed jego tekstem. Nie doklejaj objaśnień ani znaczników Markdown do pliku importowanego.

```text
SOS MUSIC PLAN 1
KOLEKCJA: Bluesowe wieczory
DŁUGOŚĆ: 03:00
JĘZYK: polski
WOKAL: męski
BPM: 78
FORMAT: mp3
JAKOŚĆ MP3: 192k
KROKI: 8
PLANOWANIE: tak

=== UTWÓR 001 ===
TYTUŁ: Światło po deszczu
BRZMIENIE I STYL:
Emotional blues rock, expressive electric guitar, singing lead guitar bends, warm bass and live drums, warm male lead singing clearly in Polish, memorable chorus and resolved ending.
TEKST:
[Verse 1]
Tutaj wpisz pełną autorską zwrotkę.

[Chorus]
Tutaj wpisz pełny autorski refren.
=== KONIEC UTWORU ===

=== UTWÓR 002 ===
TYTUŁ: Nocne światła
DŁUGOŚĆ: 05:00
WOKAL: instrumentalny
BRZMIENIE I STYL:
Slow expressive blues rock instrumental, melodic electric guitar solos, warm bass, restrained live drums, dynamic build and natural ending.
TEKST:
=== KONIEC UTWORU ===
```

Powyższe zdania zastępcze w sekcji TEKST są tylko objaśnieniami wzoru. Przy tworzeniu właściwej kolekcji należy zastąpić je pełnym tekstem piosenki.

## Obsługiwane pola

- `KOLEKCJA`: nazwa całej listy, tylko przed pierwszym utworem.
- `TYTUŁ`: wymagany, unikalny dla każdej pozycji, maksymalnie 160 znaków.
- `DŁUGOŚĆ`: od 00:10 do 05:00. Najprościej używać 01:30, 03:00, 04:00 lub 05:00. To parametr generacji; ilość tekstu trzeba dobrać do czasu.
- `JĘZYK`: polski, angielski, niemiecki, hiszpański, francuski, włoski albo właściwy kod, np. pl lub en.
- `WOKAL`: męski, kobiecy, młody męski, dowolny lub instrumentalny. Dla instrumentalnego pole TEKST może być puste. Określenie wokalu jest wskazówką dla modelu.
- `BPM`: 30–300 albo 0 dla automatycznego tempa.
- `BRZMIENIE I STYL`: wymagany opis gatunku, instrumentów, nastroju, sposobu śpiewania, struktury i zakończenia. Może mieć kilka wierszy.
- `TEKST`: pełne słowa piosenki, z sekcjami typu [Verse 1], [Chorus], [Bridge], [Outro]. Program nie dopisuje brakujących tekstów.
- `FORMAT`: mp3, wav lub flac. `JAKOŚĆ MP3`: np. 192k lub 320k.
- `KROKI`: 1–20; dla obecnego modelu turbo zalecane 8.
- `ZIARNO`: -1 dla losowania albo liczba 0–2147483647.
- `PLANOWANIE`: tak albo nie.
- `WZORZEC`: opcjonalna ścieżka do MP3, WAV, FLAC, M4A lub AIFF. W pliku może być względna wobec dokumentu; we wklejonym tekście powinna być pełna. Plik musi być dostępny na Macu.

Nazwy pól można zapisać bez polskich znaków. Nie powtarzaj tego samego pola w obrębie jednego utworu. Każdy utwór musi kończyć się osobnym wierszem `=== KONIEC UTWORU ===`.

## Zlecenie dla asystenta tworzącego kolekcję

Przygotuj jeden dokument zgodny z SOS MUSIC PLAN 1. Liczba pozycji, temat, gatunek, długość, język i rodzaj wokalu mają odpowiadać zleceniu użytkownika. Każdy utwór powinien mieć odrębny tytuł i autorski tekst albo być jawnie oznaczony jako instrumentalny. Zadbaj o różnorodność melodii sugerowanej opisem, nastroju i treści. Nie zastępuj pełnych tekstów wielokropkami. Dla dłuższych utworów uwzględnij przejścia instrumentalne, mostek lub solo. Nie umieszczaj instrukcji dla użytkownika wewnątrz sekcji TEKST.

## Import i uruchomienie

1. W zakładce Kolekcja wybierz „Wczytaj TXT / Word” lub „Wklej listę”.
2. Po imporcie sprawdź tytuły i ustawienia; przyciskiem Podgląd zobaczysz pełny styl oraz tekst.
3. Przed pierwszym startem wybierz folder. Jest on zapamiętywany dla tej kolekcji, aby wznowienie trafiało do tego samego miejsca.
4. Kliknij „Generuj całą kolejkę”. Utwory powstają pojedynczo.
5. „Pauza po utworze” kończy i zapisuje bieżącą pozycję, a potem zatrzymuje kolejkę. „Wznów kolejkę” pomija ukończone pozycje.
6. Domyślnie błąd wstrzymuje kolejkę. Po usunięciu przyczyny wybierz „Ponów” przy pozycji lub „Ponów błędy”, a następnie Wznów.

Postęp jest automatycznie zapisywany w `~/Library/Application Support/SOS Digital/Generator Muzyki/Kolejki`. Po ponownym otwarciu program odtwarza ostatnią kolekcję, ale sam nie rozpoczyna generacji. W menu Więcej można przywrócić inną zapisaną kolejkę. Import kolejnej listy nie usuwa poprzedniej.

Nowe nagrania trafiają bezpośrednio do wybranego folderu. Po ukończeniu kolekcji bez błędów program czeka 30 sekund i usuwa wyłącznie własne, niezmienione pliki pomocnicze, pozostawiając audio. Dane do wznowienia pozostają w prywatnym katalogu aplikacji. Starsze kolekcje zachowują poprzedni układ plików. Wskaźnik dysku ostrzega poniżej 5%, a przy 1% lub mniej wstrzymuje pracę. Szczegóły i raport są dostępne w aplikacji.

Gotowy i zapisany wynik ma identyfikator pozycji kolejki. Przy ponowieniu silnik najpierw sprawdza, czy taki wynik już istnieje. Gdy proces zostanie przerwany przed trwałym zapisaniem wyniku, obliczenia tej pozycji mogą wymagać powtórzenia. Usuń przyczynę braku dysku lub pliku wzorcowego przed wznowieniem.

Jedna lista może zawierać do 1000 utworów; limit treści to 5 milionów znaków. Duże kolekcje wymagają odpowiedniego czasu oraz miejsca na dysku. Podczas pracy aplikacja blokuje automatyczne usypianie systemu; ekran może się wygasić. Nie wyłączaj Maca i nie usypiaj go ręcznie podczas pracy. Do bezpiecznego zamknięcia najpierw użyj pauzy po bieżącym utworze.

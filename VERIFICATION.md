# Weryfikacja źródeł do publikacji — 22 listopada 2026

- Źródło: archiwum źródeł Generatora Muzyki 3.0.0 z SSD. Wszystkie pliki `Bridge/*.py` porównano bajt po bajcie z pakietem aplikacji na SSD — zgodne. Katalogi `Sources/` i `EngineOverlay/` zachowano bez zmian.
- `python3 build.py --preview`: **PASS**, rzeczywista kompilacja binarnego interfejsu arm64 z celem macOS 14. Kompilator SwiftUI wymagał uruchomienia poza sandboxem narzędzia. Nie instalowano ani nie uruchamiano aplikacji użytkownika.
- Python unittest: **24/24 PASS**, bez pominięć po udostępnieniu istniejących narzędzi FFmpeg/ffprobe wyłącznie w ignorowanym katalogu build. Sprawdzono rzeczywisty MP3 z syntetycznego sygnału, zapis, odtworzenie wyniku, ochronę obcych/zmienionych plików i selektywne sprzątanie. Testy AI używają adapterów zastępczych — model nie generował muzyki.
- `python3 Scripts/test_native.py`: **PASS** — trzy programy Swift (stan aplikacji, kolejka, progi dysku, kontrolowane zatrzymanie własnego procesu, termin sprzątania i raport) oraz test C (rzeczywista pamięć procesu potomnego i prywatny port).
- Test pięciu ścieżek overlay: **PASS**, własny katalog wyjściowy oraz domyślne zachowanie upstream, także po dwukrotnym zastosowaniu poprawki.
- Licencje: sprawdzono oficjalne strony ACE-Step, modeli ACE-Step, Qwen, Python i FFmpeg. Zachowano oryginalne teksty, źródła audio i inwentarz zależności. Własna warstwa jest udostępniana na MIT.
- Kontrola publikacji: osobna kopia, bez historii roboczego projektu, kolekcji użytkownika, nagrań, raportów produkcyjnych, logów, modeli, binariów runtime, certyfikatów i profili podpisywania. Sprawdzenie wzorców sekretów, danych kont użytkownika i zakazanych rozszerzeń — bez trafień. Sygnaturę wydawcy zastąpiono konfiguracją środowiskową w skryptach pakowania. Licencyjne nazwiska/autorzy bibliotek są atrybucją upstream.

## Ograniczenia

Nie odtwarzano całego środowiska ML od zera i nie wykonywano nowej generacji ani odsłuchu. Testy dotyczą obecnego Maca Apple Silicon; nie dowodzą zgodności Intel/Windows, minimalnego RAM ani wszystkich wersji macOS. Nie wykonywano nowego podpisania, DMG ani notaryzacji. Stara ścieżka SSD pozostaje wyłącznie w niezmienionej historycznej migracji kolejek i historycznych materiałach licencyjnych konfiguracji audio; nie jest wymagana do świeżej instalacji.

`requirements-runtime-lock.txt` jest inwentarzem historycznego środowiska. Nie potwierdzono ponownie dostępności wszystkich pakietów i kompletu wag do pobrania. Sprawdzenie wzorców sekretów jest kontrolą przygotowanego zestawu, nie gwarancją matematyczną.

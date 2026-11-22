# Generator Muzyki 3.0.0

Polskojęzyczna aplikacja **macOS na Apple Silicon**, z interfejsem SwiftUI i lokalnym silnikiem **ACE-Step 1.5**. Tworzy muzykę z opisu i tekstu, importuje kolekcje TXT/DOCX, prowadzi wznawialną kolejkę, zapisuje MP3 i raporty oraz udostępnia bibliotekę i odtwarzacz.

To źródła wersji Mac 3.0.0. Windows wymaga osobnego portu; nie ma tu gotowej ani przetestowanej wersji Windows lub Intel. Repozytorium nie zawiera gotowego instalatora, środowiska Python, wag modeli ani nagrań użytkownika.

## Funkcje

- Ręczne generowanie i import `SOS MUSIC PLAN 1`, wzorzec audio, presety i zegary.
- Trwała kolejka, zatrzymanie po utworze, wznowienie oraz ochrona przed nadpisaniem.
- Płaski eksport MP3, selektywne sprzątanie własnych plików pomocniczych po 30 sekundach i raporty HTML/JSON.
- Pomiar pamięci aplikacji i silnika, kontrola dysku, ostrzeganie poniżej 5% i zatrzymanie własnego silnika przy 1% lub mniej.
- Lokalny serwer związany z `127.0.0.1`. Cache i stan są zapisywane poza pakietem aplikacji.

## Wymagania i kod

Apple Silicon, macOS 14+ (cel kompilacji), Xcode Command Line Tools oraz Python **3.12** do skryptów i testów. Pełne generowanie wymaga również środowiska ACE-Step, FFmpeg/ffprobe i około **10,1 GB samych modeli**. Zużycie RAM zależy od zadania; dawne wydanie sprawdzano na Macu z 48 GB RAM, nie ustalono tutaj minimalnej pamięci.

| Katalog | Zawartość |
|---|---|
| `Sources/` | SwiftUI, kolejka, odtwarzacz, monitor zasobów oraz C do pomiarów systemu |
| `Bridge/` | Python: protokół JSON, Gradio, parser, zapis i porządkowanie |
| `EngineOverlay/`, `EngineOverlay.patch` | Pięć zmienionych plików ACE-Step i patch względem przypiętego commitu |
| `Tests/` | Testy importu, kolejki, eksportu, bezpieczeństwa i procesów |
| `Resources/` | Oryginalna ikona, instrukcje, przykładowa lista i licencje |
| `Scripts/` | Przygotowanie runtime, pobieranie modeli, budowanie audio i opcjonalne podpisywanie |

## Budowanie interfejsu i testy

```sh
python3 build.py --preview
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tests -p 'test_*.py' -v
```

Pierwsze polecenie kompiluje interfejs do `build/Generator Muzyki.app`. **Nie instaluje silnika ani modeli**; sama taka aplikacja nie wygeneruje muzyki. `--preview` używa osobnego identyfikatora i stanu do prób. Do testów natywnych:

```sh
python3 Scripts/test_native.py
```

Testy eksportu są pomijane, jeżeli nie ma `ffmpeg` i `ffprobe` w `build/Generator Muzyki.app/Contents/Resources/Runtime/Tools`. Wszystkie testy są lokalne; nie uruchamiają modelu generatywnego. Ich wynik nie dowodzi jakości ani długości wygenerowanej piosenki.

## Pełny runtime do generowania

`Scripts/prepare_runtime.py` jest narzędziem pakowania **już przygotowanego środowiska**, a nie automatycznym instalatorem zależności. Układ wejściowy opisano w [BUILDING.md](BUILDING.md). Ścieżkę wybiera `SOS_MUSIC_SOURCE`; domyślnie jest to `dependencies/ACE` w checkoutcie.

Silnik: [ace-step/ACE-Step-1.5](https://github.com/ace-step/ACE-Step-1.5), commit `ca1e85fe9430179831e6bc6be790c332190a3866`. Zastosowanie pięciu poprawek ścieżek realizuje `prepare_runtime.py`. Pełne kopie tych plików znajdują się w `EngineOverlay/`.

Modele: [ACE-Step/Ace-Step1.5](https://huggingface.co/ACE-Step/Ace-Step1.5), rewizja `19671f406d603126926c1b7e2adc169acbcade22`. Zestaw obejmuje turbo, LM 1.7B, VAE i Qwen3-Embedding-0.6B. Pobieranie bez zmiany istniejących różnych plików i kontrola 28 sum SHA-256:

```sh
python3 Scripts/download_models.py --engine-root dependencies/ACE/Silnik
python3 Scripts/download_models.py --engine-root dependencies/ACE/Silnik --verify-only
```

`requirements-runtime-lock.txt` i `Resources/Licenses/Python-packages.json` dokumentują konkretne historyczne środowisko Mac. Nie są uniwersalnym lockfile dla Windows/Intel ani gwarancją, że wszystkie wheel pozostaną dostępne. Odtworzenie pełnego runtime od zera nie zostało sprawdzone podczas publikacji.

## Obsługa

Po skompletowaniu runtime uruchom własną kompilację z `build/Generator Muzyki.app`. Instrukcja: [Resources/Instrukcja.txt](Resources/Instrukcja.txt); format kolekcji: [Resources/Instrukcja-list.md](Resources/Instrukcja-list.md). Stan produkcyjny trafia do `~/Library/Application Support/SOS Digital/Generator Muzyki`; tryb preview ma osobną lokalizację. Historyczna migracja kolejek zachowuje dawną ścieżkę SSD; nie jest potrzebna do nowej instalacji.

## Licencje

Własna warstwa aplikacji: [MIT](LICENSE), © 2026 Krzysztof Mozdzen / SOS DIGITAL . PRO. MIT pozwala także na sprzedaż, a odbiorcom na kopiowanie, modyfikowanie i dalszą dystrybucję zgodnie z licencją.

Cudze składniki zachowują własne warunki: ACE-Step i jego modele — MIT; Qwen3-Embedding — Apache-2.0; Python — PSF i towarzyszące licencje; FFmpeg/LAME — LGPL w opisanej konfiguracji. **MIT aplikacji nie zastępuje tych licencji.** Zobacz [THIRD_PARTY.md](THIRD_PARTY.md) i `Resources/Licenses/`. Wagi pobierane są z oficjalnego repozytorium, nie są publikowane tutaj.

## Weryfikacja publikacji

Aktualne wykonane kontrole i ograniczenia: [VERIFICATION.md](VERIFICATION.md). Publikacja kodu nie jest nowym wydaniem binarnym, notaryzacją ani potwierdzeniem działania na innych komputerach. Nie zmieniono wersji, interfejsu ani logiki generowania aplikacji.

Oryginalne katalogi licencji `Python/`, `Supplemental/` oraz źródła uzupełniające `Sources/Python/` są zachowane bez zmian w `Resources/Licenses/Dependency-notices.zip` (ścieżki względem `Resources/Licenses`). Rozpakuj archiwum w tym katalogu, aby czytać ścieżki z historycznego inwentarza. Nie są to biblioteki wykonywalne.

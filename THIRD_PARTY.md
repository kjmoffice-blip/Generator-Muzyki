# Składniki zewnętrzne

Sprawdzono oficjalne strony 22 listopada 2026. Licencja MIT w katalogu głównym dotyczy własnej warstwy aplikacji; nie zmienia warunków poniższych składników.

| Składnik | Licencja i źródło | Zakres repozytorium |
|---|---|---|
| ACE-Step 1.5 | [MIT](https://github.com/ace-step/ACE-Step-1.5/blob/main/LICENSE) | Pięć plików overlay + patch; oryginalny copyright w `Resources/Licenses/ACE-Step-MIT.txt`. Bazowy commit `ca1e85fe9430179831e6bc6be790c332190a3866`. |
| ACE-Step/Ace-Step1.5 | [Karta modelu, MIT](https://huggingface.co/ACE-Step/Ace-Step1.5/blob/main/README.md) | Wagi nie są dołączone. Skrypt pobiera rewizję `19671f406d603126926c1b7e2adc169acbcade22` i weryfikuje manifest. |
| Qwen3-Embedding-0.6B | [Apache-2.0](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B) | Tekst licencji `Qwen-Apache-2.0.txt`. Encoder pobierany jest jako część przypiętego zestawu ACE-Step. |
| Python | [PSF i licencje składników](https://docs.python.org/3/license.html) | Interpreter nie jest dołączony; historyczne licencje i build ID zachowano. |
| FFmpeg 9.0.2 / LAME 4.0 | [LGPL-2.1-or-later w opisanej konfiguracji](https://www.ffmpeg.org/legal.html) | Źródła, sumy, skrypt i opcje kompilacji bez GPL/nonfree. Brak binariów. GPL/nonfree w innej konfiguracji zmienia obowiązki. |
| Biblioteki Python / MLX / PyTorch / Gradio i pozostałe | Własne licencje według inwentarza | `Python-packages.json`, `Python/`, `Supplemental/`, lockfile. To historyczny inwentarz wydania 3.0.0; biblioteki nie są dołączone. |

Overlay zmienia wyłącznie pięć domyślnych ścieżek wyników tak, by respektowały `SOS_MUSIC_ENGINE_OUTPUT`. Bez tej zmiennej upstream zachowuje swoje domyślne katalogi. Test obejmuje każdą ścieżkę i powtórne zastosowanie poprawki.

W publicznej kopii skrypty pakowania korzystają ze zmiennych środowiskowych zamiast osobistych ścieżek i tożsamości podpisu. Test ścieżek korzysta z dołączonego overlay zamiast prywatnego dysku. Pozostały kod aplikacji i bridge zachowano bez zmian.

Nazwy/znaki towarowe i prawa do materiałów dostarczanych do modelu są odrębnymi kwestiami. Zachowaj informacje o autorach i wymagane licencje przy dalszej dystrybucji. MIT pozwala sprzedawać własną aplikację, ale nie daje wyłączności i nie zastępuje praw do cudzych składników lub nagrań.

Oryginalne katalogi licencji `Python/`, `Supplemental/` oraz źródła uzupełniające `Sources/Python/` są zachowane bez zmian w `Resources/Licenses/Dependency-notices.zip` (ścieżki względem `Resources/Licenses`). Rozpakuj archiwum w tym katalogu, aby czytać ścieżki z historycznego inwentarza. Nie są to biblioteki wykonywalne.

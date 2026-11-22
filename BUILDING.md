# Przygotowanie kompletnej aplikacji Mac

Kod interfejsu można kompilować bez modeli (README). Pełna generacja wymaga przygotowania wejściowego katalogu środowiska. Nie kopiuj katalogów użytkownika, cache, nagrań ani sekretów do runtime.

```text
dependencies/ACE/
  Silnik/
    acestep/ assets/ examples/ docs/ checkpoints/
    LICENSE README.md pyproject.toml AGENTS.md
    .venv/lib/python3.12/site-packages/
    .venv/bin/ffmpeg
  Runtime/python/
    bin/python3.12
    lib/python3.12/
    BUILD
```

1. Pobierz oficjalny ACE-Step do `dependencies/ACE/Silnik` i wybierz commit `ca1e85fe9430179831e6bc6be790c332190a3866`. Nie aktualizuj samowolnie do `main`: adapter i overlay dotyczą tej konkretnej wersji. Zachowaj upstream LICENSE.
2. Przygotuj relokowalny interpreter Python 3.12 dla macOS arm64 w `Runtime/python`. Wydanie historyczne używało Python 3.12.16 (python-build-standalone, identyfikator build zapisany w `Resources/Licenses/Python-build.txt`). Zwykły symlink do systemowego Pythona nie tworzy niezależnego runtime.
3. Zainstaluj zależności silnika dla tego interpretera w `Silnik/.venv/lib/python3.12/site-packages`, bazując na `requirements-runtime-lock.txt` i oficjalnych instrukcjach przypiętego ACE-Step. Sprawdź zgodność MLX/PyTorch/TorchCodec z macOS arm64. Nie są tu dystrybuowane wheel. Runtime wymaga dostępnego tymczasowego `Silnik/.venv/bin/ffmpeg`; później skrypt zastępuje go własną kompilacją LGPL.
4. Pobierz i zweryfikuj modele poleceniami z README. Skrypt używa przypiętej rewizji i manifestu SHA-256.
5. Przygotuj pakiet:

```sh
SOS_MUSIC_SOURCE="$PWD/dependencies/ACE" python3 Scripts/prepare_runtime.py
python3 -m pip install --target build/build-tools pkgconf==3.0.7.post0
python3 Scripts/build_audio_tools.py
python3 build.py --preview
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tests -p 'test_*.py' -v
python3 Scripts/test_native.py
```

Źródła FFmpeg/LAME i ich dokładne sumy oraz opcje kompilacji zachowano w `Resources/Licenses/`. Skrypt audio wymaga narzędzi `make`, kompilatora, `pkgconf` i obsługi assemblera wymaganej przez wybrany upstream. Nie uruchamiaj kilku kompilacji audio jednocześnie: korzystają z jednego katalogu tymczasowego. `tarfile` z filtrem `data` wymaga Python 3.12+.

Nie wykonano przy publikacji instalacji tego całego środowiska od zera ani nowego generowania ML. Testy eksportu sprawdzają rzeczywisty MP3 z sygnału testowego, nie muzykę modelu. Dawny runtime ma 28 plików modeli i ponad 10 GB wag; kompilacja interfejsu nie potwierdza kompletności runtime.

## Licencje i wydanie binarne

Przed dystrybucją nowego runtime zbierz licencje **rzeczywiście użytych** wersji:

```sh
SOS_MUSIC_ENGINE_REPO="$PWD/dependencies/ACE/Silnik" python3 Scripts/collect_licenses.py
python3 Scripts/supplement_notices.py
python3 build.py
```

`collect_licenses.py` przepisuje historyczny inwentarz. `supplement_notices.py` zawiera przypięte uzupełnienia dawnego zestawu: przy zmianie wersji zależności przejrzyj je ponownie. Zmiany zapisów licencyjnych wymagają ponownego kopiowania Resources przez `build.py`.

Opcjonalne podpisanie i DMG wymagają **własnej** tożsamości Developer ID; skrypty nie wybierają konta autora:

```sh
export CODESIGN_IDENTITY='Developer ID Application: TWOJA TOŻSAMOŚĆ'
python3 Scripts/sign_runtime.py
python3 -m pip install --target build/packaging dmgbuild==1.6.7
python3 package.py
```

Podpis nie jest notaryzacją. Repozytorium nie zawiera profilu Apple, klucza prywatnego, certyfikatu ani biletu Apple. Nie opisuje gotowego nowego wydania. Własne zmodyfikowane buildy należy niezależnie testować, a przed dystrybucją stosować wymagania Apple i licencje składników.

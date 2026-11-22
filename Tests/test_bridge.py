"""Focused validation, live-schema adaptation and library preservation checks."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

BRIDGE = Path(__file__).resolve().parents[1] / "Bridge"
sys.path.insert(0, str(BRIDGE))
from api_mapping import generation_arguments
from library import list_songs, save_song
from validation import validate_request, validate_server


class BridgeTests(unittest.TestCase):
    """Keep invalid input away from generation and preserve existing music."""

    def test_invalid_duration_and_boolean_rejected(self):
        for extra in ({"duration": float("nan")}, {"duration": 601}, {"thinking": "false"},
                      {"bpm": 12}, {"steps": 0}, {"format": "exe"}):
            with self.subTest(extra=extra), self.assertRaises(ValueError):
                validate_request({"caption": "Pop", **extra})

    def test_remote_server_rejected(self):
        self.assertEqual(validate_server("http://localhost:7860/"), "http://localhost:7860")
        for url in ("https://example.com", "http://127.0.0.1@evil.test", "file:///tmp"):
            with self.assertRaises(ValueError):
                validate_server(url)

    def test_mapping_uses_names_not_positions(self):
        labels = ["Think", "Audio Format", "Vocal Language", "Audio Duration (seconds)",
                  "BPM (Beats Per Minute)", "Lyrics", "Music Caption", "Reference Audio"]
        schema = {"parameters": [{"label": label, "parameter_name": f"arg_{i}",
                                   "parameter_has_default": False} for i, label in enumerate(labels)]}
        request = validate_request({"caption": "Acoustic", "instrumental": True})
        mapped = generation_arguments(schema, request)
        self.assertEqual(mapped["arg_6"], "Acoustic")
        self.assertEqual(mapped["arg_5"], "[Instrumental]")
        self.assertIsNone(mapped["arg_4"])
        self.assertIsNone(mapped["arg_7"])
        schema["parameters"].append({"label": "New requirement", "parameter_name": "unknown"})
        with self.assertRaises(ValueError):
            generation_arguments(schema, request)

    def test_optional_boolean_defaults_and_explicit_false_are_preserved(self):
        labels = ["Think", "Audio Format", "Vocal Language", "Audio Duration (seconds)",
                  "BPM (Beats Per Minute)", "Lyrics", "Music Caption"]
        parameters = [{"label": label, "parameter_name": label,
                       "parameter_has_default": False} for label in labels]
        parameters += [
            {"label": "Future optional switch", "parameter_name": "optional_true",
             "parameter_has_default": True, "parameter_default": True},
            {"label": "Second optional switch", "parameter_name": "optional_false",
             "parameter_has_default": True, "parameter_default": False},
            {"label": "AutoGen", "parameter_name": "auto",
             "parameter_has_default": True, "parameter_default": True},
        ]
        request = validate_request({"caption": "Pop", "lyrics": "Polski tekst",
                                    "thinking": False, "instrumental": False})
        mapped = generation_arguments({"parameters": parameters}, request)
        self.assertIs(mapped["Think"], False)
        self.assertEqual(mapped["Lyrics"], "Polski tekst")
        self.assertIs(mapped["optional_true"], True)
        self.assertIs(mapped["optional_false"], False)
        self.assertIs(mapped["auto"], False)

    def test_import_preserves_legacy_and_new_titles_never_overwrite(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old = root / "Piosenki" / "Dotychczasowy"
            old.mkdir(parents=True)
            original = old / "Utwór.mp3"
            original.write_bytes(b"existing audio")
            params = old / "parametry.json"
            params.write_text(json.dumps({"duration": 90, "bpm": 112, "lyrics": "Tekst"}))
            before = {p.name: p.read_bytes() for p in old.iterdir()}
            first = list_songs(root)
            self.assertEqual(first[0]["duration"], 90)
            self.assertEqual(first[0]["id"], list_songs(root)[0]["id"])
            request = validate_request({"title": "Utwór", "caption": "Pop"})
            one = save_song(root, request, original)
            two = save_song(root, request, original)
            self.assertNotEqual(one["id"], two["id"])
            self.assertNotEqual(one["audioPath"], two["audioPath"])
            self.assertEqual(len(list_songs(root)), 3)
            self.assertEqual(before, {p.name: p.read_bytes() for p in old.iterdir()})

    def test_library_symlink_cannot_escape_root(self):
        with tempfile.TemporaryDirectory() as root, tempfile.TemporaryDirectory() as external:
            Path(root, "Piosenki").symlink_to(external)
            with self.assertRaises(ValueError):
                list_songs(root)

    def test_cli_reports_invalid_json_and_library_without_gradio(self):
        with tempfile.TemporaryDirectory() as root:
            command = [sys.executable, str(BRIDGE / "bridge.py"), "--root", root]
            bad = subprocess.run(command, input="{}\n", text=True, capture_output=True)
            self.assertEqual(bad.returncode, 1)
            self.assertIn('"type": "error"', bad.stdout)
            good = subprocess.run(command, input='{"command":"library"}\n',
                                  text=True, capture_output=True)
            self.assertEqual(good.returncode, 0)
            self.assertEqual(json.loads(good.stdout.removeprefix("ACE_EVENT "))["songs"], [])

    def test_selected_folder_saves_and_lists_outside_engine_root(self):
        with tempfile.TemporaryDirectory() as root, tempfile.TemporaryDirectory() as external:
            audio = Path(root, "test.mp3"); audio.write_bytes(b"audio")
            request = validate_request({"title": "Wybrany folder", "caption": "Club"})
            song = save_song(root, request, audio, output_dir=external)
            self.assertTrue(Path(song["audioPath"]).is_relative_to(Path(external).resolve()))
            self.assertEqual(list_songs(root), [])
            self.assertEqual(list_songs(root, external)[0]["id"], song["id"])
            command = [sys.executable, str(BRIDGE / "bridge.py"), "--root", root, "--output-dir", external]
            result = subprocess.run(command, input='{"command":"library"}\n', text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout.removeprefix("ACE_EVENT "))["songs"][0]["id"], song["id"])
            with self.assertRaises(ValueError):
                save_song(root, request, audio, output_dir=Path(external, "missing"))

    def test_reference_file_validation_and_mapping(self):
        with tempfile.TemporaryDirectory() as folder:
            reference = Path(folder, "wzorzec.mp3"); reference.write_bytes(b"test audio")
            request = validate_request({"caption": "Latino", "reference_audio": str(reference)})
            self.assertEqual(request["reference_audio"], str(reference.resolve()))
            saved = save_song(folder, request, reference, {"reference_audio": "/temporary/upload.mp3"})
            params = json.loads((Path(saved["audioPath"]).parent / "parametry.json").read_text())
            self.assertEqual(params["reference_audio"], str(reference.resolve()))
            labels = ["Think", "Audio Format", "Vocal Language", "Audio Duration (seconds)",
                      "BPM (Beats Per Minute)", "Lyrics", "Music Caption", "Reference Audio"]
            schema = {"parameters": [{"label": label, "parameter_name": label} for label in labels]}
            uploaded = {"path": str(reference), "meta": {"_type": "gradio.FileData"}}
            mapped = generation_arguments(schema, {**request, "reference_audio": uploaded})
            self.assertEqual(mapped["Reference Audio"], uploaded)
            for invalid in (str(reference.with_suffix(".exe")), str(Path(folder, "missing.mp3")), "relative.mp3"):
                with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                    validate_request({"caption": "Club", "reference_audio": invalid})


if __name__ == "__main__":
    unittest.main()

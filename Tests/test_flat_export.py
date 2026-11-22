"""Exercise real audio validation, safe flat export, recovery and selective cleanup."""
from pathlib import Path
from unittest.mock import patch
import array
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import uuid
import wave

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "Bridge"))
from cleanup import cleanup_collection
from flat_library import find_flat_job, list_flat, save_flat
from generator import generate
from storage_index import atomic_json, file_hash, read_record, record_path


class FlatExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.audio_temp = tempfile.TemporaryDirectory()
        tools = Path(__file__).resolve().parents[1] / "build/Generator Muzyki.app/Contents/Resources/Runtime/Tools"
        cls.ffmpeg = str(tools / "ffmpeg")
        cls.ffprobe = str(tools / "ffprobe")
        if not Path(cls.ffprobe).is_file():
            raise unittest.SkipTest("Build bundled audio tools before running export tests")
        cls.env = patch.dict(os.environ, {"SOS_MUSIC_FFMPEG":cls.ffmpeg, "SOS_MUSIC_FFPROBE":cls.ffprobe})
        cls.env.start()
        wav = Path(cls.audio_temp.name) / "source.wav"
        samples = array.array("h", [int(6000 * math.sin(2 * math.pi * 440 * n / 48000)) for n in range(48000)])
        with wave.open(str(wav), "wb") as out:
            out.setnchannels(1); out.setsampwidth(2); out.setframerate(48000)
            out.writeframes(samples.tobytes() * 10)
        cls.source = wav.with_suffix(".mp3")
        subprocess.run([cls.ffmpeg,"-v","error","-i",str(wav),"-b:a","192k",str(cls.source)],check=True)

    @classmethod
    def tearDownClass(cls):
        cls.env.stop(); cls.audio_temp.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "private"; self.root.mkdir()
        self.output = Path(self.temp.name) / "music"; self.output.mkdir()

    def request(self, title="Piosenka"):
        return dict(title=title, caption="Warm pop", lyrics="[Verse]\nDzień dobry", duration=10,
                    language="pl", bpm=100, seed=1, job_id=str(uuid.uuid4()))

    def save(self, request):
        return save_flat(self.root, request, self.source, output_dir=self.output)

    def test_flat_cleanup_keeps_audio_user_files_and_recovery(self):
        one, two = self.request(), self.request()
        songs = [self.save(one), self.save(two)]
        foreign = self.output / "moje-notatki.json"; foreign.write_text("user data")
        self.assertFalse(any(p.is_dir() for p in self.output.iterdir()))
        result = cleanup_collection(self.root,self.output,[one['job_id'],two['job_id']])
        self.assertEqual(result['removed'],6)
        self.assertEqual(len(list(self.output.glob('*.mp3'))),2)
        self.assertEqual(foreign.read_text(),"user data")
        self.assertEqual(len(list_flat(self.root,self.output)),2)
        with patch('generator.fetch_schema',side_effect=AssertionError('must not reach engine')):
            restored=generate(self.root,'http://127.0.0.1:1',one,lambda **event:None,
                              output_dir=self.output,flat_output=True)
        self.assertEqual(restored['audioPath'],songs[0]['audioPath'])

    def test_modified_helper_preserves_all_sidecars(self):
        request=self.request(); self.save(request)
        helper=next(self.output.glob('*.tekst.txt')); helper.write_text('edited by user')
        with self.assertRaises(ValueError):cleanup_collection(self.root,self.output,[request['job_id']])
        self.assertEqual(len(list(self.output.iterdir())),4)

    def test_missing_second_audio_does_not_clean_first(self):
        one,two=self.request('One'),self.request('Two');self.save(one);song=self.save(two)
        Path(song['audioPath']).unlink()
        with self.assertRaises((ValueError,OSError)):cleanup_collection(self.root,self.output,[one['job_id'],two['job_id']])
        self.assertEqual(len(list(self.output.glob('*.tekst.txt'))),2)

    def test_forged_registry_cannot_delete_foreign_file(self):
        request=self.request();self.save(request);foreign=self.output/'private.txt';foreign.write_text('keep')
        path=record_path(self.root,self.output,request['job_id']);record=read_record(path)
        record['artifacts'].append({'name':foreign.name,'sha256':file_hash(foreign)});atomic_json(path,record)
        with self.assertRaises(ValueError):cleanup_collection(self.root,self.output,[request['job_id']])
        self.assertEqual(foreign.read_text(),'keep')

    def test_prepared_result_is_recovered_and_committed(self):
        request=self.request();song=self.save(request);path=record_path(self.root,self.output,request['job_id'])
        record=read_record(path);record['state']='prepared';atomic_json(path,record)
        self.assertEqual(find_flat_job(self.root,request['job_id'],self.output),song)
        self.assertEqual(read_record(path)['state'],'committed')

    def test_critical_disk_rejected_before_any_export(self):
        usage=shutil._ntuple_diskusage(1000,990,10)
        with patch('flat_library.shutil.disk_usage',return_value=usage):
            with self.assertRaises(ValueError):self.save(self.request())
        self.assertEqual(list(self.output.iterdir()),[])

    def test_existing_audio_never_overwritten(self):
        request=self.request();target=self.output/f"Piosenka — {request['job_id'][:8]}.mp3";target.write_bytes(b'user file')
        with self.assertRaises(FileExistsError):self.save(request)
        self.assertEqual(target.read_bytes(),b'user file')

    def test_original_reference_and_long_unicode_title_are_preserved_safely(self):
        request=self.request('樂'*150);request['reference_audio']=str(self.source)
        song=save_flat(self.root,request,self.source,{'reference_audio':'/temporary/upload.mp3'},self.output)
        record=read_record(record_path(self.root,self.output,request['job_id']))
        self.assertEqual(record['parameters']['reference_audio'],str(self.source))
        self.assertLess(len(Path(song['audioPath']).name.encode('utf-8')),255)


if __name__ == '__main__':unittest.main()

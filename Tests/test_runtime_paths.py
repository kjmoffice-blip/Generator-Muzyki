"""Confirm bundled engine output overrides without importing GPU code."""
from pathlib import Path
from unittest.mock import patch
import ast
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'Scripts'))
from prepare_runtime import patch_engine


class RuntimePathsTests(unittest.TestCase):
    def test_all_five_engine_paths_use_private_output_and_preserve_defaults(self):
        source=Path(__file__).resolve().parents[1]/'EngineOverlay'
        paths=['acestep/acestep_v15_pipeline.py','acestep/ui/gradio/api/api_routes.py',
               'acestep/ui/gradio/events/results/generation_info.py','acestep/inference.py',
               'acestep/ui/gradio/events/results/session_artifacts.py']
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for relative in paths:
                target=root/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source/relative,target)
            patch_engine(root);patch_engine(root)
            values=[]
            for relative in paths:
                tree=ast.parse((root/relative).read_text())
                for node in ast.walk(tree):
                    if isinstance(node,ast.Assign) and 'SOS_MUSIC_ENGINE_OUTPUT' in ast.unparse(node.value):
                        values.append(node.value)
            self.assertEqual(len(values),5)
            scope={'os':os,'Path':Path,'project_root':str(root),'PROJECT_ROOT':str(root)}
            for value in values:
                code=compile(ast.Expression(value),'<output-path>','eval')
                with patch.dict(os.environ,{'SOS_MUSIC_ENGINE_OUTPUT':str(root/'private')},clear=False):
                    self.assertEqual(str(eval(code,scope)),str(root/'private'))
                with patch.dict(os.environ,{},clear=True):
                    self.assertTrue(str(eval(code,scope)).endswith('gradio_outputs'))


if __name__=='__main__':unittest.main()

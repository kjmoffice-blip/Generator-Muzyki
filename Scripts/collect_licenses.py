"""Collect installed dependency notices and pinned provenance for this exact payload."""
from importlib.metadata import distributions
from pathlib import Path
import json
import os
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PAYLOAD = ROOT / "build/Generator Muzyki.app/Contents/Resources/Runtime"
DEST = ROOT / "Resources/Licenses"
DEST.mkdir(parents=True, exist_ok=True)
inventory = []
sites = [PAYLOAD / "Silnik/.venv/lib/python3.12/site-packages",
         PAYLOAD / "Runtime/python/lib/python3.12/site-packages"]
for site in sites:
    for dist in sorted(distributions(path=[str(site)]), key=lambda d:d.metadata['Name'].lower()):
        name, version = dist.metadata['Name'], dist.version
        copied = []
        for file in dist.files or []:
            relative = Path(str(file))
            if relative.is_absolute() or '..' in relative.parts:
                continue
            if not relative.name.lower().startswith(('license', 'copying', 'notice', 'authors')):
                continue
            source = site / relative
            if not source.is_file():
                continue
            target = DEST / "Python" / (re.sub(r'[^A-Za-z0-9_.-]', '_', name) + '-' + version) / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            copied.append(str(target.relative_to(DEST)))
        license_name = dist.metadata.get('License-Expression') or dist.metadata.get('License') or ''
        classifiers = [v for v in dist.metadata.get_all('Classifier',[]) if v.startswith('License ::')]
        inventory.append({'name':name, 'version':version, 'license':license_name,
                          'classifiers':classifiers, 'notices':copied,
                          'projectURLs':dist.metadata.get_all('Project-URL',[])})
supplemental = json.loads((DEST/'Supplemental.json').read_text()) if (DEST/'Supplemental.json').exists() else []
for item in inventory:
    extra = next((entry for entry in supplemental if entry['name'].lower() == item['name'].lower()), None)
    if extra:
        item['supplementalNotices'] = extra.get('notices', [])
(DEST/'Python-packages.json').write_text(json.dumps(inventory,ensure_ascii=False,indent=2))
(ROOT/'requirements-runtime-lock.txt').write_text('\n'.join(sorted({v['name']+'=='+v['version'] for v in inventory}))+'\n')
shutil.copy2(PAYLOAD/'Silnik/LICENSE',DEST/'ACE-Step-MIT.txt')
shutil.copy2(PAYLOAD/'Runtime/python/lib/python3.12/LICENSE.txt',DEST/'Python-license.txt')
shutil.copy2(ROOT/'build/model-manifest.json',DEST/'Model-files.json')
shutil.copy2(PAYLOAD/'Runtime/python/BUILD',DEST/'Python-build.txt')
source = PAYLOAD/'Silnik/checkpoints/.cache/huggingface/download'
revisions = {str(p.relative_to(source)):p.read_text() for p in source.rglob('*.metadata')}
(DEST/'Model-download-revisions.json').write_text(json.dumps(revisions,indent=2))
repo=Path(os.environ['SOS_MUSIC_ENGINE_REPO'])
commit=subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD'],text=True).strip()
(DEST/'PROVENANCE.json').write_text(json.dumps({'engineRepository':'https://github.com/ace-step/ACE-Step-1.5',
 'engineCommit':commit,'models':'https://huggingface.co/ACE-Step/Ace-Step1.5',
 'textEncoder':'https://huggingface.co/Qwen/Qwen3-Embedding-0.6B',
 'engineLicense':'MIT','textEncoderLicense':'Apache-2.0',
 'engineChanges':'Five output/cache directory defaults accept SOS_MUSIC_ENGINE_OUTPUT; defaults for other uses preserved.',
 'ffmpeg':'LGPL-2.1-or-later; compiled separately; sources and configure flags included'},indent=2))
print(f"Collected notices for {len(inventory)} installed distributions; {sum(bool(v['notices']) for v in inventory)} contain notice files.")
print('Metadata without a license label:',[v['name'] for v in inventory if not v['license'] and not v['classifiers']])

"""Preserve upstream source notices missing from a few installed wheels."""
from pathlib import Path
import base64
import hashlib
import json
import subprocess
import tarfile

ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'Resources/Licenses'
inventory=json.loads((DEST/'Python-packages.json').read_text())
supplements=[]
previous=json.loads((DEST/'Supplemental.json').read_text()) if (DEST/'Supplemental.json').exists() else []


def retrieve(url, target):
    """Download through system TLS verification, without executing source packages."""
    target.parent.mkdir(parents=True,exist_ok=True)
    subprocess.run(['/usr/bin/curl','--fail','--silent','--show-error','--location',
                    '--proto','=https','--max-time','120','--output',str(target),url],check=True)


for item in inventory:
    if item['notices']:
        continue
    name,version=item['name'],item['version']
    existing=next((v for v in previous if v['name']==name and v['version']==version),None)
    if existing and existing['notices'] and all((DEST/p).is_file() for p in existing['notices']):
        supplements.append(existing)
        continue
    metadata=ROOT/'build'/f'pypi-{name}-{version}.json'
    retrieve(f'https://pypi.org/pypi/{name}/{version}/json',metadata)
    info=json.loads(metadata.read_text())
    source=next((v for v in info['urls'] if v['packagetype']=='sdist'),None)
    notices=[]
    if source:
        archive_path=DEST/'Sources/Python'/source['filename']
        retrieve(source['url'],archive_path)
        assert hashlib.sha256(archive_path.read_bytes()).hexdigest()==source['digests']['sha256']
        if tarfile.is_tarfile(archive_path):
            with tarfile.open(archive_path) as archive:
                for member in archive.getmembers():
                    path=Path(member.name)
                    if not member.isfile() or member.size>2_000_000 or '..' in path.parts:
                        continue
                    if not path.name.lower().startswith(('license','licence','copying','notice','authors')):
                        continue
                    target=DEST/'Supplemental'/f'{name}-{version}'/Path(*path.parts[1:])
                    target.parent.mkdir(parents=True,exist_ok=True)
                    target.write_bytes(archive.extractfile(member).read())
                    notices.append(str(target.relative_to(DEST)))
    # Apache text is canonical; preserve package attribution and original metadata too.
    if not notices and ('Apache' in item['license'] or any('Apache' in v for v in item['classifiers'])):
        target=DEST/'Supplemental'/f'{name}-{version}'/'Apache-2.0.txt'
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes((DEST/'Qwen-Apache-2.0.txt').read_bytes())
        notices.append(str(target.relative_to(DEST)))
    attribution=DEST/'Supplemental'/f'{name}-{version}'/'Upstream-metadata.json'
    attribution.parent.mkdir(parents=True,exist_ok=True)
    attribution.write_text(json.dumps({'name':name,'version':version,'author':info['info'].get('author'),
                                      'license':info['info'].get('license'),'projectURLs':info['info'].get('project_urls'),
                                      'source':source},ensure_ascii=False,indent=2))
    supplement={'name':name,'version':version,'notices':notices,
                        'sourceURL':source['url'] if source else None,
                        'sourceSHA256':source['digests']['sha256'] if source else None}
    pins={('ffmpy','1.0.0'):('Ch00k/ffmpy','9312c696c4dc2d5a8c07e3df6972466035bc4254'),
          ('loguru','0.7.3'):('Delgan/loguru','5285f420ff222526f9afa7acf507362367132f9c')}
    if not notices and (name,version) in pins:
        repo,blob=pins[(name,version)];blob_path=ROOT/'build'/f'license-{name}.json'
        url=f'https://api.github.com/repos/{repo}/git/blobs/{blob}'
        retrieve(url,blob_path);data=base64.b64decode(json.loads(blob_path.read_text())['content'])
        assert hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()==blob
        target=DEST/'Supplemental'/name/'LICENSE';target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        notices.append(str(target.relative_to(DEST)));supplement.update(licenseSource=url,licenseGitBlob=blob)
    assert notices, f'Missing upstream license: {name} {version}'
    supplements.append(supplement)
    print(name,'upstream notices:',len(notices),flush=True)
(DEST/'Supplemental.json').write_text(json.dumps(supplements,ensure_ascii=False,indent=2))
for item in inventory:
    extra=next((v for v in supplements if v['name']==item['name'] and v['version']==item['version']),None)
    if extra: item['supplementalNotices']=extra['notices']
(DEST/'Python-packages.json').write_text(json.dumps(inventory,ensure_ascii=False,indent=2))

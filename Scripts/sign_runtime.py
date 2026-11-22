"""Sign bundled executable code explicitly, then seal the full app for notarization."""
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import hashlib
import json
import os
import plistlib
import subprocess

ROOT=Path(__file__).resolve().parents[1]
APP=ROOT/'build/Generator Muzyki.app'
IDENTITY=os.environ['CODESIGN_IDENTITY']
MAGIC={bytes.fromhex(v) for v in ['cffaedfe','cefaedfe','feedfacf','feedface','cafebabe','bebafeca','cafebabf','bfbafeca']}
entitlements=ROOT/'build/Python-runtime-entitlements.plist'
entitlements.write_bytes(plistlib.dumps({'com.apple.security.cs.allow-jit':True,
                                      'com.apple.security.cs.allow-unsigned-executable-memory':True}))
files=[]
for path in (APP/'Contents/Resources/Runtime').rglob('*'):
    if not path.is_file() or path.is_symlink():continue
    with path.open('rb') as stream:magic=stream.read(4)
    if magic in MAGIC:
        description=subprocess.check_output(['file','-b',str(path)],text=True)
        if 'Mach-O' in description:files.append(path)


def sign(path):
    """Sign each independent Mach-O; only the interpreter needs JIT exceptions."""
    linked=subprocess.check_output(['otool','-L',str(path)],text=True)
    ids_output=subprocess.run(['otool','-D',str(path)],capture_output=True,text=True).stdout
    own_ids={line.strip() for line in ids_output.splitlines() if not line.rstrip().endswith(':')}
    for line in linked.splitlines()[1:]:
        if not line[:1].isspace():continue  # Universal-binary architecture headings.
        lib=line.strip().split(' (')[0]
        if lib.startswith('/') and lib not in own_ids and not lib.startswith(('/usr/lib/','/System/Library/')):
            raise RuntimeError(f'External linked dependency: {path}: {lib}')
    identifier='pro.sosdigital.generatormuzyki.runtime.'+hashlib.sha256(str(path.relative_to(APP)).encode()).hexdigest()[:16]
    args=['codesign','--force','--options','runtime','--timestamp','--identifier',identifier,'--sign',IDENTITY]
    if path.name=='python3.12':args+=['--entitlements',str(entitlements)]
    result=subprocess.run(args+[str(path)],capture_output=True,text=True)
    if result.returncode:raise RuntimeError(result.stderr)
    subprocess.run(['codesign','--verify','--strict',str(path)],check=True,capture_output=True)
    return str(path.relative_to(APP))


signed=[]
with ThreadPoolExecutor(max_workers=4) as pool:
    for future in as_completed([pool.submit(sign,p) for p in files]):
        signed.append(future.result())
        if len(signed)%25==0:print(f'Signed {len(signed)}/{len(files)} Mach-O files',flush=True)
subprocess.run(['codesign','--force','--options','runtime','--timestamp','--sign',IDENTITY,str(APP)],check=True)
subprocess.run(['codesign','--verify','--deep','--strict','--verbose=2',str(APP)],check=True)
(ROOT/'build/signing-manifest.json').write_text(json.dumps({'identity':IDENTITY,'files':sorted(signed),
 'pythonEntitlements':plistlib.loads(entitlements.read_bytes()),'appVerified':True},indent=2))
print('Full app signed and verified.',flush=True)

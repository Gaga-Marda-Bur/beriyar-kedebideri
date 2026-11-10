"""Pull only named QA files, never personal device content."""
from pathlib import Path
import subprocess
import sys
HERE=Path(__file__).resolve().parent
adb=Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe'
serial, stage=sys.argv[1:]
assert stage in ('before','after')
assert not serial.startswith('emulator-')
out=HERE/'captures';out.mkdir(exist_ok=True)
for name in (f'phase62_{stage}_light.png', f'phase62_{stage}_dark.png', f'phase62_{stage}.pdf'):
    data=subprocess.run([str(adb),'-s',serial,'exec-out','run-as',
      'com.afrigama.beriyarkedebideri.qa62','cat','app_flutter/'+name],check=True,capture_output=True).stdout
    assert data.startswith(b'\x89PNG' if name.endswith('.png') else b'%PDF-')
    (out/name).write_bytes(data)
print('Collected three physical QA artifacts, serial omitted')

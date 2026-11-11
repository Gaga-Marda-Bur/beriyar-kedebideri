"""Verify the patched educational candidate without touching the main application."""
import hashlib,json,subprocess,sys,xml.etree.ElementTree as ET
from pathlib import Path
from android_artifact import main_info,cmd,shell,adb
folder=Path(__file__).resolve().parent;root=folder.parents[1]
source=root/'mobile/build/app/outputs/flutter-apk/app-debug.apk'
target=folder/'runtime/candidate64g.apk';target.write_bytes(source.read_bytes())
aapt='C:/Users/MONSTER/AppData/Local/Android/Sdk/build-tools/36.0.0/aapt.exe'
assert "name='com.afrigama.beriyarkedebideri.qa64c'" in cmd(aapt,'dump','badging',str(target))
before=main_info()
if '--inspect-only' in sys.argv:
    installed=shell('pm','path','com.afrigama.beriyarkedebideri.qa64c').splitlines()[0].removeprefix('package:')
    assert shell('sha256sum',installed).split()[0]==hashlib.sha256(target.read_bytes()).hexdigest()
else:
    assert 'Success' in cmd(adb,'-d','install','-r',str(target))
shell('am','force-stop','com.afrigama.beriyarkedebideri.qa64c')
launch=shell('am','start','-W','-n','com.afrigama.beriyarkedebideri.qa64c/com.afrigama.beriyarkedebideri.MainActivity','--es','route','/premium')
dump='/data/local/tmp/bk64g_qualification.xml'
shell('uiautomator','dump',dump)
xml=shell('cat',dump);shell('rm',dump)
nodes=ET.fromstring(xml).iter('node')
texts=[n.attrib.get('text','')+' '+n.attrib.get('content-desc','') for n in nodes if n.attrib.get('package')=='com.afrigama.beriyarkedebideri.qa64c']
premium=any('Premium' in t for t in texts)
learning=any(any(m in t for m in ['Parcours','Apprendre','Dictionnaire','Alphabet','learning','Learn']) for t in texts)
after=main_info();reference=json.loads((folder/'ANDROID_ARTIFACT.json').read_text())
assert before==after==reference['main_before']
result={'candidate_base':'964b73d','patch_files':['mobile/lib/app/app.dart','backend/monetization/services.py','backend/monetization/licensing.py'],
 'apk_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'apk_bytes':target.stat().st_size,
 'variant':'debug QA educational, simulation=false','installed':True,'physical':True,
 'direct_initial_route':'/premium','premium_ui_present':premium,'free_learning_ui_detected':learning,
 'main_fingerprint_equal_to_start':True,'ui_node_count_own_package':len(texts),
 'scope':'patched candidate; distinct from original reference APK and simulation harness'}
(folder/'ANDROID_CANDIDATE.json').write_text(json.dumps(result,indent=2)+'\n')
assert learning and not premium,result
print(json.dumps(result))

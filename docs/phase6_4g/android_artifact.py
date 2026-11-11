"""Install ONLY the reference QA artifact; fingerprint main package without reading user data."""
import hashlib,json,re,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2];folder=Path(__file__).resolve().parent
adb='C:/Users/MONSTER/AppData/Local/Android/Sdk/platform-tools/adb.exe'
sdk=Path('C:/Users/MONSTER/AppData/Local/Android/Sdk')
def cmd(*args):return subprocess.check_output(args,text=True,stderr=subprocess.STDOUT)
def shell(*args):return cmd(adb,'-d','shell',*args).strip()
def main_info():
    text=shell('dumpsys','package','com.afrigama.beriyarkedebideri')
    fields={}
    for field in ['userId','versionCode','versionName','lastUpdateTime']:
        m=re.search(r'\b'+field+r'=([^\r\n]+)',text);fields[field]=m.group(1).strip() if m else None
    path=shell('pm','path','com.afrigama.beriyarkedebideri').splitlines()[0].removeprefix('package:')
    assert re.fullmatch(r'/data/app/[\w./+~=-]+\.apk',path)
    fields['apk_sha256']=shell('sha256sum',path).split()[0]
    return fields
def run():
    before=main_info()
    apk=folder/'runtime/rc1/mobile/build/app/outputs/flutter-apk/app-debug.apk'
    data=apk.read_bytes();(folder/'runtime/rc1-reference.apk').write_bytes(data)
    tool=sorted(sdk.glob('build-tools/*/aapt.exe'),key=lambda p:p.parent.name)[-1]
    badging=cmd(str(tool),'dump','badging',str(apk))
    package=re.search(r"package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'",badging)
    assert package.group(1)=='com.afrigama.beriyarkedebideri.qa64c'
    install=cmd(adb,'-d','install','-r',str(apk));assert 'Success' in install
    after=main_info();assert before==after
    version=json.loads(cmd('C:/Users/MONSTER/Projects/django_notes_backend/flutter/bin/flutter.bat','--version','--machine'))
    result={'reference_commit':'964b73d5c884d9dc9a115e18c7c87b37f1cc28fb',
     'source_mobile_tree':cmd('git','rev-parse','964b73d:mobile').strip(),'source_kind':'exact git archive, no source modification',
     'apk_sha256':hashlib.sha256(data).hexdigest(),'apk_bytes':len(data),'package':package.group(1),'version_code':package.group(2),'version_name':package.group(3),
     'variant':'debug QA educational (not signed release)',
     'flags':{'BK_IDENTITY_QA':True,'BK_PREMIUM_SIMULATION':False,'API_FLAVOR':'local','API_BASE_URL':'http://127.0.0.1:18778/api'},
     'flutter_version':version,'android_build_tools':tool.parent.name,
     'device':{'model':shell('getprop','ro.product.model'),'android':shell('getprop','ro.build.version.release'),'sdk':shell('getprop','ro.build.version.sdk')},
     'install_result':'Success','main_before':before,'main_after':after,'main_fingerprint_equal':True,
     'no_ad_id_permission':'com.google.android.gms.permission.AD_ID' not in badging,
     'bit_for_bit_clean_rebuild':'not yet tested'}
    (folder/'ANDROID_ARTIFACT.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['package','apk_sha256','apk_bytes','main_fingerprint_equal']}))

if __name__ == "__main__":
    run()

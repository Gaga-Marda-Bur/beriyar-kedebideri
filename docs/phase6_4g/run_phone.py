"""Physical QA on a separate package. No user account, main app data or remote API."""
import argparse,json,subprocess,hashlib,sys
from pathlib import Path
folder=Path(__file__).resolve().parent;root=folder.parents[1]
runtime=folder/'runtime';mobile=runtime/'rc1/mobile'
adb='C:/Users/MONSTER/AppData/Local/Android/Sdk/platform-tools/adb.exe'
flutter='C:/Users/MONSTER/Projects/django_notes_backend/flutter/bin/flutter.bat'
package='com.afrigama.beriyarkedebideri.qa64c'
def shell(*args):return subprocess.check_output([adb,'-d','shell',*args],text=True).strip()
parser=argparse.ArgumentParser();parser.add_argument('phases',nargs='+');parser.add_argument('--learning',action='store_true');args=parser.parse_args()
allowed={'initial','switch','b-restart','login-a','offline','guest-offline','erfe','revalidate','reboot','learning-seed','learning-offline'}
assert set(args.phases)<=allowed
defines={'BK_IDENTITY_QA':'true','BK_PREMIUM_SIMULATION':'true','API_FLAVOR':'local',
 'API_BASE_URL':'http://127.0.0.1:18765/api','BK_SIMULATION_PUBLIC_KEYS':(runtime/'public_keys.json').read_text()}
if args.learning: defines['API_BASE_URL']='http://127.0.0.1:18778/api'
config=runtime/'identity-defines.json';config.write_text(json.dumps(defines))
target='integration_test/premium_identity_test.dart'
if args.learning:
    import shutil
    shutil.copyfile(folder/'samsung_offline_learning_test.dart',mobile/'integration_test/qualification_offline_test.dart')
    target='integration_test/qualification_offline_test.dart'
    subprocess.run([adb,'-d','reverse','tcp:18778','tcp:18778'],check=True,capture_output=True)
statefile=folder/'PHONE_NETWORK_INITIAL.json'
if not statefile.exists():
    statefile.write_text(json.dumps({k:shell('settings','get','global',k) for k in ['airplane_mode_on','wifi_on','mobile_data']},indent=2)+'\n')
network=json.loads(statefile.read_text());offline=False
resultsfile=folder/'SAMSUNG_SCENARIOS.json'
results=json.loads(resultsfile.read_text()) if resultsfile.exists() else []
try:
 for phase in args.phases:
    subprocess.run([adb,'-d','shell','run-as',package,'mkdir','-p','app_flutter'],check=True,capture_output=True)
    if phase in ('offline','guest-offline','learning-offline'):
        shell('cmd','connectivity','airplane-mode','enable')
        subprocess.run([adb,'-d','reverse','--remove','tcp:18765'],check=False,capture_output=True)
        subprocess.run([adb,'-d','reverse','--remove','tcp:18778'],check=False,capture_output=True)
        offline=True
    subprocess.run([adb,'-d','shell','run-as',package,'tee','app_flutter/qa_phase.txt'],input=phase.encode(),check=True,capture_output=True)
    log=runtime/('phone-'+phase+'.log')
    with log.open('w',encoding='utf-8') as out:
        p=subprocess.run([flutter,'test',target,'-d',
            # Resolve the single connected hardware device, never an emulator.
            subprocess.check_output([adb,'-d','get-serialno'],text=True).strip(),
            '--no-pub','--no-uninstall','--dart-define-from-file='+str(config),
            '--dart-define=BK_QA_PHASE=dynamic'],cwd=mobile,stdout=out,stderr=subprocess.STDOUT)
    text=log.read_text(encoding='utf-8')
    passed=p.returncode==0 and 'All tests passed!' in text and 'BK_QA_SCENARIO:'+phase in text
    result={'phase':phase,'passed':passed,'physical':True,'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),
        'airplane_mode':shell('settings','get','global','airplane_mode_on'),'backend_usb_forward_removed':offline,
        'harness':target,'application_source':'964b73d','simulation':True,
        'sentinel_limitation':'identity harness rewrites sentinel; separate learning harness checks actual saved progress without rewriting'}
    results.append(result);resultsfile.write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps(result),flush=True)
    if not passed:print(text[-2500:]);sys.exit(1)
finally:
 if offline:
    shell('cmd','connectivity','airplane-mode','enable' if network['airplane_mode_on']=='1' else 'disable')
    if network['wifi_on'] in ('0','1'):shell('svc','wifi','enable' if network['wifi_on']=='1' else 'disable')
    if network['mobile_data'] in ('0','1'):shell('svc','data','enable' if network['mobile_data']=='1' else 'disable')
    subprocess.run([adb,'-d','reverse','tcp:18765','tcp:18765'],capture_output=True,check=True)
    subprocess.run([adb,'-d','reverse','tcp:18778','tcp:18778'],capture_output=True,check=True)

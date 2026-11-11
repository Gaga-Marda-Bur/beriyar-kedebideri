"""Summarize executed local evidence; never runs a migration or network call."""
import hashlib
import json
import re
import subprocess
from pathlib import Path

folder = Path(__file__).resolve().parent
root = folder.parents[1]
runtime = folder/'runtime'


def log(name):
    return (runtime/name).read_text(encoding='utf-8-sig')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


assert 'Ran 147 tests' in log('django-global.log') and 'OK (skipped=2)' in log('django-global.log')
assert 'Ran 30 tests' in log('postgres-tests.log') and re.search(r'^OK$',log('postgres-tests.log'),re.M)
assert '+145: All tests passed!' in log('flutter-global.log')
assert 'No issues found!' in log('flutter-analyze.log')
assert '# pass 5' in log('javascript.log') and '# fail 0' in log('javascript.log')
for name in ('android-initial.log','android-airplane.log','android-reboot.log'):
    assert 'All tests passed!' in log(name)
schema = json.loads((folder/'SCHEMA_CHECKS.json').read_text(encoding='utf-8'))
assert sha(root/'backend/db.sqlite3') == schema['source_sqlite_sha256']
proof = json.loads((folder/'NATIVE_PROOF_VERIFICATION.json').read_text(encoding='utf-8'))
assert proof['source_log_sha256'] == sha(runtime/'android-initial.log')

changed = subprocess.check_output(['git','diff','c59808e','--name-only'],cwd=root,text=True).splitlines()
base_files = set(subprocess.check_output(['git','ls-tree','-r','--name-only','c59808e'],cwd=root,text=True).splitlines())
tracked = [p for p in changed if p in base_files]
allowed = {'backend/config/settings.py','backend/config/urls.py','backend/requirements.txt',
    'mobile/pubspec.yaml','mobile/pubspec.lock','mobile/android/app/build.gradle.kts',
    'mobile/android/app/src/main/kotlin/com/afrigama/beriyarkedebideri/MainActivity.kt'}
assert set(tracked) == allowed, tracked
new = subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=root,text=True).splitlines()
new += [p for p in changed if p not in base_files]
paths = sorted(set(tracked+new+['docs/phase6_4b/FILES_CHANGED.txt','docs/phase6_4b/RESULTS.json','docs/phase6_4b/SIMULATIONS.json']))
assert not any('/runtime/' in p or '__pycache__/' in p or p.endswith(('.sqlite3','.pem','.apk','.env')) for p in paths)
(folder/'FILES_CHANGED.txt').write_text('\n'.join(paths)+'\n',encoding='utf-8')

result = {'phase':'6.4B simulation foundation','date':'2026-11-11','base':'c59808e',
    'branch':subprocess.check_output(['git','branch','--show-current'],cwd=root,text=True).strip(),
    'baseline_executed':{'django':117,'flutter':130,'javascript':5},
    'final_executed':{'django_sqlite':{'run':147,'passed':145,'skipped_postgres_only':2},
        'new_module_postgresql':{'run':30,'passed':30,'concurrent_tests':2},
        'flutter':{'passed':145,'new_commerce_tests':15},'javascript':{'passed':5},
        'flutter_analysis':'no issues', 'django_check':'no issues',
        'makemigrations_check':'no changes', 'apk_debug':'compiled',
        'android_native_emulator_steps_passed':['initial Keystore/AES-GCM/signature',
            'force-stop/relaunch in airplane mode, package retained','system reboot requires online verification'],
        'native_p256_proof_independently_verified_python':True},
    'device':json.loads((folder/'ANDROID_ENVIRONMENT.json').read_text()),
    'source_db_sha256':schema['source_sqlite_sha256'],
    'source_db_matches_phase63':True,'source_or_production_migrations_applied':False,
    'preserved_previous_tracked_deliverables':True,
    'not_performed':['physical Android phone validation','production deployment','real payment',
        'real bank account configuration','SDK Ads or IAP integration','commercial activation',
        'native account login UI','migration of existing guest/A/B pedagogical caches',
        'production signing-key provisioning or live key rotation','runtime performance benchmark'],
    'limits':['offline immediate revocation impossible','privileged full-state rollback/root not defeated',
        'pre-API23 or missing boot identity: extra features fail closed','merchant country undetermined',
        'no legal parental-consent validation inferred','previous production blockers remain'],
    'cleanup_observed':{'qa_package_uninstalled':True,'emulator_stopped':True,'own_postgres_cluster_stopped':True},
    'logs':{p.name:{'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(runtime.glob('*.log'))
        if p.name in ['django-global.log','postgres-tests.log','flutter-global.log','flutter-analyze.log',
                      'flutter-targeted.log','javascript.log','android-initial.log','android-airplane.log','android-reboot.log']},
    'decision':{'isolated_simulation_foundation':'GO technical review',
        'real_provider_or_production':'NO-GO pending explicit approval and prerequisites'}}
(folder/'RESULTS.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
simulations = {'mode':'simulation only','currency':'XXX','country':'ZZ','real_encashment':False,
    'methods_tested':['bank','mobile_money','cash','online'],
    'path_tested':['pending','verified','activated'],
    'additional_tests':['reject','cancel','refund','revoke','donation without grant',
        'complimentary/scholarship without fictitious payment','duplicate receipt refusal',
        'idempotency conflict','independent approver','protected age extra permission',
        'Admin form and HTTP actions','simultaneous activation','simultaneous request creation'],
    'tests_module':'backend/monetization/tests.py and tests_concurrency.py',
    'postgres_log_sha256':sha(runtime/'postgres-tests.log'),'result':'passed'}
(folder/'SIMULATIONS.json').write_text(json.dumps(simulations,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'django':147,'postgres':30,'flutter':145,'javascript':5,
    'analysis':'clean','files':len(paths),'source_db':'unchanged'},ensure_ascii=False))

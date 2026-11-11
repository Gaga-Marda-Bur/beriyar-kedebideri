"""Consolidate executed evidence, retaining failed browser scenarios as failures."""
import ast,hashlib,json,re,subprocess
from pathlib import Path
folder=Path(__file__).resolve().parent;root=folder.parents[1]
read=lambda name:json.loads((folder/name).read_text(encoding='utf-8'))
log=lambda name:(folder/'runtime'/name).read_text(encoding='utf-8-sig')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert 'Ran 158 tests' in log('django-final.log') and 'OK (skipped=2)' in log('django-final.log')
assert 'Ran 41 tests' in log('postgres-final.log') and re.search(r'^OK$',log('postgres-final.log'),re.M)
assert '+152: All tests passed!' in log('flutter-final.log')
assert 'No issues found!' in log('analyze.log')
assert '# pass 5' in log('javascript.log')
assert 'FAILED (failures=2)' in log('staging-red.log')
assert 'Ran 3 tests' in log('staging-green.log') and re.search(r'^OK$',log('staging-green.log'),re.M)
browser=read('BROWSER.json');assert len(browser['results'])==12
failed={x['name'] for x in browser['results'] if x['status']=='failed'}
assert failed=={'unit_and_lessons','theme_preference_light_dark'},failed
phone=read('SAMSUNG_SCENARIOS.json');assert len(phone)==9 and all(p['passed'] for p in phone)
assert read('REPRODUCIBILITY.json')['byte_identical']
candidate=read('ANDROID_CANDIDATE.json');assert candidate['free_learning_ui_detected'] and not candidate['premium_ui_present']
initial=read('INITIAL_STATE.json')
assert sha(root/'backend/db.sqlite3')==initial['source_database_sha256']
for p,digest in initial['preexisting_dirty_files'].items():assert sha(root/p)==digest,p
assert not (root/'docs/phase6_4b/runtime/pgdata/postmaster.pid').exists()
result={'lot':'6.4G','date':'2026-11-11','base_commit':initial['reference'],
 'branch':'codex/phase6-4g-staging-readiness',
 'baseline_executed':{'django_run':155,'django_skipped_postgres':2,'flutter':151,'javascript':5,'postgres_module':38},
 'final_executed':{'django_run':158,'django_passed':156,'django_skipped_postgres':2,'postgres_module_passed':41,
 'flutter_passed':152,'javascript_passed':5,'flutter_analysis':'clean','chrome_checks':12,'chrome_passed':10,
 'chrome_failed_observed':sorted(failed),'samsung_scenarios_passed':9,'samsung_corrected_direct_route':'passed',
 'staging_regression_red_failures':2,'staging_regression_green_passed':3,
 'deploy_warning_ids':[m['id'] for m in read('STAGING_CHECKS.json')['deploy_messages']]},
 'source_db_sha256':initial['source_database_sha256'],'source_db_unchanged':True,
 'preexisting_dirty_bytecodes_preserved':list(initial['preexisting_dirty_files']),
 'reference_apk':read('ANDROID_ARTIFACT.json'),'reproducibility':read('REPRODUCIBILITY.json'),
 'corrected_candidate':candidate,'learning_offline':read('SAMSUNG_LEARNING.json'),
 'cleanup':{'owned_local_servers_stopped':True,'own_pg_cluster_stopped':True,'qa_app_stopped_not_uninstalled':True,
 'phone_network_restored_to_initial':True,'qa_usb_forwards_removed':True},
 'not_executed':['remote deployment','production or source migration','actual staging TLS/proxy/ACL/DB role verification',
 'full BK remote backup/restore','signed release build','physical system reboot this lot','human audio listening this lot',
 'manual accessibility and PDF requalification'],
 'decision':{'local_qualification_dossier':'GO','immediate_staging_deployment':'NO-GO',
 'reasons':['target secrets/domains/TLS/roles/media/backups not provisioned and verified',
 'public theme index empty','local corpus still in review and a published translation placeholder',
 'web light theme not observed']},
 'logs':{n:{'sha256':sha(folder/'runtime'/n),'bytes':(folder/'runtime'/n).stat().st_size} for n in
 ['django.log','django-final.log','postgres-tests.log','postgres-final.log','flutter.log','flutter-final.log','javascript.log',
 'analyze.log','browser.log','staging-red.log','staging-green.log','staging-check.log','apk-reference.log','cold-rebuild.log','apk-corrected.log']},
 'captures':{p.name:{'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted((folder/'captures').glob('*.png'))}}
patch=subprocess.check_output(['git','diff','964b73d','--','backend/monetization/services.py','backend/monetization/licensing.py','mobile/lib/app/app.dart'],cwd=root)
result['business_code_patch_sha256']=hashlib.sha256(patch).hexdigest()
(folder/'RESULTS.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
base=set(subprocess.check_output(['git','ls-tree','-r','--name-only','964b73d'],cwd=root,text=True).splitlines())
changed=subprocess.check_output(['git','diff','964b73d','--name-only'],cwd=root,text=True).splitlines()
untracked=subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=root,text=True).splitlines()
paths=sorted((set(changed+untracked)-set(initial['preexisting_dirty_files']))|{'docs/phase6_4g/FILES_CHANGED.txt'})
assert all('/runtime/' not in p and '__pycache__' not in p for p in paths)
assert {p for p in paths if p in base}=={'backend/monetization/licensing.py','backend/monetization/services.py','mobile/lib/app/app.dart'}
(folder/'FILES_CHANGED.txt').write_text('\n'.join(paths)+'\n',encoding='utf-8')
for p in [root/'docs/PHASE6_4G_STAGING_READINESS.md',*folder.glob('*.md')]:
    body=p.read_text(encoding='utf-8');assert len(re.findall(r'^```',body,re.M))%2==0,p
    for link in re.findall(r'\]\(([^)]+)\)',body):
        if '://' not in link:assert (p.parent/link.split('#')[0]).exists(),(p,link)
for p in [*folder.glob('*.py'),root/'backend/monetization/tests_staging_gate.py']:ast.parse(p.read_text(encoding='utf-8-sig'))
print(json.dumps({'files':len(paths),'django':158,'postgres':41,'flutter':152,'javascript':5,'chrome':'10 passed / 2 observed failures',
 'samsung':'9 scenarios + corrected route','decision':'NO-GO immediate staging'},ensure_ascii=False))

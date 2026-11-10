"""Collect only QA app results from our emulator; never collect phone contents."""
import json
import hashlib
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
LAB = HERE / 'runtime'
ADB = Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk/platform-tools/adb.exe'
DEVICE = 'emulator-5580'
PACKAGE = 'com.afrigama.beriyarkedebideri.qa'


def adb(*args):
    return subprocess.run([str(ADB), '-s', DEVICE, *args], check=True, capture_output=True,
                          text=True, encoding='utf-8').stdout.strip()


names = ('online', 'offline', 'resync', 'cached_audio', 'cached_quizzes', 'offline_catalogue', 'quiz-check')
results = {}
for name in names:
    text = adb('shell', 'run-as', PACKAGE, 'cat', f'app_flutter/qa_{name}.json')
    results[name] = json.loads(text)
    (LAB / f'android_{name}.json').write_text(text + '\n', encoding='utf-8')

lab = json.loads((LAB / 'lab.json').read_text(encoding='utf-8'))
http = json.loads((LAB / 'http_results.json').read_text(encoding='utf-8'))
analysis = json.loads((LAB / 'pack_analysis.json').read_text(encoding='utf-8'))
all_passed = all(v.get('passed') is True for v in results.values())
decision_str = (
    'GO: all 4 Phase 3.1 Android defects resolved and verified'
    if all_passed
    else 'NO-GO: blocking offline and feedback defects'
)
summary = {
    'date': '2026-11-09', 'decision': decision_str,
    'physical_android_executed': False,
    'physical_detection': 'Samsung USB composite seen by Windows; no physical ADB device detected',
    'emulator': {'model': adb('shell', 'getprop', 'ro.product.model'),
                 'api': adb('shell', 'getprop', 'ro.build.version.sdk'),
                 'android_release': adb('shell', 'getprop', 'ro.build.version.release'),
                 'ram_mb_configured': 2048, 'audio_output': 'disabled; native decode/completion tested'},
    'isolation': {'application_id': PACKAGE, 'source_db_sha256': lab['source_db_sha256'],
        'source_db_sha256_after': hashlib.sha256((ROOT / 'backend/db.sqlite3').read_bytes()).hexdigest(),
        'backup_restore_tables_compared': lab['restore_tables_compared'],
        'migration': lab['migration'], 'production_migration': False},
    'http': http, 'android': results, 'pack_analysis': analysis,
    'performance': {'scope': 'single samples, debug, emulator; no release comparison',
        'pack_bytes_exact': lab['pack_bytes'], 'normal_debug_apk_bytes': (LAB / 'artifacts/bk-qa-debug.apk').stat().st_size,
        'shell_observation_provenance': 'am start -W and dumpsys meminfo outputs captured in this session; values transcribed below, not recomputed by this collector',
        'am_start_cold_total_ms': 5136, 'pss_snapshot_kb': 335633,
        'documents_delta_download_extract_bytes': results['online']['documents_bytes_after'] - results['online']['documents_bytes_before'],
        'low_storage_test_executed': False, 'frame_profile_executed': False},
}
(HERE / 'PHASE3_RESULTS.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'native_results_collected': len(results), 'http_scenarios': len(http['scenarios']),
                  'decision': summary['decision']}, indent=2))

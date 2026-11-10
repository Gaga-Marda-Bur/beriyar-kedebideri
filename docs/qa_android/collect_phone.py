"""Collect QA-only results from an explicitly selected, connected physical device."""
import argparse
import json
import os
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
LAB = HERE / 'runtime'
ADB = Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk/platform-tools/adb.exe'
parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
serial = parser.parse_args().device
inventory = subprocess.run([str(ADB), 'devices'], capture_output=True, text=True, check=True).stdout
assert any(line.split() == [serial, 'device'] for line in inventory.splitlines())
assert not serial.startswith('emulator-')


def adb(*args):
    return subprocess.run([str(ADB), '-s', serial, *args], check=True, capture_output=True,
                          text=True, encoding='utf-8').stdout.strip()


assert adb('shell', 'getprop', 'ro.kernel.qemu') != '1'
names = ('online', 'offline', 'resync', 'cached_audio', 'cached_quizzes', 'offline_catalogue', 'quiz-check')
results = {}
for name in names:
    text = adb('shell', 'run-as', 'com.afrigama.beriyarkedebideri.qa', 'cat', f'app_flutter/qa_{name}.json')
    results[name] = json.loads(text)
    (LAB / f'physical_{name}.json').write_text(text + '\n', encoding='utf-8')
initial = json.loads((LAB / 'phone_state_before.json').read_text(encoding='utf-8'))
restored = {key: int(adb('shell', 'settings', 'get', 'global', key))
            for key in ('airplane_mode_on', 'wifi_on', 'mobile_data')}
assert all(restored[key] == initial[key] for key in restored)
config = {'model': adb('shell', 'getprop', 'ro.product.model'),
          'android_release': adb('shell', 'getprop', 'ro.build.version.release'),
          'api': int(adb('shell', 'getprop', 'ro.build.version.sdk')),
          'abi': adb('shell', 'getprop', 'ro.product.cpu.abi'),
          'display': adb('shell', 'wm', 'size'), 'density': adb('shell', 'wm', 'density'),
          'mem_total': next(line for line in adb('shell', 'cat', '/proc/meminfo').splitlines() if line.startswith('MemTotal:'))}
phone = {'configuration': config, 'initial_state': initial, 'restored_state': restored,
         'android_results': results}
(LAB / 'phone_results.json').write_text(json.dumps(phone, ensure_ascii=False, indent=2), encoding='utf-8')
summary_file = HERE / 'PHASE3_RESULTS.json'
summary = json.loads(summary_file.read_text(encoding='utf-8'))
summary.update(physical_android_executed=True,
    physical_detection='Samsung authorized in ADB after enabling USB debugging; serial deliberately omitted',
    physical_android=phone)
summary_file.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'physical_model': config['model'], 'native_results_collected': len(results),
                  'network_state_restored': restored, 'human_audio_audible': initial['human_confirmed_audio_audible']}, indent=2))

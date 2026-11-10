"""Create isolated QA62 clone. Refresh lib only with explicit 'refresh'."""
from pathlib import Path
import shutil
import sys

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
target=HERE/'runtime/mobile'
if 'refresh' in sys.argv:
    assert target.is_dir()
    shutil.copytree(ROOT/'mobile/lib',target/'lib',dirs_exist_ok=True)
    shutil.copytree(ROOT/'mobile/assets',target/'assets',dirs_exist_ok=True)
else:
    assert not target.exists(), 'Refusing to overwrite QA clone'
    target.mkdir(parents=True)
    for folder in ('lib','assets','android'):
        shutil.copytree(ROOT/'mobile'/folder,target/folder,
          ignore=shutil.ignore_patterns('build','.gradle','.cxx','key.properties','*.jks','*.keystore','local.properties'))
    for name in ('pubspec.lock','analysis_options.yaml','l10n.yaml'):
        shutil.copy2(ROOT/'mobile'/name,target/name)
    gradle=target/'android/app/build.gradle.kts'
    gradle.write_text(gradle.read_text(encoding='utf-8').replace(
      'applicationId = "com.afrigama.beriyarkedebideri"',
      'applicationId = "com.afrigama.beriyarkedebideri.qa62"'),encoding='utf-8')
    manifest=target/'android/app/src/main/AndroidManifest.xml'
    manifest.write_text(manifest.read_text(encoding='utf-8').replace(
      'android:label="Beřiyar Kedebideři"','android:label="BK QA Typographie"'),encoding='utf-8')
pubspec=(ROOT/'mobile/pubspec.yaml').read_text(encoding='utf-8')
assert 'integration_test:' not in pubspec
(target/'pubspec.yaml').write_text(pubspec.replace('dev_dependencies:',
    'dev_dependencies:\n  integration_test:\n    sdk: flutter'),encoding='utf-8')
(target/'integration_test').mkdir(exist_ok=True)
shutil.copy2(HERE/'typography_android_test.dart',target/'integration_test/typography_android_test.dart')
print(target)

"""Create a loopback-only QA lab. No production settings or source DB writes.

Usage: backend/venv/Scripts/python.exe docs/qa_android/prepare_lab.py prepare|serve
The source corpus is read-only; users/history are synthetic. Runtime is ignored.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import secrets
import shutil
import sqlite3
import sys

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / 'docs/qa_android/runtime'
SOURCE = ROOT / 'backend/db.sqlite3'


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def snapshot(path):
    with sqlite3.connect(path.as_uri() + '?mode=ro', uri=True) as db:
        tables = db.execute("SELECT name,sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name").fetchall()
        return {name: (ddl, sorted(db.execute('SELECT * FROM "' + name + '"').fetchall(), key=repr)) for name, ddl in tables}


def setup():
    sys.path.insert(0, str(ROOT / 'backend'))
    os.environ.update(DJANGO_SETTINGS_MODULE='config.settings', DJANGO_ENV='test',
        DATABASE_URL='sqlite:///' + (LAB / 'qa.sqlite3').as_posix(), USE_R2='False',
        DEBUG='True', SECURE_SSL_REDIRECT='False',
        SECRET_KEY='isolated-phase3-lab-key-not-production',
        ALLOWED_HOSTS='127.0.0.1,localhost,10.0.2.2')
    import django
    django.setup()


def prepare():
    from django.apps import apps
    from django.contrib.auth import get_user_model
    from django.core.management import call_command
    from django.db import connection
    from django.db.migrations.executor import MigrationExecutor
    from offline_packs.models import LessonPack
    from offline_packs.services.offline_pack_generator import OfflinePackGenerator
    if (LAB / 'qa.sqlite3').exists():
        raise SystemExit('QA database already exists: refusing to overwrite it.')
    source_hash = sha(SOURCE)
    executor = MigrationExecutor(connection)
    targets = [node for node in executor.loader.graph.leaf_nodes() if node[0] != 'progress'] + [('progress', '0003_unitprogress_scoring_metadata')]
    executor.migrate(targets)
    old_apps = executor.loader.project_state(targets).apps
    src = sqlite3.connect(SOURCE.as_uri() + '?mode=ro', uri=True)
    src.row_factory = sqlite3.Row
    inserted = {}
    files = []

    def copy_model(app, name, where):
        model = apps.get_model(app, name)
        fields = {f.attname: f for f in model._meta.concrete_fields}
        selected = set()
        for row in src.execute('SELECT * FROM ' + model._meta.db_table + ' WHERE ' + where):
            values = {k: row[k] for k in fields if k in row.keys()}
            for key, field in fields.items():
                if key not in values:
                    continue
                if field.get_internal_type() == 'JSONField':
                    values[key] = json.loads(values[key])
                if field.is_relation and values[key] is not None:
                    if not field.remote_field.model.objects.filter(pk=values[key]).exists():
                        if not field.null:
                            break
                        values[key] = None
                if field.get_internal_type() in ('FileField', 'ImageField') and values[key]:
                    path = (ROOT / 'backend/media' / values[key]).resolve()
                    if path.is_relative_to((ROOT / 'backend/media').resolve()) and path.is_file():
                        target = LAB / 'media' / values[key]
                        target.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(path, target)
                        files.append({'name': values[key], 'bytes': path.stat().st_size, 'sha256': sha(path)})
            else:
                # Only personal recording metadata is anonymized in this QA copy.
                if name == 'AudioAsset':
                    values.update(speaker_name='', notes='')
                obj = model.objects.create(**values)
                selected.add(obj.pk)
        inserted[f'{app}.{name}'] = len(selected)
        return model

    active = "is_active=1"
    published = active + " AND validation_status='published'"
    copy_model('audio_assets', 'AudioAsset', "validation_status='published'")
    copy_model('vocabulary', 'WordCategory', active)
    copy_model('alphabet', 'Character', published)
    copy_model('vocabulary', 'Word', published)
    # Keep active parent rows with their original editorial status. A published
    # unit may reference a draft theme; never silently publish that theme.
    copy_model('learning', 'LearningTheme', active)
    Unit = copy_model('learning', 'LearningUnit', active + " AND status='published'")
    for unit in Unit.objects.all():
        for relation_name in ('characters', 'distractor_characters', 'words'):
            relation = getattr(unit, relation_name)
            through = relation.through
            fk = 'word_id' if relation_name == 'words' else 'character_id'
            ids = [r[0] for r in src.execute('SELECT ' + fk + ' FROM ' + through._meta.db_table + ' WHERE learningunit_id=?', (unit.pk,))]
            relation.set(relation.model.objects.filter(pk__in=ids))
    Lesson = copy_model('lessons', 'Lesson', active + " AND status='published'")
    copy_model('lessons', 'LessonItem', active)
    Quiz = copy_model('quizzes', 'QuizQuestion', active + " AND status='published'")
    copy_model('quizzes', 'QuizOption', '1=1')
    for app, name in [('alphabet', 'CharacterAudio'), ('vocabulary', 'WordAudio'),
                      ('lessons', 'LessonItemAudio'), ('quizzes', 'QuizQuestionAudio')]:
        copy_model(app, name, '1=1')
    src.close()
    assert sha(SOURCE) == source_hash
    first_unit = Unit.objects.order_by('order_index', 'id').first()
    if first_unit is None:
        raise RuntimeError('No published source unit; no invented fallback.')
    credentials = {name: secrets.token_urlsafe(24) for name in ('qa_account_a', 'qa_account_b')}
    users = {name: get_user_model().objects.create_user(username=name, password=password) for name, password in credentials.items()}
    OldProgress = old_apps.get_model('progress', 'UnitProgress')
    OldProgress.objects.create(user_id=users['qa_account_a'].pk, device_id='qa-account-a',
                              device_token='synthetic-old-token-a', unit_id=first_unit.pk, lessons_seen=4)
    OldProgress.objects.create(device_id='qa-legacy', unit_id=first_unit.pk, lessons_seen=5)
    backup = LAB / 'before_0004.sqlite3'
    with sqlite3.connect(LAB / 'qa.sqlite3') as db, sqlite3.connect(backup) as out:
        db.backup(out)
    before = snapshot(backup)
    restored = LAB / 'restore_check.sqlite3'
    with sqlite3.connect(backup) as db, sqlite3.connect(restored) as out:
        db.backup(out)
    assert snapshot(restored) == before
    with sqlite3.connect(restored) as db:
        assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
        assert not db.execute('PRAGMA foreign_key_check').fetchall()
    call_command('migrate', verbosity=0, interactive=False)
    call_command('makemigrations', check=True, dry_run=True, verbosity=0)
    Pack = LessonPack.objects.create(slug='qa-phase3', title_fr='Recette isolée Phase 3',
                                    version=1, status='published', is_featured=True)
    Pack.units.set(Unit.objects.all())
    Pack.themes.set(apps.get_model('learning', 'LearningTheme').objects.filter(status='published'))
    Pack.characters.set(apps.get_model('alphabet', 'Character').objects.all())
    Pack.words.set(apps.get_model('vocabulary', 'Word').objects.all())
    Pack.lessons.set(Lesson.objects.all())
    Pack.quiz_questions.set(Quiz.objects.all())
    OfflinePackGenerator(Pack).generate()
    (LAB / 'synthetic_accounts.json').write_text(json.dumps(credentials), encoding='utf-8')
    result = {'source_db_sha256': source_hash, 'source_unchanged': sha(SOURCE) == source_hash,
        'copied_content_with_original_status': inserted, 'copied_media': files,
        'backup': str(backup), 'backup_sha256': sha(backup), 'restore_tables_compared': len(before),
        'migration': 'progress.0004_progressdevicecredential applied to QA only',
        'first_unit_slug': first_unit.slug, 'first_unit_id': first_unit.pk,
        'pack_id': Pack.pk, 'pack_bytes': Pack.file.size, 'pack_sha256': Pack.checksum,
        'base_url': 'http://127.0.0.1:8765/api', 'qa_application_id': 'com.afrigama.beriyarkedebideri.qa'}
    (LAB / 'lab.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False, indent=2))


def clone_mobile():
    target = LAB / 'mobile'
    if target.exists():
        raise SystemExit('QA mobile clone already exists; refusing overwrite.')
    target.mkdir()
    ignored = shutil.ignore_patterns('build', '.gradle', '.cxx', 'key.properties', '*.jks', '*.keystore', 'local.properties')
    for directory in ('lib', 'assets', 'android'):
        shutil.copytree(ROOT / 'mobile' / directory, target / directory, ignore=ignored)
    for file in ('pubspec.lock', 'analysis_options.yaml', 'l10n.yaml'):
        shutil.copy2(ROOT / 'mobile' / file, target / file)
    pubspec = (ROOT / 'mobile/pubspec.yaml').read_text(encoding='utf-8')
    pubspec = pubspec.replace('dev_dependencies:', 'dev_dependencies:\n  integration_test:\n    sdk: flutter', 1)
    (target / 'pubspec.yaml').write_text(pubspec, encoding='utf-8')
    gradle = target / 'android/app/build.gradle.kts'
    value = gradle.read_text(encoding='utf-8')
    original_id = 'applicationId = "com.afrigama.beriyarkedebideri"'
    assert original_id in value
    # Set the full ID so Flutter's install/stop logic also recognizes the QA ID.
    # A debug suffix alone was not recognized by this installed Flutter CLI.
    gradle.write_text(value.replace(original_id, 'applicationId = "com.afrigama.beriyarkedebideri.qa"', 1), encoding='utf-8')
    manifest = target / 'android/app/src/main/AndroidManifest.xml'
    value = manifest.read_text(encoding='utf-8').replace('android:label="Beřiyar Kedebideři"', 'android:label="BK QA Phase 3"')
    manifest.write_text(value, encoding='utf-8')
    (target / 'integration_test').mkdir()
    shutil.copy2(ROOT / 'docs/qa_android/phase3_android_test.dart', target / 'integration_test/phase3_android_test.dart')
    print('Isolated mobile clone: ' + str(target))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=('prepare', 'serve', 'clone-mobile'))
    action = parser.parse_args().action
    LAB.mkdir(parents=True, exist_ok=True)
    if action == 'clone-mobile':
        return clone_mobile()
    setup()
    from django.test import override_settings
    with override_settings(MEDIA_ROOT=LAB / 'media', STORAGES={
        'default': {'BACKEND': 'django.core.files.storage.FileSystemStorage'},
        'staticfiles': {'BACKEND': 'django.contrib.staticfiles.storage.StaticFilesStorage'}}):
        if action == 'prepare':
            prepare()
        else:
            if not (LAB / 'lab.json').exists():
                raise SystemExit('Prepare the isolated lab first.')
            from django.core.management import call_command
            call_command('runserver', '127.0.0.1:8765', use_reloader=False)


if __name__ == '__main__':
    main()

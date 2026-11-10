from django.core.management import call_command
from django.db import connection
from django.db.migrations.executor import MigrationExecutor
from django.test import TransactionTestCase


class ProgressCredentialMigrationTests(TransactionTestCase):
    def test_additive_migration_preserves_populated_history_and_matches_models(self):
        before = ('progress', '0003_unitprogress_scoring_metadata')
        after = ('progress', '0004_progressdevicecredential')
        executor = MigrationExecutor(connection)
        executor.migrate([before])
        try:
            # Other apps remain at their installed leaf migrations while only
            # progress is moved backwards. Match that state for fixture creation.
            targets = [node for node in executor.loader.graph.leaf_nodes() if node[0] != 'progress'] + [before]
            apps = executor.loader.project_state(targets).apps
            theme = apps.get_model('learning', 'LearningTheme').objects.create(slug='migration-theme', title_fr='Test')
            unit = apps.get_model('learning', 'LearningUnit').objects.create(theme_id=theme.pk, slug='migration-unit', title_fr='Test')
            Progress = apps.get_model('progress', 'UnitProgress')
            Progress.objects.create(device_id='legacy-migration', unit_id=unit.pk, lessons_seen=7)
            Progress.objects.create(device_id='secure-migration', device_token='kept-secret', unit_id=unit.pk, best_score_percent=80)
            user = apps.get_model('auth', 'User').objects.create(username='migration-owner')
            Progress.objects.create(device_id='account-migration', user_id=user.pk, device_token='old-account-secret', unit_id=unit.pk)
            snapshot = list(Progress.objects.order_by('pk').values())
            executor = MigrationExecutor(connection)
            executor.migrate([after])
            current = executor.loader.project_state([after]).apps
            migrated = list(current.get_model('progress', 'UnitProgress').objects.order_by('pk').values())
            self.assertEqual([row['account_bound'] for row in migrated], [False, False, True])
            self.assertEqual([{k: v for k, v in row.items() if k != 'account_bound'} for row in migrated], snapshot)
            self.assertEqual(current.get_model('progress', 'ProgressDeviceCredential').objects.count(), 0)
            call_command('makemigrations', check=True, dry_run=True, verbosity=0)
            executor = MigrationExecutor(connection)
            executor.migrate([before])
            old = executor.loader.project_state([before]).apps
            self.assertEqual(list(old.get_model('progress', 'UnitProgress').objects.order_by('pk').values()), snapshot)
        finally:
            MigrationExecutor(connection).migrate([after])

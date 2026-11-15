from datetime import timedelta

from django.core.files.storage import default_storage
from django.core.management.base import BaseCommand
from django.db import transaction
from django.db.models import Q
from django.utils import timezone

from core.media_storage import private_backend
from offline_packs.models import LessonPack


def _list_storage_files(storage, prefix='offline_packs/files'):
    try:
        _, files = storage.listdir(prefix)
    except Exception:
        return []
    return [f'{prefix}/{name}' for name in files]


def _is_older_than(storage, name, min_age_seconds):
    if min_age_seconds <= 0:
        return True
    try:
        modified = storage.get_modified_time(name)
    except Exception:
        return False
    if timezone.is_naive(modified):
        modified = timezone.make_aware(modified, timezone.get_current_timezone())
    return (timezone.now() - modified) >= timedelta(seconds=min_age_seconds)


class Command(BaseCommand):
    help = (
        'Idempotent inventory and reconciliation of LessonPack public/private '
        'storage objects (non-destructive dry-run by default; pass --apply to execute).'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Explicitly run in read-only inventory mode (default behavior).',
        )
        parser.add_argument(
            '--apply',
            action='store_true',
            help='Actually migrate non-published packs and delete verified orphaned objects.',
        )
        parser.add_argument(
            '--min-age-seconds',
            type=int,
            default=300,
            help='Minimum object age in seconds before --apply may delete an orphan (default: 300).',
        )

    def handle(self, *args, **options):
        apply_changes = bool(options['apply']) and not bool(options['dry_run'])
        min_age_seconds = max(0, int(options['min_age_seconds']))
        priv_storage = private_backend()

        # 1) Non-published packs still referencing public `file`
        misplaced = LessonPack.objects.exclude(status=LessonPack.PUBLISHED).exclude(file='')
        self.stdout.write(f'Misplaced non-published packs with public file: {misplaced.count()}')
        if apply_changes:
            for pack in misplaced:
                with transaction.atomic():
                    locked = LessonPack.objects.select_for_update().get(pk=pack.pk)
                    if locked.status != LessonPack.PUBLISHED and locked.file:
                        locked.save()
                self.stdout.write(f'  Reconciled pack={pack.slug} status={pack.status}')

        # 2) List storage objects BEFORE querying DB references so in-flight creations
        #    cannot appear in listdir() while missing from a stale DB snapshot.
        public_objects = _list_storage_files(default_storage)
        private_objects = _list_storage_files(priv_storage)

        referenced_all = set(
            LessonPack.objects.exclude(file='').values_list('file', flat=True)
        ) | set(
            LessonPack.objects.exclude(private_file='').values_list('private_file', flat=True)
        )

        public_orphans = [name for name in public_objects if name not in referenced_all]
        private_orphans = [name for name in private_objects if name not in referenced_all]

        self.stdout.write(f'Public storage orphans: {len(public_orphans)}')
        self._process_orphans(default_storage, public_orphans, 'public', apply_changes, min_age_seconds)

        self.stdout.write(f'Private storage orphans: {len(private_orphans)}')
        self._process_orphans(priv_storage, private_orphans, 'private', apply_changes, min_age_seconds)

    def _process_orphans(self, storage, orphans, label, apply_changes, min_age_seconds):
        for name in orphans:
            self.stdout.write(f'  [{label} orphan] {name}')
            if not apply_changes:
                continue
            if not _is_older_than(storage, name, min_age_seconds):
                self.stdout.write(f'  [skipped < {min_age_seconds}s] {name}')
                continue
            # Re-verify against DB right before deletion to prevent deleting newly referenced keys.
            if LessonPack.objects.filter(Q(file=name) | Q(private_file=name)).exists():
                self.stdout.write(f'  [skipped now referenced] {name}')
                continue
            LessonPack._safe_delete_storage_object(storage, name)

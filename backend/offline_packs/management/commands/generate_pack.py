from django.core.management.base import BaseCommand, CommandError

from offline_packs.models import LessonPack
from offline_packs.services.offline_pack_generator import OfflinePackGenerator


class Command(BaseCommand):
    help = 'Generate offline ZIP pack.'

    def add_arguments(self, parser):
        parser.add_argument('slug', type=str)

    def handle(self, *args, **options):
        slug = options['slug']

        try:
            pack = LessonPack.objects.get(slug=slug)
        except LessonPack.DoesNotExist:
            raise CommandError(f'Pack not found: {slug}')

        generator = OfflinePackGenerator(pack)
        generator.generate()

        self.stdout.write(
            self.style.SUCCESS(
                f'Pack generated successfully: {pack.title_fr} v{pack.version}'
            )
        )

        if pack.file:
            self.stdout.write(f'File: {pack.file.url}')

        self.stdout.write(f'Items: {pack.items_count}')
        self.stdout.write(f'Size MB: {pack.size_mb}')
        self.stdout.write(f'Checksum: {pack.checksum}')
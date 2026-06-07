from django.core.management.base import BaseCommand

from alphabet.models import Character


class Command(BaseCommand):
    help = 'Seed 50 Beriya Erfe Unicode characters.'

    def handle(self, *args, **options):
        code_points = [
            *range(0x16EA0, 0x16EB8 + 1),
            *range(0x16EBB, 0x16ED3 + 1),
        ]

        created = 0
        updated = 0

        for index, code_point in enumerate(code_points, start=1):
            symbol = chr(code_point)
            unicode_code = f'U+{code_point:04X}'

            character, was_created = Character.objects.get_or_create(
                unicode_code=unicode_code,
                defaults={
                    'symbol': symbol,
                    'order_index': index,
                    'validation_status': Character.REVIEW,
                    'is_active': True,
                    'available_offline': True,
                },
            )

            if was_created:
                created += 1
                continue

            changed = False

            if character.symbol != symbol:
                character.symbol = symbol
                changed = True

            if character.order_index != index:
                character.order_index = index
                changed = True

            if changed:
                character.save()
                updated += 1

        self.stdout.write(
            self.style.SUCCESS(
                f'Beriya Erfe characters seeded. Created={created}, Updated={updated}, Total={len(code_points)}'
            )
        )
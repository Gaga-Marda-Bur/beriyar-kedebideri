from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from alphabet.models import Character
from learning.models import LearningTheme, LearningUnit
from lessons.models import Lesson
from quizzes.models import QuizQuestion


ERF_UNIT_SLUGS = [
    'bk-preprod-erf-01',
    'bk-preprod-erf-02',
    'bk-preprod-erf-03',
    'bk-preprod-erf-04',
    'bk-preprod-erf-05',
]

NON_AUDIO_QUESTION_TYPES = {
    QuizQuestion.TEXT_TO_CHARACTER,
}


class Command(BaseCommand):
    help = (
        'Enregistre la validation linguistique humaine des 25 lettres Erfe et des 5 leçons '
        'ERF-01..ERF-05 pour un fonctionnement sans audio (candidat non publié).'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--validated-by',
            type=str,
            default='responsable_linguistique',
            help='Identifiant ou nom du valideur linguistique.',
        )
        parser.add_argument(
            '--validated-on',
            type=str,
            default='2026-11-14',
            help='Date de décision (YYYY-MM-DD).',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Simule la validation sans modifier la base.',
        )

    def handle(self, *args, **options):
        validated_by = options['validated_by']
        validated_on = options['validated_on']
        dry_run = bool(options['dry_run'])

        with transaction.atomic():
            theme = LearningTheme.objects.filter(slug='bk-preprod-alphabet-erfe').first()
            if theme is None:
                raise CommandError(
                    "Thème 'bk-preprod-alphabet-erfe' introuvable. Exécutez d'abord import_preprod_courses."
                )

            if theme.status != LearningTheme.PUBLISHED:
                theme.status = LearningTheme.VALIDATED
                theme.save(update_fields=['status', 'updated_at'])

            units = list(LearningUnit.objects.filter(slug__in=ERF_UNIT_SLUGS).order_by('order_index'))
            if len(units) != 5:
                raise CommandError(
                    f'Attendu 5 unités ERF-01..ERF-05, trouvé {len(units)}.'
                )

            validated_chars = 0
            activated_non_audio_quizzes = 0
            disabled_audio_quizzes = 0

            decision_trace = {
                'status': 'validated',
                'validated_by': validated_by,
                'validated_on': validated_on,
                'audio_mode': 'audio_optional_pending',
                'note': '25 lettres Erfe et ERF-01..ERF-05 validées linguistiquement ; audios à enregistrer ultérieurement.',
            }

            for unit in units:
                cfg = dict(unit.pedagogy_config) if isinstance(unit.pedagogy_config, dict) else {}
                cfg['linguistic_validation'] = decision_trace
                cfg['human_edited'] = True
                cfg['audio_optional'] = True
                unit.pedagogy_config = cfg
                if unit.status != LearningUnit.PUBLISHED:
                    unit.status = LearningUnit.VALIDATED
                unit.save(update_fields=['pedagogy_config', 'status', 'updated_at'])

                for lesson in Lesson.objects.filter(unit=unit):
                    if lesson.status != Lesson.PUBLISHED:
                        lesson.status = Lesson.VALIDATED
                        lesson.oral_intro_fr = 'Parcours validé sans audio (enregistrements audio à venir).'
                        lesson.save(update_fields=['status', 'oral_intro_fr', 'updated_at'])

                for char in unit.characters.all():
                    if char.validation_status != Character.PUBLISHED:
                        char.validation_status = Character.VALIDATED
                        char.save(update_fields=['validation_status', 'updated_at'])
                    validated_chars += 1

                for q in QuizQuestion.objects.filter(unit=unit):
                    has_audio = q.audio_links.exists()
                    if q.question_type in NON_AUDIO_QUESTION_TYPES:
                        if q.status != QuizQuestion.PUBLISHED:
                            q.status = QuizQuestion.VALIDATED
                        q.is_active = True
                        q.save(update_fields=['status', 'is_active', 'updated_at'])
                        activated_non_audio_quizzes += 1
                    elif not has_audio:
                        if q.status != QuizQuestion.PUBLISHED:
                            q.status = QuizQuestion.DRAFT
                        q.is_active = False
                        q.save(update_fields=['status', 'is_active', 'updated_at'])
                        disabled_audio_quizzes += 1

            if dry_run:
                transaction.set_rollback(True)

        mode = 'DRY-RUN' if dry_run else 'VALIDATION ENREGISTRÉE'
        self.stdout.write(
            self.style.SUCCESS(
                f'[{mode}] units={len(units)} | chars_validated={validated_chars} | '
                f'non_audio_quizzes_active={activated_non_audio_quizzes} | '
                f'audio_quizzes_disabled={disabled_audio_quizzes}'
            )
        )

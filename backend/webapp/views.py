from django.shortcuts import get_object_or_404, render

from alphabet.models import Character
from learning.models import LearningTheme, LearningUnit
from no_ena.models import NoEnaPublication
from offline_packs.models import LessonPack
from vocabulary.models import Word


def home(request):
    featured_no_ena = NoEnaPublication.objects.filter(
        is_active=True,
        status=NoEnaPublication.PUBLISHED,
    ).select_related(
        'primary_audio_asset',
        'related_character',
        'related_word',
        'related_unit',
    ).order_by(
        '-is_featured',
        'order_index',
        '-published_at',
    )[:3]

    learning_themes = LearningTheme.objects.filter(
        is_active=True,
        status=LearningTheme.PUBLISHED,
    ).prefetch_related(
        'units',
    ).order_by(
        'level',
        'order_index',
    )[:3]

    starter_pack = LessonPack.objects.filter(
        is_active=True,
        status=LessonPack.PUBLISHED,
        is_featured=True,
    ).order_by(
        'level',
        'title_fr',
    ).first()

    stats = {
        'themes_count': LearningTheme.objects.filter(is_active=True).count(),
        'units_count': LearningUnit.objects.filter(is_active=True).count(),
        'no_ena_count': NoEnaPublication.objects.filter(
            is_active=True,
            status=NoEnaPublication.PUBLISHED,
        ).count(),
    }

    return render(
        request,
        'webapp/home.html',
        {
            'featured_no_ena': featured_no_ena,
            'learning_themes': learning_themes,
            'starter_pack': starter_pack,
            'stats': stats,
        },
    )


def alphabet_page(request):
    characters = Character.objects.filter(
        is_active=True,
    ).prefetch_related(
        'audio_links__audio_asset',
    ).order_by(
        'order_index',
        'unicode_code',
    )

    return render(
        request,
        'webapp/alphabet.html',
        {
            'characters': characters,
        },
    )


def vocabulary_page(request):
    search = request.GET.get('q', '').strip()
    category = request.GET.get('category', '').strip()

    words = Word.objects.filter(
        is_active=True,
    ).select_related(
        'category',
    ).prefetch_related(
        'audio_links__audio_asset',
    )

    if search:
        words = (
            words.filter(beriya_text__icontains=search)
            | words.filter(latin_transcription__icontains=search)
            | words.filter(french_translation__icontains=search)
            | words.filter(english_translation__icontains=search)
            | words.filter(arabic_translation__icontains=search)
        )

    if category:
        words = words.filter(category__slug=category)

    words = words.order_by(
        'difficulty_order',
        'beriya_text',
    )

    categories = []

    try:
        from vocabulary.models import WordCategory

        categories = WordCategory.objects.filter(
            is_active=True,
        ).order_by(
            'order_index',
            'name_fr',
        )
    except Exception:
        categories = []

    return render(
        request,
        'webapp/vocabulary.html',
        {
            'words': words,
            'categories': categories,
            'search': search,
            'selected_category': category,
        },
    )


def learning_path_page(request):
    themes = LearningTheme.objects.filter(
        is_active=True,
    ).prefetch_related(
        'units',
        'units__characters',
        'units__words',
    ).order_by(
        'level',
        'order_index',
    )

    return render(
        request,
        'webapp/learning_path.html',
        {
            'themes': themes,
        },
    )


def unit_detail_page(request, slug):
    unit = get_object_or_404(
        LearningUnit.objects.select_related(
            'theme',
        ).prefetch_related(
            'characters',
            'characters__audio_links__audio_asset',
            'words',
            'words__category',
            'words__audio_links__audio_asset',
            'lessons',
            'lessons__items',
            'quiz_questions',
            'quiz_questions__options',
        ),
        slug=slug,
        is_active=True,
    )

    lessons = unit.lessons.filter(
        is_active=True,
    ).prefetch_related(
        'items',
        'items__character',
        'items__word',
        'items__audio_links__audio_asset',
    ).order_by(
        'order_index',
        'title_fr',
    )

    quizzes = unit.quiz_questions.filter(
        is_active=True,
    ).prefetch_related(
        'options',
        'audio_links__audio_asset',
    ).order_by(
        'order_index',
        'id',
    )

    return render(
        request,
        'webapp/unit_detail.html',
        {
            'unit': unit,
            'lessons': lessons,
            'quizzes': quizzes,
        },
    )


def no_ena_list_page(request):
    publication_type = request.GET.get('type', '').strip()

    publications = NoEnaPublication.objects.filter(
        is_active=True,
        status=NoEnaPublication.PUBLISHED,
    ).select_related(
        'primary_audio_asset',
        'related_character',
        'related_word',
        'related_unit',
    )

    if publication_type:
        publications = publications.filter(publication_type=publication_type)

    publications = publications.order_by(
        '-is_featured',
        'order_index',
        '-published_at',
        '-created_at',
    )

    return render(
        request,
        'webapp/no_ena_list.html',
        {
            'publications': publications,
            'selected_type': publication_type,
            'publication_types': NoEnaPublication.PUBLICATION_TYPE_CHOICES,
        },
    )


def no_ena_detail_page(request, slug):
    publication = get_object_or_404(
        NoEnaPublication.objects.select_related(
            'primary_audio_asset',
            'related_character',
            'related_word',
            'related_unit',
        ),
        slug=slug,
        is_active=True,
        status=NoEnaPublication.PUBLISHED,
    )

    publication.view_count += 1
    publication.save(update_fields=['view_count'])

    related_publications = NoEnaPublication.objects.filter(
        is_active=True,
        status=NoEnaPublication.PUBLISHED,
    ).exclude(
        id=publication.id,
    ).order_by(
        '-is_featured',
        '-published_at',
    )[:3]

    return render(
        request,
        'webapp/no_ena_detail.html',
        {
            'publication': publication,
            'related_publications': related_publications,
        },
    )
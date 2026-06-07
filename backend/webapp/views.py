from django.shortcuts import render

from learning.models import LearningTheme, LearningUnit
from no_ena.models import NoEnaPublication
from offline_packs.models import LessonPack


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
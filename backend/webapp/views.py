from django.shortcuts import get_object_or_404, redirect, render

from alphabet.models import Character
from learning.models import LearningTheme, LearningUnit
from no_ena.models import NoEnaPublication
from offline_packs.models import LessonPack
from vocabulary.models import Word
from django.contrib import messages
from feedback.models import FeedbackReport
from quizzes.models import QuizQuestion
from pathlib import Path

from django.conf import settings
from django.http import FileResponse, Http404

def get_web_lang(request):
    lang = request.GET.get("lang") or request.session.get("web_lang") or "fr"

    if lang not in ["fr", "en", "ar"]:
        lang = "fr"

    request.session["web_lang"] = lang
    return lang

def home(request):
    lang = get_web_lang(request)
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
            "current_lang": lang,
            "is_rtl": lang == "ar",
        },
    )


def alphabet_page(request):
    lang = get_web_lang(request)
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
            "current_lang": lang,
            "is_rtl": lang == "ar",
        },
    )


def vocabulary_page(request):
    lang = get_web_lang(request)
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
            "current_lang": lang,
            "is_rtl": lang == "ar",
        },
    )


def learning_path_page(request):
    lang = get_web_lang(request)
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
            "current_lang": lang,
            "is_rtl": lang == "ar",
        },
    )


def unit_detail_page(request, slug):
    lang = get_web_lang(request)
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
            "current_lang": lang,
            "is_rtl": lang == "ar",
        },
    )


def no_ena_list_page(request):
    lang = get_web_lang(request)
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
            "current_lang": lang,
            "is_rtl": lang == "ar",
        },
    )


def no_ena_detail_page(request, slug):
    lang = get_web_lang(request)
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
            "current_lang": lang,
            "is_rtl": lang == "ar",
        },
    )

def feedback_page(request):
    lang = get_web_lang(request)
    if request.method == "POST":
        feedback_type = request.POST.get("feedback_type", FeedbackReport.OTHER)
        title = request.POST.get("title", "").strip()
        message = request.POST.get("message", "").strip()
        language_code = request.POST.get("language_code", "fr")

        if not title and not message:
            messages.error(request, "Merci d’écrire un message avant d’envoyer.")
            return redirect("web-feedback")

        FeedbackReport.objects.create(
            feedback_type=feedback_type,
            title=title,
            message=message,
            platform="web",
            language_code=language_code,
        )

        messages.success(request, "Feedback envoyé. Merci !")
        return redirect("web-feedback")

    feedback_types = FeedbackReport.FEEDBACK_TYPE_CHOICES

    return render(
        request,
        "webapp/feedback.html",
        {
            "feedback_types": feedback_types,
            "current_lang": lang,
            "is_rtl": lang == "ar",
        },
    )


def quiz_page(request):
    lang = request.GET.get("lang", "fr")
    if lang not in ["fr", "en", "ar"]:
        lang = "fr"

    unit_slug = request.GET.get("unit")

    quizzes = QuizQuestion.objects.filter(
        is_active=True,
        status=QuizQuestion.PUBLISHED,
    ).select_related(
        "unit",
        "lesson",
        "character",
        "word",
    ).prefetch_related(
        "options",
        "options__character",
        "options__word",
        "audio_links__audio_asset",
    ).order_by(
        "unit__order_index",
        "lesson__order_index",
        "order_index",
        "id",
    )

    if unit_slug:
        quizzes = quizzes.filter(unit__slug=unit_slug)

    return render(
        request,
        "webapp/quiz.html",
        {
            "quizzes": quizzes,
            "current_lang": lang,
            "is_rtl": lang == "ar",
        },
    )

def android_apk_download(request):
    apk_path = Path(settings.MEDIA_ROOT) / "downloads" / "beriyar-kedebideri-v1.apk"

    if not apk_path.exists():
        raise Http404("APK file not found.")

    return FileResponse(
        open(apk_path, "rb"),
        as_attachment=True,
        filename="beriyar-kedebideri-v1.apk",
        content_type="application/vnd.android.package-archive",
    )

def sticker_studio_page(request):
    lang = get_web_lang(request)

    return render(
        request,
        "webapp/sticker_studio.html",
        {
            "current_lang": lang,
            "is_rtl": lang == "ar",
        },
    )
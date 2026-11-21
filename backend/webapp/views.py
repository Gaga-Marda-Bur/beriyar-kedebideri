from pathlib import Path
from urllib.parse import urlsplit

from django.conf import settings
from django.contrib import messages
from django.contrib.auth import authenticate
from django.db.models import Prefetch, Q
from django.http import FileResponse, Http404
from django.shortcuts import get_object_or_404, redirect, render

from alphabet.models import Character
from core.erfe_search import erfe_search_expression
from core.permissions import PILOT_ALLOWED_UNIT_SLUGS, filter_by_access, is_pilot_user, is_staff_preview
from core.transliteration import normalize_erfe
from feedback.models import FeedbackReport
from learning.models import LearningTheme, LearningUnit
from no_ena.models import NoEnaPublication
from no_ena.services import record_publication_view
from offline_packs.models import LessonPack
from quizzes.models import QuizQuestion
from vocabulary.models import Word

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
        "primary_audio_asset",
        "related_character",
        "related_word",
        "related_unit",
    ).order_by(
        "-is_featured",
        "order_index",
        "-published_at",
    )[:3]

    learning_themes = LearningTheme.objects.filter(
        is_active=True,
        status=LearningTheme.PUBLISHED,
    ).prefetch_related(
        "units",
    ).order_by(
        "level",
        "order_index",
    )[:3]

    chars_qs = Character.objects.filter(is_active=True)
    if not is_staff_preview(request):
        chars_qs = chars_qs.filter(validation_status='published')
    showcase_characters = chars_qs.order_by(
        "order_index",
        "unicode_code",
    )[:6]

    starter_pack = LessonPack.objects.filter(
        is_active=True,
        status=LessonPack.PUBLISHED,
        is_featured=True,
    ).order_by(
        "level",
        "title_fr",
    ).first()

    stats = {
        "themes_count": LearningTheme.objects.filter(
            is_active=True,
            status=LearningTheme.PUBLISHED,
        ).count(),
        "units_count": LearningUnit.objects.filter(
            is_active=True,
            status=LearningUnit.PUBLISHED,
        ).count(),
        "no_ena_count": NoEnaPublication.objects.filter(
            is_active=True,
            status=NoEnaPublication.PUBLISHED,
        ).count(),
    }

    return render(
        request,
        "webapp/home.html",
        {
            "featured_no_ena": featured_no_ena,
            "learning_themes": learning_themes,
            "showcase_characters": showcase_characters,
            "starter_pack": starter_pack,
            "stats": stats,
            "current_lang": lang,
            "is_rtl": lang == "ar",
        },
    )

def alphabet_page(request):
    lang = get_web_lang(request)
    characters_qs = Character.objects.filter(is_active=True)
    if not is_staff_preview(request):
        characters_qs = characters_qs.filter(validation_status='published')
    characters = characters_qs.prefetch_related(
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

    words_qs = Word.objects.filter(is_active=True)
    if not is_staff_preview(request):
        words_qs = words_qs.filter(validation_status='published')
    words = words_qs.select_related(
        'category',
    ).prefetch_related(
        'audio_links__audio_asset',
    )

    if search:
        words = words.alias(_erfe_search=erfe_search_expression('beriya_text', search))
        words = (
            words.filter(_erfe_search__icontains=normalize_erfe(search))
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
    themes_qs = LearningTheme.objects.filter(is_active=True)
    themes_qs = filter_by_access(
        themes_qs,
        request,
        pilot_q=Q(units__slug__in=PILOT_ALLOWED_UNIT_SLUGS, units__status='validated', units__is_active=True),
    )

    units_qs = filter_by_access(
        LearningUnit.objects.filter(is_active=True),
        request,
        pilot_q=Q(slug__in=PILOT_ALLOWED_UNIT_SLUGS),
    ).order_by('order_index', 'title_fr')

    chars_qs = filter_by_access(
        Character.objects.filter(is_active=True),
        request,
        status_field='validation_status',
        pilot_q=Q(learning_units__slug__in=PILOT_ALLOWED_UNIT_SLUGS),
    ).order_by('order_index', 'id')

    words_qs = filter_by_access(
        Word.objects.filter(is_active=True),
        request,
        status_field='validation_status',
    ).order_by('difficulty_order', 'beriya_text')

    themes = themes_qs.prefetch_related(
        Prefetch('units', queryset=units_qs),
        Prefetch('units__characters', queryset=chars_qs),
        Prefetch('units__words', queryset=words_qs),
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
    units_qs = LearningUnit.objects.select_related('theme')
    units_qs = filter_by_access(
        units_qs,
        request,
        pilot_q=Q(slug__in=PILOT_ALLOWED_UNIT_SLUGS),
    )
    if not is_staff_preview(request):
        theme_q = Q(theme__is_active=True, theme__status=LearningTheme.PUBLISHED)
        if is_pilot_user(request):
            theme_q |= Q(theme__is_active=True, slug__in=PILOT_ALLOWED_UNIT_SLUGS)
        units_qs = units_qs.filter(theme_q)

    unit = get_object_or_404(
        units_qs,
        slug=slug,
        is_active=True,
    )

    char_pilot_q = Q(pk__in=unit.characters.values_list('pk', flat=True)) if unit.slug in PILOT_ALLOWED_UNIT_SLUGS else None
    unit_characters = filter_by_access(
        unit.characters.filter(is_active=True),
        request,
        status_field='validation_status',
        pilot_q=char_pilot_q,
    ).prefetch_related('audio_links__audio_asset').order_by('order_index', 'id')

    unit_words = filter_by_access(
        unit.words.filter(is_active=True),
        request,
        status_field='validation_status',
    ).select_related('category').prefetch_related('audio_links__audio_asset').order_by('difficulty_order', 'beriya_text')

    lessons = filter_by_access(
        unit.lessons.filter(is_active=True),
        request,
        pilot_q=Q(unit__slug__in=PILOT_ALLOWED_UNIT_SLUGS),
    ).prefetch_related(
        'items',
        'items__character',
        'items__word',
        'items__audio_links__audio_asset',
    ).order_by(
        'order_index',
        'title_fr',
    )

    quizzes = filter_by_access(
        unit.quiz_questions.filter(is_active=True),
        request,
        pilot_q=Q(unit__slug__in=PILOT_ALLOWED_UNIT_SLUGS),
    ).prefetch_related(
        'options',
        'audio_links__audio_asset',
    ).order_by(
        'order_index',
        'id',
    )

    core_flow_steps = unit.generate_core_flow(request=request, lang=lang)
    core_flow_actionable_count = sum(
        1 for step in core_flow_steps if step.get('step_type') != 'celebration'
    )

    return render(
        request,
        'webapp/unit_detail.html',
        {
            'unit': unit,
            'unit_characters': unit_characters,
            'unit_words': unit_words,
            'lessons': lessons,
            'quizzes': quizzes,
            'core_flow_steps': core_flow_steps,
            'core_flow_actionable_count': core_flow_actionable_count,
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

    record_publication_view(publication, request=request)

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
    from feedback.forms import FeedbackForm
    from feedback.throttles import check_submission_limits
    from feedback.validation import message as feedback_message, humanize_wait
    lang = get_web_lang(request)
    form = FeedbackForm(request.POST if request.method == 'POST' else None, lang=lang)
    response_status = 200

    if request.method == "POST":
        valid = form.is_valid()
        wait = check_submission_limits(request)
        if wait is not None:
            form.add_error(None, feedback_message('throttled', lang, wait=humanize_wait(wait, lang)))
            response_status = 429
        elif valid:
            FeedbackReport.objects.create(
                **form.cleaned_data, platform='web',
                user=request.user if request.user.is_authenticated else None,
            )
            messages.success(request, {
                'ar': 'تم إرسال الملاحظة. شكرًا لك!',
                'en': 'Feedback sent. Thank you!',
                'fr': 'Feedback envoyé. Merci !',
            }[lang])
            return redirect('web-feedback')
        else:
            response_status = 400

    feedback_types = FeedbackReport.FEEDBACK_TYPE_CHOICES

    response = render(
        request,
        "webapp/feedback.html",
        {
            "feedback_types": feedback_types,
            "current_lang": lang,
            "is_rtl": lang == "ar",
            "form": form,
        },
        status=response_status,
    )
    if response_status == 429:
        response['Retry-After'] = str(max(1, int(wait + 0.999)))
    return response


def quiz_page(request):
    lang = get_web_lang(request)

    unit_slug = request.GET.get("unit")

    quizzes = filter_by_access(
        QuizQuestion.objects.filter(is_active=True),
        request,
        pilot_q=Q(unit__slug__in=PILOT_ALLOWED_UNIT_SLUGS),
    )
    if not is_staff_preview(request):
        unit_q = Q(unit__isnull=True) | Q(
            unit__is_active=True,
            unit__status=LearningUnit.PUBLISHED,
            unit__theme__is_active=True,
            unit__theme__status=LearningTheme.PUBLISHED,
        )
        if is_pilot_user(request):
            unit_q |= Q(
                unit__is_active=True,
                unit__status=LearningUnit.VALIDATED,
                unit__slug__in=PILOT_ALLOWED_UNIT_SLUGS,
                unit__theme__is_active=True,
            )
        quizzes = quizzes.filter(unit_q).distinct()

    quizzes = quizzes.select_related(
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


def editor_page(request):
    lang = get_web_lang(request)

    return render(
        request,
        "webapp/editor.html",
        {
            "current_lang": lang,
            "is_rtl": lang == "ar",
        },
    )


def privacy_page(request):
    lang = get_web_lang(request)

    return render(
        request,
        "webapp/privacy.html",
        {
            "current_lang": lang,
            "is_rtl": lang == "ar",
            "privacy_draft_incomplete": True,
        },
    )


def _is_authorized_apk_release_url(url: str) -> bool:
    if not url:
        return False
    parsed = urlsplit(url)
    allowed_hosts = {"media.beriyarkedebideri.com", "beriyarkedebideri.com"}
    r2_domain = (getattr(settings, "R2_PUBLIC_DOMAIN", "") or "").strip().lower()
    if r2_domain:
        allowed_hosts.add(r2_domain)
    return (
        parsed.scheme == "https"
        and bool(parsed.hostname)
        and parsed.hostname.lower() in allowed_hosts
        and not parsed.username
        and not parsed.password
        and parsed.path.lower().endswith(".apk")
        and "beriyar-kedebideri-v1.apk" not in url
    )


def mobile_download_page(request):
    lang = get_web_lang(request)
    configured_url = (getattr(settings, "ANDROID_APK_RELEASE_URL", "") or "").strip()
    apk_download_enabled = _is_authorized_apk_release_url(configured_url)

    return render(
        request,
        "webapp/mobile.html",
        {
            "current_lang": lang,
            "is_rtl": lang == "ar",
            "apk_download_enabled": apk_download_enabled,
            "apk_download_url": configured_url if apk_download_enabled else "",
            "apk_package_id": "com.afrigama.beriyarkedebideri",
            "apk_version": "1.1.3+7",
            "apk_version_code": 7,
            "apk_size_bytes": "70 694 649",
            "apk_sha256": "6B02C6B07C8E819F4E85D54C2284EFBB49296BD6F9216D5D04377E6E6C43D6F1",
        },
    )


def account_deletion_page(request):
    from core.auth_views import LearnerDeletionThrottle
    from core.models import AccountDeletionRequest

    lang = get_web_lang(request)
    deletion_result = None
    deletion_error = None
    existing_request = None
    status_code = 200

    if request.user.is_authenticated and request.user.is_active:
        existing_request = AccountDeletionRequest.objects.filter(
            user=request.user,
            status__in=[
                AccountDeletionRequest.STATUS_PENDING,
                AccountDeletionRequest.STATUS_IN_REVIEW,
            ],
        ).first()

        if request.method == "POST":
            if not LearnerDeletionThrottle().allow_request(request, None):
                status_code = 429
                if lang == "ar":
                    deletion_error = "تم تجاوز الحد المسموح به من الطلبات. يرجى المحاولة لاحقاً."
                elif lang == "en":
                    deletion_error = "Too many requests. Please try again later."
                else:
                    deletion_error = "Trop de tentatives. Veuillez réessayer plus tard."
            else:
                password = request.POST.get("password", "")
                note = (request.POST.get("note", "") or "").strip()[:500]
                verified_user = authenticate(
                    request,
                    username=request.user.get_username(),
                    password=password,
                )
                if verified_user is None or verified_user.pk != request.user.pk:
                    if lang == "ar":
                        deletion_error = "كلمة المرور غير صحيحة."
                    elif lang == "en":
                        deletion_error = "Incorrect password."
                    else:
                        deletion_error = "Mot de passe incorrect."
                elif existing_request is not None:
                    deletion_result = existing_request
                else:
                    deletion_result = AccountDeletionRequest.objects.create(
                        user=request.user,
                        requested_username=request.user.get_username(),
                        has_email=bool((request.user.email or "").strip()),
                        source=AccountDeletionRequest.SOURCE_WEB,
                        verification_method="session_and_password",
                        status=AccountDeletionRequest.STATUS_PENDING,
                        user_note=note,
                    )
                    existing_request = deletion_result

    response = render(
        request,
        "webapp/account_deletion.html",
        {
            "current_lang": lang,
            "is_rtl": lang == "ar",
            "deletion_result": deletion_result,
            "deletion_error": deletion_error,
            "existing_request": existing_request,
        },
        status=status_code,
    )
    if request.user.is_authenticated or request.method == "POST":
        response["Cache-Control"] = "private, no-store"
        response["Vary"] = "Cookie"
    return response

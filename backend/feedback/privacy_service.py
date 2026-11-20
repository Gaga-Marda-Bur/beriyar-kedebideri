"""
Services de suppression contrôlée des médias de feedback (R2/stockage privé),
de caviardage/suppression des données personnelles dans les champs libres,
et de diagnostic non destructif de conservation.

Règles de sécurité :
- Aucune purge automatique ni tâche planifiée.
- Validation stricte des préfixes autorisés (feedback/screenshots/, feedback/audio/).
- Protection absolue des médias pédagogiques (audio_assets/files/, packs hors ligne, etc.).
- Opérations idempotentes sans fausse atomicité PostgreSQL/R2 : en cas d'échec
  de suppression distante, la référence en base n'est pas effacée silencieusement.
- Aucun secret R2, aucune URL signée et aucun texte PII original ne sont journalisés.
"""

from dataclasses import dataclass, field
from datetime import timedelta
import posixpath
import re
from typing import Iterable, List, Optional

from django.db.models import Q
from django.utils import timezone

from audio_assets.models import AudioAsset
from .models import FeedbackReport

ALLOWED_SCREENSHOT_PREFIX = 'feedback/screenshots/'
ALLOWED_AUDIO_PREFIX = 'feedback/audio/'

REDACTED_MESSAGE_PLACEHOLDER = '[Contenu personnel supprimé par l’administration]'
REDACTED_TITLE_PLACEHOLDER = '[Supprimé]'

_EMAIL_HINT_RE = re.compile(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
_PHONE_HINT_RE = re.compile(r'(?:\+?\d[\d\s().-]{7,}\d)')


@dataclass
class MediaPurgeItem:
    kind: str  # 'screenshot' | 'audio'
    path: str
    status: str  # 'would_delete' | 'deleted' | 'already_absent' | 'failed' | 'rejected'
    detail: str = ''


@dataclass
class MediaPurgeReport:
    feedback_id: int
    dry_run: bool
    overall_status: str = 'noop'  # 'noop' | 'dry_run' | 'completed' | 'partial' | 'failed' | 'rejected'
    items: List[MediaPurgeItem] = field(default_factory=list)


@dataclass
class RedactionResult:
    feedback_id: int
    dry_run: bool
    mode: str
    changed_fields: List[str] = field(default_factory=list)
    pii_hints: List[str] = field(default_factory=list)


def validate_feedback_media_path(path: str, *, kind: str) -> tuple[bool, str]:
    """
    Valide qu'un chemin de fichier appartient strictement à l'espace de feedback
    autorisé et ne représente ni un chemin pédagogique, ni un traversal, ni un préfixe.
    """
    if not isinstance(path, str) or not path.strip():
        return False, 'Chemin vide.'

    raw = path.strip()
    if '\x00' in raw or '\\' in raw or '*' in raw or '?' in raw:
        return False, 'Caractères interdits (wildcard, antislash ou octet nul).'
    if raw.startswith('/') or raw.endswith('/'):
        return False, 'Chemin absolu ou suppression par préfixe interdite.'

    normalized = posixpath.normpath(raw)
    if normalized != raw or normalized.startswith('..') or '/../' in f'/{normalized}/':
        return False, 'Traversée de répertoire détectée.'

    expected_prefix = (
        ALLOWED_SCREENSHOT_PREFIX if kind == 'screenshot' else ALLOWED_AUDIO_PREFIX
    )
    if not normalized.startswith(expected_prefix):
        return False, f'Chemin hors préfixe autorisé ({expected_prefix}).'

    filename = normalized[len(expected_prefix):]
    if not filename or '/' in filename:
        return False, 'Nom de fichier direct attendu sous le préfixe autorisé.'

    return True, ''


def _audio_asset_is_shared_or_pedagogical(audio_asset: AudioAsset, feedback: FeedbackReport) -> tuple[bool, str]:
    if audio_asset.audio_type != AudioAsset.FEEDBACK:
        return True, f"AudioAsset de type '{audio_asset.audio_type}' protégé (non feedback)."

    if feedback.audio_feedback_id != audio_asset.pk:
        return True, 'Relation FeedbackReport -> AudioAsset non prouvée.'

    if FeedbackReport.objects.filter(audio_feedback=audio_asset).exclude(pk=feedback.pk).exists():
        return True, 'AudioAsset référencé par un autre FeedbackReport.'

    # Vérifie l'absence de lien avec des modèles pédagogiques/éditoriaux.
    for rel_name in (
        'character_links',
        'word_links',
        'lesson_item_links',
        'quiz_question_links',
        'no_ena_publications',
    ):
        manager = getattr(audio_asset, rel_name, None)
        if manager is not None and manager.exists():
            return True, f'AudioAsset lié à un contenu pédagogique/éditorial ({rel_name}).'

    return False, ''


def feedback_has_attached_media(feedback: FeedbackReport) -> bool:
    has_screenshot = bool(feedback.screenshot and getattr(feedback.screenshot, 'name', ''))
    has_audio = bool(
        feedback.audio_feedback_id
        and feedback.audio_feedback
        and feedback.audio_feedback.file
        and getattr(feedback.audio_feedback.file, 'name', '')
    )
    return has_screenshot or has_audio


def purge_feedback_media(
    feedback: FeedbackReport,
    *,
    dry_run: bool = True,
    storage_resolver=None,
) -> MediaPurgeReport:
    """
    Prévisualise (dry_run=True) ou exécute (dry_run=False) la suppression contrôlée
    des pièces jointes (screenshot et audio_feedback) d'un FeedbackReport précis.
    """
    report = MediaPurgeReport(feedback_id=feedback.pk, dry_run=dry_run)

    # 1. Capture d'écran (FeedbackReport.screenshot)
    screenshot_name = getattr(feedback.screenshot, 'name', '') if feedback.screenshot else ''
    if screenshot_name:
        ok, reason = validate_feedback_media_path(screenshot_name, kind='screenshot')
        if not ok:
            report.items.append(
                MediaPurgeItem(kind='screenshot', path=screenshot_name, status='rejected', detail=reason)
            )
        elif dry_run:
            report.items.append(
                MediaPurgeItem(kind='screenshot', path=screenshot_name, status='would_delete', detail='Capture validée.')
            )
        else:
            storage = (
                storage_resolver('screenshot', feedback.screenshot.storage)
                if storage_resolver is not None
                else feedback.screenshot.storage
            )
            try:
                existed = bool(storage.exists(screenshot_name))
                if existed:
                    storage.delete(screenshot_name)
                    item_status = 'deleted'
                    detail = 'Objet supprimé du stockage.'
                else:
                    item_status = 'already_absent'
                    detail = 'Objet déjà absent du stockage (nettoyage idempotent de la référence).'
            except Exception as exc:
                # Ne pas effacer la référence DB si la suppression distante a échoué.
                report.items.append(
                    MediaPurgeItem(
                        kind='screenshot',
                        path=screenshot_name,
                        status='failed',
                        detail=f'Échec suppression stockage : {type(exc).__name__}',
                    )
                )
            else:
                try:
                    feedback.screenshot = ''
                    feedback.save(update_fields=['screenshot', 'updated_at'])
                    report.items.append(
                        MediaPurgeItem(kind='screenshot', path=screenshot_name, status=item_status, detail=detail)
                    )
                except Exception as exc:
                    report.items.append(
                        MediaPurgeItem(
                            kind='screenshot',
                            path=screenshot_name,
                            status='failed',
                            detail=(
                                f'Stockage traité ({item_status}) mais échec mise à jour DB : '
                                f'{type(exc).__name__} (reprise idempotente requise).'
                            ),
                        )
                    )

    # 2. Audio de feedback (FeedbackReport.audio_feedback)
    if feedback.audio_feedback_id:
        audio_asset = feedback.audio_feedback
        audio_name = getattr(audio_asset.file, 'name', '') if audio_asset and audio_asset.file else ''
        if audio_asset is None:
            report.items.append(
                MediaPurgeItem(kind='audio', path='', status='rejected', detail='AudioAsset introuvable.')
            )
        else:
            protected, prot_reason = _audio_asset_is_shared_or_pedagogical(audio_asset, feedback)
            if protected:
                report.items.append(
                    MediaPurgeItem(kind='audio', path=audio_name, status='rejected', detail=prot_reason)
                )
            else:
                ok, reason = validate_feedback_media_path(audio_name, kind='audio')
                if not ok:
                    report.items.append(
                        MediaPurgeItem(kind='audio', path=audio_name, status='rejected', detail=reason)
                    )
                elif dry_run:
                    report.items.append(
                        MediaPurgeItem(kind='audio', path=audio_name, status='would_delete', detail='Audio feedback validé.')
                    )
                else:
                    storage = (
                        storage_resolver('audio', audio_asset.file.storage)
                        if storage_resolver is not None
                        else audio_asset.file.storage
                    )
                    try:
                        existed = bool(storage.exists(audio_name))
                        if existed:
                            storage.delete(audio_name)
                            item_status = 'deleted'
                            detail = 'Audio feedback supprimé du stockage.'
                        else:
                            item_status = 'already_absent'
                            detail = 'Audio déjà absent du stockage (nettoyage idempotent de la référence).'
                    except Exception as exc:
                        report.items.append(
                            MediaPurgeItem(
                                kind='audio',
                                path=audio_name,
                                status='failed',
                                detail=f'Échec suppression stockage : {type(exc).__name__}',
                            )
                        )
                    else:
                        try:
                            feedback.audio_feedback = None
                            feedback.save(update_fields=['audio_feedback', 'updated_at'])
                            audio_asset.delete()
                            report.items.append(
                                MediaPurgeItem(kind='audio', path=audio_name, status=item_status, detail=detail)
                            )
                        except Exception as exc:
                            report.items.append(
                                MediaPurgeItem(
                                    kind='audio',
                                    path=audio_name,
                                    status='failed',
                                    detail=(
                                        f'Stockage traité ({item_status}) mais échec mise à jour DB : '
                                        f'{type(exc).__name__} (reprise idempotente requise).'
                                    ),
                                )
                            )

    if not report.items:
        report.overall_status = 'noop'
        return report

    statuses = {item.status for item in report.items}
    if dry_run:
        report.overall_status = 'rejected' if statuses == {'rejected'} else 'dry_run'
    else:
        success_statuses = {'deleted', 'already_absent'}
        failure_statuses = {'failed', 'rejected'}
        has_success = bool(statuses & success_statuses)
        has_failure = bool(statuses & failure_statuses)
        if has_success and has_failure:
            report.overall_status = 'partial'
        elif has_failure:
            report.overall_status = 'rejected' if statuses == {'rejected'} else 'failed'
        else:
            report.overall_status = 'completed'
    return report


def detect_potential_pii_hints(*texts: Optional[str]) -> List[str]:
    """
    Aide indicative uniquement : signale des motifs courants (e-mail, téléphone).
    Ne constitue PAS une détection exhaustive ni une anonymisation automatique fiable.
    """
    hints: List[str] = []
    combined = '\n'.join(t for t in texts if isinstance(t, str) and t)
    if _EMAIL_HINT_RE.search(combined):
        hints.append('email_pattern_detected')
    if _PHONE_HINT_RE.search(combined):
        hints.append('phone_pattern_detected')
    return hints


def redact_feedback_pii(
    feedback: FeedbackReport,
    *,
    mode: str = 'clear_all',
    new_title: Optional[str] = None,
    new_message: Optional[str] = None,
    new_admin_note: Optional[str] = None,
    clear_device_id: bool = True,
    clear_user: bool = False,
    clear_admin_note: bool = False,
    dry_run: bool = True,
) -> RedactionResult:
    """
    Supprime ou caviarde manuellement les champs textuels personnels d'un FeedbackReport
    en conservant les métadonnées non personnelles (feedback_type, status, priority,
    app_version, platform, language_code, content_type, object_id).
    """
    if mode not in ('clear_all', 'manual'):
        raise ValueError("Mode de caviardage invalide ('clear_all' ou 'manual').")

    hints = detect_potential_pii_hints(feedback.title, feedback.message, feedback.admin_note)
    result = RedactionResult(
        feedback_id=feedback.pk,
        dry_run=dry_run,
        mode=mode,
        pii_hints=hints,
    )

    update_fields: List[str] = []

    if mode == 'clear_all':
        if feedback.title != REDACTED_TITLE_PLACEHOLDER:
            result.changed_fields.append('title')
            if not dry_run:
                feedback.title = REDACTED_TITLE_PLACEHOLDER
                update_fields.append('title')
        if feedback.message != REDACTED_MESSAGE_PLACEHOLDER:
            result.changed_fields.append('message')
            if not dry_run:
                feedback.message = REDACTED_MESSAGE_PLACEHOLDER
                update_fields.append('message')
        if clear_admin_note and feedback.admin_note:
            result.changed_fields.append('admin_note')
            if not dry_run:
                feedback.admin_note = ''
                update_fields.append('admin_note')
    else:
        if new_title is not None and new_title != feedback.title:
            result.changed_fields.append('title')
            if not dry_run:
                feedback.title = new_title
                update_fields.append('title')
        if new_message is not None and new_message != feedback.message:
            result.changed_fields.append('message')
            if not dry_run:
                feedback.message = new_message
                update_fields.append('message')
        if new_admin_note is not None and new_admin_note != feedback.admin_note:
            result.changed_fields.append('admin_note')
            if not dry_run:
                feedback.admin_note = new_admin_note
                update_fields.append('admin_note')

    if clear_device_id and feedback.device_id:
        result.changed_fields.append('device_id')
        if not dry_run:
            feedback.device_id = ''
            update_fields.append('device_id')

    if clear_user and feedback.user_id is not None:
        result.changed_fields.append('user')
        if not dry_run:
            feedback.user = None
            update_fields.append('user')

    if not dry_run and update_fields:
        update_fields.append('updated_at')
        feedback.save(update_fields=update_fields)

    return result


def get_retention_diagnostics(now=None) -> dict:
    """
    Outil strictement non destructif (lecture seule) pour repérer les éléments
    à examiner manuellement selon les objectifs de conservation.
    """
    ref_now = now or timezone.now()
    cutoff_12m = ref_now - timedelta(days=365)
    cutoff_90d = ref_now - timedelta(days=90)
    closed_statuses = [
        FeedbackReport.FIXED,
        FeedbackReport.ARCHIVED,
        FeedbackReport.REJECTED,
    ]

    closed_over_12m_qs = FeedbackReport.objects.filter(status__in=closed_statuses).filter(
        Q(resolved_at__lt=cutoff_12m) | Q(resolved_at__isnull=True, updated_at__lt=cutoff_12m)
    )

    closed_media_over_90d_qs = (
        FeedbackReport.objects.filter(status__in=closed_statuses)
        .filter(
            Q(resolved_at__lt=cutoff_90d) | Q(resolved_at__isnull=True, updated_at__lt=cutoff_90d)
        )
        .filter(
            (Q(screenshot__isnull=False) & ~Q(screenshot=''))
            | Q(audio_feedback__isnull=False)
        )
    )

    ownerless_with_free_text_qs = (
        FeedbackReport.objects.filter(user__isnull=True)
        .filter(
            (~Q(title='') & ~Q(title=REDACTED_TITLE_PLACEHOLDER))
            | (~Q(message='') & ~Q(message=REDACTED_MESSAGE_PLACEHOLDER))
        )
    )

    unlinked_feedback_audio_qs = AudioAsset.objects.filter(
        audio_type=AudioAsset.FEEDBACK,
        feedback_reports__isnull=True,
    )

    return {
        'reference_time': ref_now,
        'closed_feedbacks_over_12m_count': closed_over_12m_qs.count(),
        'closed_feedbacks_over_12m_ids': list(closed_over_12m_qs.values_list('id', flat=True)),
        'closed_media_over_90d_count': closed_media_over_90d_qs.count(),
        'closed_media_over_90d_ids': list(closed_media_over_90d_qs.values_list('id', flat=True)),
        'ownerless_free_text_count': ownerless_with_free_text_qs.count(),
        'ownerless_free_text_ids': list(ownerless_with_free_text_qs.values_list('id', flat=True)),
        'unlinked_feedback_audio_count': unlinked_feedback_audio_qs.count(),
        'unlinked_feedback_audio_ids': list(unlinked_feedback_audio_qs.values_list('id', flat=True)),
    }

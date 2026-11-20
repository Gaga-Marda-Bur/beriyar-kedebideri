from django.contrib import admin, messages
from django.core.exceptions import PermissionDenied
from django.template.response import TemplateResponse

from .models import FeedbackReport
from .privacy_service import (
    detect_potential_pii_hints,
    feedback_has_attached_media,
    purge_feedback_media,
    redact_feedback_pii,
)


@admin.register(FeedbackReport)
class FeedbackReportAdmin(admin.ModelAdmin):
    actions = ['purge_feedback_media_action', 'redact_feedback_pii_action']
    list_display = [
        'id',
        'feedback_type',
        'title',
        'device_id',
        'content_type',
        'object_id',
        'priority',
        'status',
        'platform',
        'language_code',
        'created_at',
    ]

    list_filter = [
        'feedback_type',
        'priority',
        'status',
        'platform',
        'language_code',
        'created_at',
    ]

    search_fields = [
        'title',
        'message',
        'device_id',
        'admin_note',
        'app_version',
    ]

    raw_id_fields = [
        'user',
        'content_type',
        'audio_feedback',
    ]

    readonly_fields = [
        'device_id',
        'platform',
        'app_version',
        'language_code',
        'client_created_at',
        'synced_at',
        'created_at',
        'updated_at',
    ]

    date_hierarchy = 'created_at'
    list_per_page = 25

    fieldsets = (
        ('Utilisateur / appareil', {
            'fields': (
                'user',
                'device_id',
                'platform',
                'app_version',
                'language_code',
            ),
        }),
        ('Feedback', {
            'fields': (
                'feedback_type',
                'title',
                'message',
                'priority',
                'status',
            ),
        }),
        ('Contenu concerné', {
            'fields': (
                'content_type',
                'object_id',
            ),
        }),
        ('Média', {
            'fields': (
                'audio_feedback',
                'screenshot',
            ),
        }),
        ('Traitement admin', {
            'fields': (
                'admin_note',
                'resolved_at',
            ),
        }),
        ('Dates', {
            'fields': (
                'client_created_at',
                'synced_at',
                'created_at',
                'updated_at',
            ),
        }),
    )

    def delete_model(self, request, obj):
        if feedback_has_attached_media(obj):
            self.message_user(
                request,
                f"Suppression bloquée pour Feedback #{obj.pk} : des médias (capture ou audio) sont encore attachés. "
                "Exécutez d’abord l’action contrôlée « Prévisualiser / purger les médias R2 » pour éviter les fichiers orphelins.",
                level=messages.ERROR,
            )
            return
        super().delete_model(request, obj)

    def delete_queryset(self, request, queryset):
        blocked_ids = [obj.pk for obj in queryset if feedback_has_attached_media(obj)]
        if blocked_ids:
            self.message_user(
                request,
                f"Suppression directe bloquée pour les feedbacks {blocked_ids} contenant encore des médias attachés. "
                "Exécutez d’abord l’action contrôlée « Prévisualiser / purger les médias R2 ».",
                level=messages.ERROR,
            )
            queryset = queryset.exclude(pk__in=blocked_ids)
        if queryset.exists():
            super().delete_queryset(request, queryset)

    @admin.action(description="Prévisualiser / purger les médias R2 des feedbacks sélectionnés")
    def purge_feedback_media_action(self, request, queryset):
        if not (
            request.user.has_perm('feedback.change_feedbackreport')
            and request.user.has_perm('feedback.delete_feedbackreport')
        ):
            raise PermissionDenied("Permissions feedback.change_feedbackreport et delete_feedbackreport requises.")

        if request.POST.get('confirm_execute') == 'yes':
            counts = {'completed': 0, 'partial': 0, 'failed': 0, 'rejected': 0, 'noop': 0}
            for obj in queryset.select_related('audio_feedback'):
                rep = purge_feedback_media(obj, dry_run=False)
                counts[rep.overall_status] = counts.get(rep.overall_status, 0) + 1
            level = (
                messages.ERROR
                if counts['failed'] or counts['rejected']
                else (messages.WARNING if counts['partial'] else messages.SUCCESS)
            )
            self.message_user(
                request,
                f"Purge médias terminée — réussies: {counts['completed']}, partielles: {counts['partial']}, "
                f"échecs: {counts['failed']}, refusées: {counts['rejected']}, sans média: {counts['noop']}.",
                level=level,
            )
            return None

        preview_reports = [
            purge_feedback_media(obj, dry_run=True)
            for obj in queryset.select_related('audio_feedback')
        ]
        context = {
            **self.admin_site.each_context(request),
            'title': 'Confirmation de suppression des médias de feedback',
            'queryset': queryset,
            'preview_reports': preview_reports,
        }
        return TemplateResponse(request, 'admin/feedback/confirm_purge_media.html', context)

    @admin.action(description="Caviarder / supprimer les données personnelles (champs libres)")
    def redact_feedback_pii_action(self, request, queryset):
        if not request.user.has_perm('feedback.change_feedbackreport'):
            raise PermissionDenied("Permission feedback.change_feedbackreport requise.")

        if request.POST.get('confirm_redact') == 'yes':
            mode = request.POST.get('redaction_mode', 'clear_all')
            if mode not in ('clear_all', 'manual'):
                mode = 'clear_all'
            clear_admin_note = request.POST.get('clear_admin_note') == '1'
            clear_user = request.POST.get('clear_user') == '1'
            updated = 0
            for obj in queryset:
                res = redact_feedback_pii(
                    obj,
                    mode=mode,
                    new_title=request.POST.get(f'manual_title_{obj.pk}') if mode == 'manual' else None,
                    new_message=request.POST.get(f'manual_message_{obj.pk}') if mode == 'manual' else None,
                    clear_device_id=True,
                    clear_user=clear_user,
                    clear_admin_note=clear_admin_note,
                    dry_run=False,
                )
                if res.changed_fields:
                    updated += 1
            # Ne jamais inclure le texte original PII dans le message admin.
            self.message_user(
                request,
                f"Caviardage / suppression PII appliqué sur {updated} feedback(s) (mode={mode}).",
                level=messages.SUCCESS,
            )
            return None

        preview_items = [
            {
                'obj': obj,
                'hints': detect_potential_pii_hints(obj.title, obj.message, obj.admin_note),
            }
            for obj in queryset
        ]
        context = {
            **self.admin_site.each_context(request),
            'title': 'Confirmation de caviardage / suppression PII',
            'queryset': queryset,
            'preview_items': preview_items,
        }
        return TemplateResponse(request, 'admin/feedback/confirm_redact_pii.html', context)
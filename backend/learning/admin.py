from django.contrib import admin

from .models import LearningTheme, LearningUnit


class LearningUnitInline(admin.TabularInline):
    model = LearningUnit
    extra = 0
    fields = [
        'title_fr',
        'level',
        'order_index',
        'status',
        'is_active',
        'available_offline',
    ]
    show_change_link = True


@admin.register(LearningTheme)
class LearningThemeAdmin(admin.ModelAdmin):
    list_display = [
        'title_fr',
        'slug',
        'level',
        'order_index',
        'status',
        'units_status_summary',
        'is_active',
        'available_offline',
    ]

    list_filter = [
        'level',
        'status',
        'is_active',
        'available_offline',
    ]

    search_fields = [
        'title_fr',
        'title_en',
        'title_ar',
        'slug',
    ]

    prepopulated_fields = {
        'slug': ('title_fr',),
    }

    readonly_fields = [
        'created_at',
        'updated_at',
    ]

    inlines = [LearningUnitInline]

    @admin.display(description="Unités (Publiées / Total)")
    def units_status_summary(self, obj):
        from django.utils.html import format_html
        total = obj.units.count()
        published = obj.units.filter(status='published').count()
        if total == 0:
            return "0 unité"
        if published == total:
            return format_html('<span style="color: green; font-weight: bold;">{}/{} publiées</span>', published, total)
        return format_html('<span style="color: #e67e22; font-weight: bold;">{}/{} publiées</span>', published, total)

    fieldsets = (
        ('Identité', {
            'fields': (
                'slug',
                'title_fr',
                'title_en',
                'title_ar',
            ),
        }),
        ('Descriptions', {
            'fields': (
                'description_fr',
                'description_en',
                'description_ar',
            ),
        }),
        ('Classement', {
            'fields': (
                'level',
                'order_index',
                'cover_image',
            ),
        }),
        ('Publication & Dépendances', {
            'fields': (
                'status',
                'dependency_status_details',
                'is_active',
                'available_offline',
            ),
        }),
        ('Historique', {
            'fields': (
                'created_at',
                'updated_at',
            ),
        }),
    )


@admin.register(LearningUnit)
class LearningUnitAdmin(admin.ModelAdmin):
    list_display = [
        'title_fr',
        'theme',
        'target_word',
        'status',
        'dependency_status_badge',
        'level',
        'estimated_minutes',
        'order_index',
        'is_active',
        'available_offline',
    ]

    list_filter = [
        'theme',
        'level',
        'status',
        'is_active',
        'available_offline',
    ]

    search_fields = [
        'title_fr',
        'title_en',
        'title_ar',
        'slug',
        'theme__title_fr',
    ]

    prepopulated_fields = {
        'slug': ('title_fr',),
    }

    autocomplete_fields = [
        'theme',
        'target_word',
    ]

    filter_horizontal = [
        'characters',
        'distractor_characters',
        'words',
    ]

    readonly_fields = [
        'dependency_status_details',
        'created_at',
        'updated_at',
        'core_flow_preview',
    ]

    fieldsets = (
        ('Identité', {
            'fields': (
                'theme',
                'slug',
                'title_fr',
                'title_en',
                'title_ar',
            ),
        }),
        ('Descriptions', {
            'fields': (
                'description_fr',
                'description_en',
                'description_ar',
            ),
        }),
        ('Méthode Active (Learning Core)', {
            'description': "Configuration du parcours d'alphabétisation active (Oral -> Visuel -> Geste -> Fusion -> Clavier)",
            'fields': (
                'target_word',
                'characters',
                'distractor_characters',
                'enable_tracing',
                'weight_recognition',
                'weight_tracing',
                'weight_encoding',
                'pedagogy_config',
                'core_flow_preview',
            ),
        }),
        ('Contenu d’accompagnement', {
            'classes': ('collapse',),
            'fields': (
                'words',
            ),
        }),
        ('Progression', {
            'fields': (
                'level',
                'estimated_minutes',
                'min_score_to_pass',
                'order_index',
            ),
        }),
        ('Publication', {
            'fields': (
                'status',
                'is_active',
                'available_offline',
            ),
        }),
        ('Historique', {
            'fields': (
                'created_at',
                'updated_at',
            ),
        }),
    )

    def core_flow_preview(self, obj):
        from django.utils.html import format_html
        if not obj.pk:
            return "Sauvegardez l'unité pour générer l'aperçu du flux."
        steps = obj.generate_core_flow()
        if not steps:
            return "Aucune étape générée. Veuillez sélectionner des caractères et un mot cible."

        rows = []
        for step in steps:
            idx = step.get('index', 0) + 1
            stype = step.get('step_type', '')
            details = []
            if 'symbol' in step:
                details.append(f"<b>Glyphe:</b> {step['symbol']}")
            if 'phoneme_ipa' in step and step['phoneme_ipa'] != 'À_VALIDER':
                details.append(f"<b>Son:</b> /{step['phoneme_ipa']}/")
            if 'target_symbol' in step:
                details.append(f"<b>Cible:</b> {step['target_symbol']} vs {step.get('other_symbol', '')}")
            if 'components' in step:
                details.append(f"<b>Fusion:</b> {' + '.join(step['components'])} &rarr; {step.get('result_syllable', '')}")
            if 'word' in step:
                details.append(f"<b>Mot:</b> {step['word']} ({step.get('french_translation', '')})")
            if 'keyboard_keys' in step:
                details.append(f"<b>Touches clavier:</b> {' '.join(step['keyboard_keys'])}")
            if 'weights' in step:
                w = step['weights']
                details.append(f"<b>Pondérations:</b> Reconnaissance {w.get('recognition')}% | Tracé {w.get('tracing')}% | Encodage {w.get('encoding')}%")

            detail_str = " &nbsp;|&nbsp; ".join(details) if details else step.get('instruction', '')
            rows.append(
                f"<tr>"
                f"<td style='padding:6px 12px; border:1px solid #ddd; text-align:center;'><b>{idx}</b></td>"
                f"<td style='padding:6px 12px; border:1px solid #ddd; font-weight:bold; color:#1b4332;'>{stype}</td>"
                f"<td style='padding:6px 12px; border:1px solid #ddd;'>{detail_str}</td>"
                f"</tr>"
            )

        html = (
            "<div style='max-width:800px; margin-top:8px;'>"
            "<table style='width:100%; border-collapse:collapse; background:#fff; font-size:13px;'>"
            "<thead><tr style='background:#f4f6f8;'>"
            "<th style='padding:6px; border:1px solid #ddd; width:40px;'>#</th>"
            "<th style='padding:6px; border:1px solid #ddd; width:150px;'>Type d'étape</th>"
            "<th style='padding:6px; border:1px solid #ddd;'>Détails & Contenu</th>"
            "</tr></thead>"
            f"<tbody>{''.join(rows)}</tbody>"
            "</table></div>"
        )
        return format_html(html)

    core_flow_preview.short_description = "Aperçu dynamique du flux (Learning Core)"
    @admin.display(description="Dépendances")
    def dependency_status_badge(self, obj):
        from django.utils.html import format_html
        warnings = self._get_dependency_warnings(obj)
        if not warnings:
            return format_html('<span style="color: green; font-weight: bold;">✓ Complètes</span>')
        if obj.status == 'published':
            return format_html(
                '<span style="background: #e74c3c; color: white; padding: 2px 6px; border-radius: 4px; font-weight: bold;" title="{}">⚠️ Bloquantes ({})</span>',
                "; ".join(warnings),
                len(warnings),
            )
        return format_html(
            '<span style="color: #e67e22; font-weight: bold;" title="{}">⚠️ Non publiées ({})</span>',
            "; ".join(warnings),
            len(warnings),
        )

    def _get_dependency_warnings(self, obj):
        warnings = []
        if obj.theme and obj.theme.status != 'published':
            warnings.append(f"Thème '{obj.theme.title_fr}' non publié ({obj.theme.status})")
        if obj.target_word and obj.target_word.validation_status != 'published':
            warnings.append(f"Mot cible '{obj.target_word.beriya_text}' non validé ({obj.target_word.validation_status})")

        unpub_chars = obj.characters.exclude(validation_status='published').count()
        if unpub_chars > 0:
            warnings.append(f"{unpub_chars} caractère(s) non validé(s)")

        unpub_distractors = obj.distractor_characters.exclude(validation_status='published').count()
        if unpub_distractors > 0:
            warnings.append(f"{unpub_distractors} distracteur(s) non validé(s)")

        unpub_words = obj.words.exclude(validation_status='published').count()
        if unpub_words > 0:
            warnings.append(f"{unpub_words} mot(s) d'accompagnement non validé(s)")

        return warnings

    @admin.display(description="Statut des dépendances éditoriales")
    def dependency_status_details(self, obj):
        from django.utils.html import format_html
        if not obj.pk:
            return "Enregistrez l'unité pour analyser les dépendances."
        warnings = self._get_dependency_warnings(obj)
        if not warnings:
            return format_html('<div style="color: #27ae60; font-weight: bold;">✓ Toutes les dépendances (thème, caractères, mots) sont publiées et validées.</div>')
        items = "".join(f"<li>{w}</li>" for w in warnings)
        color = "#c0392b" if obj.status == 'published' else "#d35400"
        return format_html(
            '<div style="border-left: 4px solid {}; padding: 8px 12px; background: #fff8f8; color: {}; border-radius: 4px;">'
            '<strong>Attention : Cette unité contient des dépendances non publiées / en révision :</strong>'
            '<ul style="margin: 6px 0 6px 20px;">{}</ul>'
            '<small style="color: #7f8c8d;">Règle A07 : Les dépendances non publiées restent masquées pour les utilisateurs publics tant qu’elles ne sont pas explicitement validées.</small>'
            '</div>',
            color,
            color,
            format_html(items),
        )

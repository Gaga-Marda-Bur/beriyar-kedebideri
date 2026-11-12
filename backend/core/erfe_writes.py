"""Normalize only NEW/EDITED Erfe-bearing text; never rewrite unchanged history.

save()/ModelForm/REST model writes are covered. Bulk/raw SQL imports must call
normalize_erfe explicitly (or use save); signals do not run for bulk operations.
"""
from django.core.exceptions import ValidationError
from django.db import models
from django.db.models.signals import pre_save
from .transliteration import normalize_erfe

CONTENT_APPS = {'alphabet', 'vocabulary', 'learning', 'lessons', 'quizzes', 'no_ena'}


def normalize_changed_erfe(sender, instance, raw=False, using='default', update_fields=None, **kwargs):
    if raw or sender._meta.app_label not in CONTENT_APPS:
        return
    candidates = {}
    for field in sender._meta.concrete_fields:
        if not isinstance(field, (models.CharField, models.TextField)):
            continue
        if update_fields is not None and field.name not in update_fields:
            continue
        value = getattr(instance, field.attname)
        if not isinstance(value, str) or not any(0x16EA0 <= ord(c) <= 0x16ED3 for c in value):
            continue
        canonical = normalize_erfe(value)
        if canonical != value:
            candidates[field.name] = canonical
    if not candidates:
        return
    previous = None
    if not instance._state.adding:
        previous = sender._base_manager.using(using).filter(pk=instance.pk).values(*candidates).first()
    for name, canonical in candidates.items():
        if previous and previous[name] == getattr(instance, name):
            continue
        field = sender._meta.get_field(name)
        if field.unique and sender._base_manager.using(using).filter(**{name: canonical}).exclude(pk=instance.pk).exists():
            raise ValidationError({name: 'Ce caractère Erfe canonique existe déjà.'})
        setattr(instance, name, canonical)
        if sender._meta.label_lower == 'alphabet.character' and name == 'symbol':
            # Do not persist a stale lower-case codepoint next to a new upper-case symbol.
            if len(canonical) == 1:
                instance.unicode_code = f'U+{ord(canonical):X}'
                if update_fields is not None and 'unicode_code' not in update_fields:
                    raise ValidationError({'unicode_code': 'Inclure unicode_code lors de la modification du symbole.'})


def register():
    pre_save.connect(normalize_changed_erfe, dispatch_uid='core.canonical_erfe_new_writes', weak=False)

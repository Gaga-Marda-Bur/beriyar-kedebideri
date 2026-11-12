from django import forms
from .transliteration import normalize_erfe


class CanonicalErfeModelForm(forms.ModelForm):
    """Normalize edited fields before model/uniqueness validation, not after it."""
    def clean(self):
        data = super().clean()
        for name in self.changed_data:
            value = data.get(name)
            if isinstance(value, str) and any(0x16EA0 <= ord(c) <= 0x16ED3 for c in value):
                data[name] = normalize_erfe(value)
        if self._meta.model._meta.label_lower == 'alphabet.character' and 'symbol' in self.changed_data:
            symbol = data.get('symbol', '')
            if len(symbol) == 1:
                data['unicode_code'] = f'U+{ord(symbol):X}'
        return data

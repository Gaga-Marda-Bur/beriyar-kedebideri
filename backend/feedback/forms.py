from django import forms

from . import validation


class FeedbackForm(forms.Form):
    feedback_type = forms.CharField(required=False, max_length=40)
    title = forms.CharField(required=False, strip=False)
    message = forms.CharField(required=False, strip=False, widget=forms.Textarea)
    language_code = forms.CharField(required=False, max_length=10)

    def __init__(self, *args, lang='fr', **kwargs):
        self.lang = lang
        super().__init__(*args, **kwargs)

    def clean_feedback_type(self):
        return validation.clean_feedback_type(self.cleaned_data['feedback_type'], self.lang)

    def clean_title(self):
        return validation.clean_text(self.cleaned_data['title'], validation.MAX_TITLE_LENGTH, self.lang)

    def clean_message(self):
        return validation.clean_text(self.cleaned_data['message'], validation.MAX_MESSAGE_LENGTH, self.lang)

    def clean_language_code(self):
        return validation.clean_language_code(self.cleaned_data['language_code'], self.lang)

    def clean(self):
        data = super().clean()
        if not self.errors:
            try:
                validation.require_title_or_message(data.get('title'), data.get('message'), self.lang)
            except forms.ValidationError as error:
                self.add_error('message', error)
        return data

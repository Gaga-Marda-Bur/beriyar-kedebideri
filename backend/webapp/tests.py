from django.test import TestCase, Client
from django.urls import reverse

class WebappViewsTestCase(TestCase):
    def setUp(self):
        self.client = Client()

    def test_editor_page_loads(self):
        response = self.client.get(reverse("web-editor"))
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, "webapp/editor.html")
        self.assertContains(response, "editorCanvas")
        self.assertContains(response, "editorTitle")
        self.assertContains(response, "editorBody")
        self.assertContains(response, "pdf-lib.min")
        self.assertContains(response, "fontkit.umd.min")
        self.assertContains(response, "beriya_editor")

    def test_editor_page_multilingual(self):
        # Arabic
        resp_ar = self.client.get(reverse("web-editor") + "?lang=ar")
        self.assertEqual(resp_ar.status_code, 200)
        self.assertContains(resp_ar, 'dir="rtl"')

        # English
        resp_en = self.client.get(reverse("web-editor") + "?lang=en")
        self.assertEqual(resp_en.status_code, 200)
        self.assertContains(resp_en, "Beriya Erfe Text Editor")

        # French
        resp_fr = self.client.get(reverse("web-editor") + "?lang=fr")
        self.assertEqual(resp_fr.status_code, 200)
        self.assertContains(resp_fr, "Éditeur Beriya Erfe")

    def test_sticker_studio_page(self):
        response = self.client.get(reverse("web-sticker-studio"))
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, "webapp/sticker_studio.html")

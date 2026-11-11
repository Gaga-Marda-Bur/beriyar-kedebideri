from django.test import TestCase, Client
from django.urls import reverse

class HistoricalToolsWebTests(TestCase):
    def setUp(self):
        self.client = Client()

    def test_historical_tools_routes_return_200(self):
        # 1. No Ena list
        res_no_ena = self.client.get('/no-ena/')
        self.assertEqual(res_no_ena.status_code, 200)

        # 2. Studio Sticker
        res_sticker = self.client.get('/sticker-studio/')
        self.assertEqual(res_sticker.status_code, 200)
        self.assertTemplateUsed(res_sticker, 'webapp/sticker_studio.html')

        # 3. Éditeur Beriya
        res_editor = self.client.get('/editeur/')
        self.assertEqual(res_editor.status_code, 200)
        self.assertTemplateUsed(res_editor, 'webapp/editor.html')

    def test_home_page_contains_outils_et_creation_section(self):
        response = self.client.get(reverse('web-home'))
        self.assertEqual(response.status_code, 200)

        # Section Outils & Création présente
        self.assertContains(response, 'id="outils-creation"')
        self.assertContains(response, 'Outils & Création')

        # Liens vers les 3 outils
        self.assertContains(response, '/no-ena/')
        self.assertContains(response, '/sticker-studio/')
        self.assertContains(response, '/editeur/')

        # Textes des cartes
        self.assertContains(response, 'No Ena')
        self.assertContains(response, 'Studio Sticker')
        self.assertContains(response, 'Éditeur Beriya')

    def test_home_page_outils_creation_multilingual(self):
        # Test version anglaise
        resp_en = self.client.get(reverse('web-home') + '?lang=en')
        self.assertEqual(resp_en.status_code, 200)
        self.assertContains(resp_en, 'Tools & Creation')
        self.assertContains(resp_en, 'Sticker Studio')
        self.assertContains(resp_en, 'Beriya Editor')

        # Test version arabe
        resp_ar = self.client.get(reverse('web-home') + '?lang=ar')
        self.assertEqual(resp_ar.status_code, 200)
        self.assertContains(resp_ar, 'أدوات وإبداع')
        self.assertContains(resp_ar, 'استوديو الملصقات')
        self.assertContains(resp_ar, 'محرر بيريا')

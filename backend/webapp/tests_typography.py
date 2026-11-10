from pathlib import Path
from types import SimpleNamespace

from django.conf import settings
from django.contrib.admin.sites import AdminSite
from django.test import SimpleTestCase
from django.utils.safestring import mark_safe

from learning.admin import LearningUnitAdmin
from learning.models import LearningUnit
from webapp.templatetags import web_i18n


class ErfeTypographyTests(SimpleTestCase):
    def test_mixed_text_preserves_codepoints_and_escapes_html(self):
        text = 'Beřiya <script>x</script> العربية 𖺵̄ 𖺢'
        html = str(web_i18n.render_erfe(text))
        self.assertIn('Beřiya &lt;script&gt;x&lt;/script&gt; العربية ', html)
        self.assertIn('dir="ltr">𖺵̄</span>', html)
        self.assertIn('dir="ltr">𖺢</span>', html)
        self.assertNotIn('<script>', str(web_i18n.render_erfe(mark_safe(text))))

    def test_admin_template_loads_shared_fonts(self):
        from django.template.loader import render_to_string
        from django.test import RequestFactory
        request = RequestFactory().get('/admin/')
        request.user = SimpleNamespace(is_active=False, is_staff=False)
        html = render_to_string('admin/base_site.html', {
            'site_header': 'BK', 'site_title': 'BK', 'has_permission': False,
            'is_popup': False, 'is_nav_sidebar_enabled': False,
        }, request=request)
        self.assertIn('webapp/css/erfe.css', html)

    def test_all_assigned_characters_and_combining_marks(self):
        points = [*range(0x16EA0, 0x16EB9), *range(0x16EBB, 0x16ED4)]
        for cp in points:
            with self.subTest(cp=cp):
                self.assertIn(f'>{chr(cp)}̄</span>', str(web_i18n.render_erfe(chr(cp) + '\u0304')))
        self.assertEqual(str(web_i18n.render_erfe('Beřiya العربية')), 'Beřiya العربية')

    def test_six_font_weights_and_scoped_fallback(self):
        css = (Path(settings.BASE_DIR) / 'static/webapp/css/erfe.css').read_text()
        for weight in (400, 500, 600, 700, 800, 900):
            self.assertIn(f'font-weight: {weight}', css)
        self.assertIn('unicode-range:', css)
        self.assertIn('direction: ltr', css)

    def test_admin_preview_renders_and_escapes_dynamic_values(self):
        obj = SimpleNamespace(pk=1, generate_core_flow=lambda: [
            {'step_type': '<img src=x onerror=alert(1)>', 'symbol': '<script>x</script>𖺵'}])
        preview = str(LearningUnitAdmin(LearningUnit, AdminSite()).core_flow_preview(obj))
        self.assertIn('𖺵', preview)
        self.assertIn('&lt;script&gt;', preview)
        self.assertNotIn('<script>', preview)
        self.assertNotIn('<img', preview)

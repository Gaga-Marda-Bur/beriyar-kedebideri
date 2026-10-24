from django.test import RequestFactory, TestCase
from django.contrib.sessions.middleware import SessionMiddleware
from rest_framework.test import APIRequestFactory
from django.core.cache import cache

from .models import NoEnaPublication
from .services import record_publication_view
from .views import NoEnaPublicationViewAPIView


class NoEnaViewCountTests(TestCase):
    def setUp(self):
        cache.clear()
        self.rf = RequestFactory()
        self.api_rf = APIRequestFactory()
        self.pub_published = NoEnaPublication.objects.create(
            title_fr="Publication Test",
            slug="publication-test",
            caption_fr="Contenu test",
            status=NoEnaPublication.PUBLISHED,
            is_active=True,
            view_count=10,
        )
        self.pub_draft = NoEnaPublication.objects.create(
            title_fr="Publication Draft",
            slug="publication-draft",
            caption_fr="Contenu brouillon",
            status=NoEnaPublication.DRAFT,
            is_active=True,
            view_count=0,
        )

    def _add_session(self, request):
        middleware = SessionMiddleware(lambda req: None)
        middleware.process_request(request)
        request.session.save()
        return request

    def test_atomic_increment_first_view(self):
        """Une première vue doit incrémenter de façon atomique le view_count."""
        request = self._add_session(self.rf.get("/culture/publication-test/"))
        count, counted = record_publication_view(self.pub_published, request=request)
        self.assertTrue(counted)
        self.assertEqual(count, 11)

        self.pub_published.refresh_from_db()
        self.assertEqual(self.pub_published.view_count, 11)

    def test_session_anti_bounce_web(self):
        """Deux consultations dans la même session web ne doivent pas surcomptabiliser (anti-rebond F5)."""
        request = self._add_session(self.rf.get("/culture/publication-test/"))

        # 1ère vue : comptabilisée
        count1, counted1 = record_publication_view(self.pub_published, request=request)
        self.assertTrue(counted1)
        self.assertEqual(count1, 11)

        # 2ème vue dans la même session : non recomptabilisée
        count2, counted2 = record_publication_view(self.pub_published, request=request)
        self.assertFalse(counted2)
        self.assertEqual(count2, 11)

        self.pub_published.refresh_from_db()
        self.assertEqual(self.pub_published.view_count, 11)

    def test_api_view_count_endpoint(self):
        """L'API POST /api/no-ena/<slug>/view/ incrémente et signale si compté."""
        view = NoEnaPublicationViewAPIView.as_view()

        # 1er appel avec device-1
        req1 = self.api_rf.post("/api/no-ena/publication-test/view/", {"device_id": "device-uuid-1"}, format="json")
        res1 = view(req1, slug="publication-test")
        self.assertEqual(res1.status_code, 200)
        self.assertEqual(res1.data["view_count"], 11)
        self.assertTrue(res1.data["counted"])

        # 2ème appel immédiat avec le même device-1 : non recompté
        req2 = self.api_rf.post("/api/no-ena/publication-test/view/", {"device_id": "device-uuid-1"}, format="json")
        res2 = view(req2, slug="publication-test")
        self.assertEqual(res2.status_code, 200)
        self.assertEqual(res2.data["view_count"], 11)
        self.assertFalse(res2.data["counted"])

        # 3ème appel avec un device-2 distinct : compté
        req3 = self.api_rf.post("/api/no-ena/publication-test/view/", {"device_id": "device-uuid-2"}, format="json")
        res3 = view(req3, slug="publication-test")
        self.assertEqual(res3.status_code, 200)
        self.assertEqual(res3.data["view_count"], 12)
        self.assertTrue(res3.data["counted"])

    def test_draft_publication_not_viewable(self):
        """Une publication non publiée renvoie 404 sur l'API de vue publique."""
        view = NoEnaPublicationViewAPIView.as_view()
        req = self.api_rf.post("/api/no-ena/publication-draft/view/", {}, format="json")
        res = view(req, slug="publication-draft")
        self.assertEqual(res.status_code, 404)

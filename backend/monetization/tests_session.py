import json
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import Client, TestCase
from .services import state_for


class SessionBridgeTests(TestCase):
    base='/api/monetization/v1/'

    def setUp(self):
        cache.clear()
        self.a=get_user_model().objects.create_user('qa-a',password='synthetic-session-password')
        self.b=get_user_model().objects.create_user('qa-b',password='synthetic-session-password')
        self.client=Client(enforce_csrf_checks=True)

    def post(self, action, body=None):
        token=self.client.get(self.base+'session/csrf/').json()['csrf_token']
        return self.client.post(self.base+'session/'+action+'/',json.dumps(body or {}),
            content_type='application/json',HTTP_X_CSRFTOKEN=token)

    def test_login_csrf_rotation_identity_and_logout(self):
        self.assertEqual(self.client.post(self.base+'session/login/',{},content_type='application/json').status_code,403)
        response=self.post('login',{'username':'qa-a','password':'synthetic-session-password','user_id':self.b.pk})
        self.assertEqual(response.status_code,200)
        self.assertEqual(response.json()['subject'],str(state_for(self.a).subject))
        cookie=self.client.cookies['sessionid'].value
        self.assertNotIn(cookie,response.content.decode())
        self.assertEqual(self.client.get(self.base+'me/entitlements/').status_code,200)
        self.assertTrue(self.post('logout').json()['signed_out'])
        self.assertEqual(self.client.get(self.base+'session/').status_code,401)

    def test_change_account_and_disable_delete(self):
        for user in (self.a,self.b):
            self.assertEqual(self.post('login',{'username':user.username,'password':'synthetic-session-password'}).status_code,200)
            self.assertEqual(self.client.get(self.base+'session/').json()['subject'],str(state_for(user).subject))
        self.b.is_active=False
        self.b.save()
        self.assertEqual(self.client.get(self.base+'session/').status_code,401)
        self.assertEqual(self.post('login',{'username':'qa-b','password':'synthetic-session-password'}).status_code,400)
        self.a.delete()
        self.assertEqual(self.post('login',{'username':'qa-a','password':'synthetic-session-password'}).status_code,400)

    def test_expired_session_guest_and_csrf_errors(self):
        self.post('login',{'username':'qa-a','password':'synthetic-session-password'})
        session=self.client.session
        session.set_expiry(-1)
        session.save()
        self.assertEqual(self.client.get(self.base+'session/').status_code,401)
        guest=Client()
        self.assertEqual(guest.get(self.base+'session/',HTTP_X_DEVICE_TOKEN='fake').status_code,401)
        self.assertEqual(self.client.post(self.base+'session/logout/',{}).status_code,403)

    def test_no_session_secret_in_public_data_and_login_throttled(self):
        for _ in range(15):
            self.assertEqual(self.post('login',{'username':'missing','password':'synthetic'}).status_code,400)
        self.assertEqual(self.post('login',{'username':'missing','password':'synthetic'}).status_code,429)
        self.assertEqual(self.client.get(self.base+'session/csrf/')['Cache-Control'],'private, no-store')

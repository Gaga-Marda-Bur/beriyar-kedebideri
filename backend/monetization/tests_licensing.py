import base64
import json
import tempfile
from datetime import timedelta
from pathlib import Path

from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import ec, ed25519
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.core.exceptions import PermissionDenied, ValidationError
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from . import licensing, services
from .models import DeviceKey, CommercialPolicy, EntitlementGrant
from .tests import FoundationTests


class LicenseTests(TestCase):
    def setUp(self):
        FoundationTests.setUp(self)
        req = FoundationTests.request(self)
        FoundationTests.verify(self, req)
        services.transition(actor=self.approver, request_id=req.pk, action='activate', reason='Simulation')
        self.key = ec.generate_private_key(ec.SECP256R1())
        self.public = base64.b64encode(self.key.public_key().public_bytes(
            serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)).decode()
        self.temp = tempfile.TemporaryDirectory(prefix='bk-commerce-test-')
        self.addCleanup(self.temp.cleanup)
        pem = Path(self.temp.name)/'synthetic.pem'
        self.signer = ed25519.Ed25519PrivateKey.generate()
        pem.write_bytes(self.signer.private_bytes(serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
        self.settings_override = override_settings(MONETIZATION_SIGNING_KEY_FILE=str(pem),
            MONETIZATION_SIGNING_KID='sim-unit-test')
        self.settings_override.enable()
        self.addCleanup(self.settings_override.disable)
        row = licensing.challenge(self.a, 'enroll')
        self.device = licensing.enroll(self.a, row.pk, self.public, self.proof(row))

    def proof(self, row):
        return base64.b64encode(self.key.sign(licensing.proof_message(row), ec.ECDSA(hashes.SHA256()))).decode()

    def issue(self, user=None, device=None):
        owner = user or self.a
        row = licensing.challenge(owner,'lease')
        envelope = licensing.issue_lease(owner,row.pk, device or self.device.pk,self.proof(row))
        payload = envelope['payload_b64url']
        self.signer.public_key().verify(base64.urlsafe_b64decode(envelope['signature_b64url']+'=='),
            f"BK-OFFLINE-GRANT/v1\n{envelope['kid']}\n{payload}".encode())
        return json.loads(base64.urlsafe_b64decode(payload+'=='))

    def test_signature_owner_device_policy_and_seven_day_bound(self):
        claims = self.issue()
        self.assertEqual(claims['subject'], str(services.state_for(self.a).subject))
        self.assertEqual(claims['device_id'], str(self.device.pk))
        self.assertEqual(claims['expires_at']-claims['issued_at'],7*86400)
        self.assertEqual(claims['features'],['simulation.badge'])
        self.assertEqual(claims['policy_version'],1)

    def test_subscription_expiry_caps_lease(self):
        end = timezone.now()+timedelta(minutes=5)
        EntitlementGrant.objects.update(ends_at=end)
        self.assertEqual(self.issue()['expires_at'], int(end.timestamp()))

    def test_policy_can_shorten_but_cannot_extend_offline_window(self):
        with self.assertRaises(ValidationError):
            CommercialPolicy(offline_days=8).save()
        CommercialPolicy.objects.create(offline_days=1)
        claims = self.issue()
        self.assertEqual(claims['expires_at']-claims['issued_at'],86400)

    def test_account_isolation_and_device_replay(self):
        with self.assertRaises(PermissionDenied):
            self.issue(user=self.b)
        row = licensing.challenge(self.a,'enroll')
        licensing.enroll(self.a,row.pk,self.public,self.proof(row))
        with self.assertRaises(PermissionDenied):
            licensing.enroll(self.a,row.pk,self.public,self.proof(row))

    def test_invalid_signature_does_not_consume_challenge(self):
        row = licensing.challenge(self.a,'lease')
        with self.assertRaises(PermissionDenied):
            licensing.issue_lease(self.a,row.pk,self.device.pk,'AAAA')
        row.refresh_from_db()
        self.assertFalse(row.used)

    def test_revocation_after_reconnection_and_inactive_account(self):
        old = self.issue()
        grant = EntitlementGrant.objects.get()
        self.approver.user_permissions.add(Permission.objects.get(codename='revoke_entitlement'))
        actor = get_user_model().objects.get(pk=self.approver.pk)
        services.transition(actor=actor,request_id=grant.request_id,action='revoke',reason='Simulation')
        new = self.issue()
        self.assertEqual(new['features'],[])
        self.assertGreater(new['entitlement_epoch'],old['entitlement_epoch'])
        self.a.is_active = False
        self.a.save()
        client = APIClient()
        client.force_authenticate(self.a)
        # Real Session/Basic authentication rejects inactive users; forced auth bypasses authentication.
        client.force_authenticate(None)
        self.assertIn(client.get('/api/monetization/v1/me/entitlements/').status_code,[401,403])

    def test_deleted_account_cannot_reuse_installation_credential(self):
        self.a.delete()
        self.assertFalse(DeviceKey.objects.filter(pk=self.device.pk).exists())
        self.assertIsNone(EntitlementGrant.objects.get().user_id)
        client = APIClient()
        response = client.get('/api/monetization/v1/me/entitlements/',
            HTTP_X_DEVICE_ID=str(self.device.pk),HTTP_X_DEVICE_TOKEN='old-guest-token')
        self.assertIn(response.status_code,[401,403])

    @override_settings(DJANGO_ENV='production')
    def test_no_simulation_issuance_in_production(self):
        with self.assertRaises(PermissionDenied):
            licensing.challenge(self.a,'lease')
        with self.assertRaises(PermissionDenied):
            licensing.signing_key()

    def test_session_csrf_and_ledger_ownership(self):
        client = APIClient(enforce_csrf_checks=True)
        client.force_login(self.a)
        self.assertEqual(client.post('/api/monetization/v1/me/device-keys/challenge/', {'purpose':'enroll'}).status_code,403)
        foreign = FoundationTests.request(self,user=self.b,key='foreign')
        self.assertEqual(client.get(f'/api/monetization/v1/me/requests/{foreign.pk}/').status_code,404)
        self.assertNotIn('payment', str(client.get('/api/monetization/v1/public-config/').data))

    def test_signer_missing_returns503_preserves_grants(self):
        client = APIClient()
        client.force_authenticate(self.a)
        row = licensing.challenge(self.a,'lease')
        with override_settings(MONETIZATION_SIGNING_KEY_FILE=''):
            response = client.post('/api/monetization/v1/me/offline-lease/',
                {'challenge_id':str(row.pk),'device_id':str(self.device.pk),'signature':self.proof(row)})
        self.assertEqual(response.status_code,503)
        self.assertEqual(services.entitlements(self.a)['features'],['simulation.badge'])

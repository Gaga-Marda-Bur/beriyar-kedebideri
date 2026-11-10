"""Ownership regression tests: synthetic users and in-memory progress only."""
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient

from learning.models import LearningTheme, LearningUnit
from .models import UnitProgress

LIST = '/api/progress/unit-progress/'
SYNC = LIST + 'sync/'


class ProgressOwnershipTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        User = get_user_model()
        cls.a = User.objects.create_user(username='owner-a')
        cls.b = User.objects.create_user(username='owner-b')
        cls.staff = User.objects.create_user(username='limited-staff', is_staff=True)
        cls.admin = User.objects.create_superuser(username='authorized-admin')
        theme = LearningTheme.objects.create(slug='ownership', title_fr='Test', status='published')
        cls.unit = LearningUnit.objects.create(theme=theme, slug='ownership-one', title_fr='Test', status='published')
        cls.other = LearningUnit.objects.create(theme=theme, slug='ownership-two', title_fr='Test', status='published')
        cls.private = UnitProgress.objects.create(user=cls.b, device_id='private-b',
            device_token='private-b-token', unit=cls.unit, lessons_seen=5)
        cls.guest = UnitProgress.objects.create(device_id='guest-b', device_token='guest-b-token',
            unit=cls.unit, lessons_seen=6)
        cls.legacy = UnitProgress.objects.create(device_id='legacy-b', unit=cls.unit, lessons_seen=7)

    def setUp(self):
        self.api = APIClient(raise_request_exception=False)

    def sync(self, device, token, unit=None, **fields):
        return self.api.post(SYNC, {'items': [{'unit_slug': (unit or self.unit).slug,
            'device_id': device, 'device_token': token, **fields}]}, format='json')

    def denied_sync(self, response):
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['synced_count'], 0)
        self.assertEqual(response.data['error_count'], 1)

    def test_account_a_only_reads_own_records_even_with_forged_identifiers(self):
        own = UnitProgress.objects.create(user=self.a, device_id='private-a', unit=self.unit)
        self.api.force_authenticate(self.a)
        response = self.api.get(LIST, {'user': self.b.id, 'device_id': 'private-b'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual([r['id'] for r in response.data['results']], [own.id])
        self.assertNotIn('device_token', response.data['results'][0])

    def test_anonymous_cannot_read_account_progress_even_with_old_device_token(self):
        response = self.api.get(LIST, {'device_id': 'private-b'}, HTTP_X_DEVICE_TOKEN='private-b-token')
        self.assertEqual(response.status_code, 403)

    def test_anonymous_cannot_modify_account_progress_even_with_old_device_token(self):
        self.denied_sync(self.sync('private-b', 'private-b-token', lessons_seen=99))
        self.private.refresh_from_db()
        self.assertEqual(self.private.lessons_seen, 5)

    def test_a_cannot_overwrite_b_even_with_b_device_token(self):
        self.api.force_authenticate(self.a)
        self.denied_sync(self.sync('private-b', 'private-b-token', lessons_seen=99))
        self.private.refresh_from_db()
        self.assertEqual(self.private.user_id, self.b.id)
        self.assertEqual(self.private.lessons_seen, 5)

    def test_legacy_record_cannot_be_read_with_an_arbitrary_token(self):
        response = self.api.get(LIST, {'device_id': 'legacy-b'}, HTTP_X_DEVICE_TOKEN='invented')
        self.assertEqual(response.status_code, 403)

    def test_legacy_record_cannot_be_claimed_by_guest_or_unrelated_account(self):
        for user in (None, self.a):
            with self.subTest(user=user):
                self.api.force_authenticate(user)
                self.denied_sync(self.sync('legacy-b', 'invented', lessons_seen=99))
        self.legacy.refresh_from_db()
        self.assertEqual(self.legacy.device_token, '')
        self.assertIsNone(self.legacy.user_id)
        self.assertEqual(self.legacy.lessons_seen, 7)

    def test_new_unit_does_not_register_a_different_token_for_existing_device(self):
        self.denied_sync(self.sync('guest-b', 'attacker-token', unit=self.other))
        self.assertFalse(UnitProgress.objects.filter(device_id='guest-b', unit=self.other).exists())

    def test_preexisting_mixed_tokens_never_expose_other_token_or_tokenless_rows(self):
        UnitProgress.objects.create(device_id='guest-b', device_token='other-secret', unit=self.other)
        response = self.api.get(LIST, {'device_id': 'guest-b'}, HTTP_X_DEVICE_TOKEN='other-secret')
        self.assertIn(response.status_code, (200, 403))
        if response.status_code == 200:
            self.assertNotIn(self.guest.id, [r['id'] for r in response.data['results']])

    def test_new_guest_requires_a_nonempty_token(self):
        self.denied_sync(self.sync('new-guest', ''))
        self.assertFalse(UnitProgress.objects.filter(device_id='new-guest').exists())

    def test_wrong_or_missing_guest_token_cannot_read_or_write(self):
        for token in ('', 'wrong'):
            with self.subTest(token=token):
                self.assertEqual(self.api.get(LIST, {'device_id': 'guest-b'}, HTTP_X_DEVICE_TOKEN=token).status_code, 403)
                self.denied_sync(self.sync('guest-b', token, lessons_seen=99))

    def test_normal_guest_can_create_read_and_update_two_units_with_same_token(self):
        for unit in (self.unit, self.other):
            response = self.sync('new-guest', 'new-guest-secret', unit=unit, lessons_seen=2, user=self.b.id)
            self.assertEqual(response.data['synced_count'], 1)
        response = self.sync('new-guest', 'new-guest-secret', lessons_seen=3)
        self.assertEqual(response.data['synced_count'], 1)
        response = self.api.get(LIST, {'device_id': 'new-guest'}, HTTP_X_DEVICE_TOKEN='new-guest-secret')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['count'], 2)
        self.assertTrue(all(r['user'] is None for r in response.data['results']))

    def test_auth_creation_ignores_forged_user_and_supports_no_device(self):
        self.api.force_authenticate(self.a)
        response = self.api.post(SYNC, {'items': [{'unit_slug': self.other.slug, 'user': self.b.id}]}, format='json')
        self.assertEqual(response.data['synced_count'], 1)
        record = UnitProgress.objects.get(unit=self.other)
        self.assertEqual(record.user_id, self.a.id)
        self.assertNotEqual(record.device_id, '')

    def test_account_owner_can_update_without_device_token(self):
        self.api.force_authenticate(self.b)
        response = self.api.post(SYNC, {'items': [{'unit_slug': self.unit.slug, 'lessons_seen': 8}]}, format='json')
        self.assertEqual(response.data['synced_count'], 1)
        self.private.refresh_from_db()
        self.assertEqual(self.private.lessons_seen, 8)

    def test_guest_to_account_link_requires_proof_and_revokes_guest_access(self):
        self.api.force_authenticate(self.a)
        self.denied_sync(self.sync('guest-b', 'wrong'))
        response = self.sync('guest-b', 'guest-b-token')
        self.assertEqual(response.data['synced_count'], 1)
        self.guest.refresh_from_db()
        self.assertEqual(self.guest.user_id, self.a.id)
        self.api.force_authenticate(None)
        self.assertEqual(self.api.get(LIST, {'device_id': 'guest-b'}, HTTP_X_DEVICE_TOKEN='guest-b-token').status_code, 403)
        self.denied_sync(self.sync('guest-b', 'guest-b-token', unit=self.other))

    def test_malformed_credentials_are_item_errors_not_500_or_leaked_secrets(self):
        for token in (42, [], {}, True, 'x' * 129):
            with self.subTest(token=type(token).__name__):
                response = self.sync('guest-b', token)
                self.denied_sync(response)
                self.assertNotIn('guest-b-token', str(response.data))

    def test_header_payload_identity_mismatch_is_rejected(self):
        response = self.api.post(SYNC, {'items': [{'unit_slug': self.unit.slug,
            'device_id': 'guest-b', 'device_token': 'guest-b-token'}]}, format='json',
            HTTP_X_DEVICE_ID='different-device', HTTP_X_DEVICE_TOKEN='guest-b-token')
        self.denied_sync(response)

    def test_staff_needs_explicit_model_permission_for_global_listing(self):
        self.api.force_authenticate(self.staff)
        response = self.api.get(LIST)
        self.assertEqual(response.data['count'], 0)
        self.staff.user_permissions.add(Permission.objects.get(codename='view_unitprogress'))
        self.api.force_authenticate(get_user_model().objects.get(pk=self.staff.pk))
        self.assertEqual(self.api.get(LIST).data['count'], 3)

    def test_unsupported_api_crud_and_id_routes_do_not_delete_or_mutate(self):
        count = UnitProgress.objects.count()
        self.api.force_authenticate(self.a)
        for method in ('post', 'put', 'patch', 'delete'):
            self.assertEqual(getattr(self.api, method)(LIST, {'id': self.private.id}, format='json').status_code, 405)
        for method in ('get', 'put', 'patch', 'delete'):
            self.assertEqual(getattr(self.api, method)(LIST + str(self.private.id) + '/').status_code, 404)
        self.assertEqual(self.api.get(SYNC).status_code, 405)
        self.assertEqual(UnitProgress.objects.count(), count)

    def test_authorized_admin_listing_and_deletion_continue_to_work(self):
        self.client.force_login(self.admin)
        response = self.client.get(reverse('admin:progress_unitprogress_changelist'))
        self.assertEqual(response.status_code, 200)
        response = self.client.post(reverse('admin:progress_unitprogress_delete', args=[self.private.pk]), {'post': 'yes'})
        self.assertEqual(response.status_code, 302)
        self.assertFalse(UnitProgress.objects.filter(pk=self.private.pk).exists())

    def test_limited_staff_cannot_delete_via_admin(self):
        self.client.force_login(self.staff)
        response = self.client.post(reverse('admin:progress_unitprogress_delete', args=[self.private.pk]), {'post': 'yes'})
        self.assertEqual(response.status_code, 403)
        self.assertTrue(UnitProgress.objects.filter(pk=self.private.pk).exists())

    def test_header_only_flutter_identity_and_partial_batch_keep_successes(self):
        response = self.api.post(SYNC, {'items': [
            {'unit_slug': self.unit.slug, 'lessons_seen': 2},
            {'unit_slug': self.other.slug, 'device_id': 'forged-device'}]}, format='json',
            HTTP_X_DEVICE_ID='header-device', HTTP_X_DEVICE_TOKEN='header-secret')
        self.assertEqual(response.data['synced_count'], 1)
        self.assertEqual(response.data['error_count'], 1)
        self.assertEqual(UnitProgress.objects.get(device_id='header-device').lessons_seen, 2)
        self.assertFalse(UnitProgress.objects.filter(device_id='forged-device').exists())

    def test_credential_survives_progress_deletion_and_blocks_new_token(self):
        from .models import ProgressDeviceCredential
        self.assertEqual(self.sync('registered', 'first-secret').data['synced_count'], 1)
        credential = ProgressDeviceCredential.objects.get(pk='registered')
        self.assertNotEqual(credential.token_digest, 'first-secret')
        self.assertEqual(len(credential.token_digest), 64)
        UnitProgress.objects.filter(device_id='registered').delete()
        self.denied_sync(self.sync('registered', 'different-secret', unit=self.other))
        self.assertEqual(self.sync('registered', 'first-secret', unit=self.other).data['synced_count'], 1)

    def test_linked_installation_stays_closed_after_account_deletion(self):
        self.api.force_authenticate(self.a)
        self.assertEqual(self.sync('guest-b', 'guest-b-token').data['synced_count'], 1)
        self.a.delete()
        self.api.force_authenticate(None)
        self.assertEqual(self.api.get(LIST, {'device_id': 'guest-b'}, HTTP_X_DEVICE_TOKEN='guest-b-token').status_code, 403)
        self.denied_sync(self.sync('guest-b', 'guest-b-token'))

    def test_account_history_without_registry_stays_private_after_account_deletion(self):
        self.b.delete()
        self.private.refresh_from_db()
        self.assertIsNone(self.private.user_id)
        self.assertTrue(self.private.account_bound)
        self.assertEqual(self.api.get(LIST, {'device_id': 'private-b'}, HTTP_X_DEVICE_TOKEN='private-b-token').status_code, 403)
        self.denied_sync(self.sync('private-b', 'private-b-token'))

    def test_session_authentication_requires_csrf_for_sync(self):
        api = APIClient(enforce_csrf_checks=True)
        api.force_login(self.a)
        response = api.post(SYNC, {'items': [{'unit_slug': self.unit.slug}]}, format='json')
        self.assertEqual(response.status_code, 403)

    def test_admin_cannot_impersonate_an_account_through_sync(self):
        self.api.force_authenticate(self.admin)
        self.denied_sync(self.sync('private-b', 'private-b-token', lessons_seen=99))
        self.private.refresh_from_db()
        self.assertEqual(self.private.lessons_seen, 5)

    def test_reserved_account_namespace_is_not_available_to_guests(self):
        self.denied_sync(self.sync(f'account:{self.b.id}', 'invented'))

    def test_public_pedagogical_endpoints_do_not_embed_private_progress(self):
        for route in ('/api/learning/themes/', '/api/learning/units/', '/api/lessons/', '/api/quizzes/'):
            response = self.api.get(route)
            self.assertEqual(response.status_code, 200)
            self.assertNotIn('private-b', str(response.data))
            self.assertNotIn('guest-b-token', str(response.data))

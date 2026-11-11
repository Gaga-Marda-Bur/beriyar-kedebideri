"""Comprehensive verification of Django Admin commercial roles and emergency controls."""
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.core.cache import cache
from django.test import Client, TestCase
from django.urls import reverse

from .models import (
    CommercialPolicy,
    CommercialRequest,
    EntitlementGrant,
    AuditEvent,
    PremiumPlan,
    PaymentMethod,
    PremiumFeature,
)


class AdminSimulationWorkflowTests(TestCase):
    def setUp(self):
        cache.clear()
        User = get_user_model()
        self.superadmin = User.objects.create_superuser('adm-super', password='admin-password')
        self.manager = User.objects.create_user('adm-manager', password='manager-password', is_staff=True)
        self.verifier = User.objects.create_user('adm-verifier', password='verifier-password', is_staff=True)
        self.checker = User.objects.create_user('adm-checker', password='checker-password', is_staff=True)
        self.unprivileged_staff = User.objects.create_user('adm-unprivileged', password='staff-password', is_staff=True)
        self.user = User.objects.create_user('test-customer', password='customer-password')

        # Permissions setup via official codenames
        self.manager.user_permissions.add(*Permission.objects.filter(
            codename__in=['view_commercialrequest', 'configure_commerce', 'review_protected_account']
        ))
        self.verifier.user_permissions.add(*Permission.objects.filter(
            codename__in=['view_commercialrequest', 'verify_payment']
        ))
        self.checker.user_permissions.add(*Permission.objects.filter(
            codename__in=[
                'view_commercialrequest',
                'view_commercialpolicy',
                'change_commercialpolicy',
                'approve_payment',
                'grant_entitlement',
                'revoke_entitlement',
                'disable_ads_emergency',
                'review_protected_account'
            ]
        ))

        # Base commercial models
        self.feature = PremiumFeature.objects.create(code='simulation.badge', label='Sim Badge')
        self.plan = PremiumPlan.objects.create(code='sim_plan', label='Sim Plan', duration_days=30, simulation_available=True)
        self.plan.features.add(self.feature)
        self.method = PaymentMethod.objects.create(code='sim_cash', kind='cash', enabled=True)
        self.policy = CommercialPolicy.objects.create(pk=1, version=1, ads_enabled=False, emergency_stop=False)

    def test_unprivileged_staff_cannot_access_or_trigger_simulation(self):
        client = Client()
        client.force_login(self.unprivileged_staff)
        url = reverse('admin:monetization_simulate')
        response = client.get(url)
        self.assertEqual(response.status_code, 403)
        changelist = reverse('admin:monetization_commercialrequest_changelist')
        response_post = client.post(changelist, {'action': 'verify', '_selected_action': ['00000000-0000-0000-0000-000000000000']})
        # Unprivileged staff lacks view_commercialrequest
        self.assertEqual(response_post.status_code, 403)

    def test_full_two_person_rule_verify_activate_revoke_workflow(self):
        client = Client()
        client.force_login(self.verifier)
        simulate_url = reverse('admin:monetization_simulate')

        # 1. Create simulation request
        post_data = {
            'user': self.user.pk,
            'plan': self.plan.pk,
            'method': self.method.pk,
            'purpose': 'purchase',
            'key': 'sim-admin-seq-1',
            'reason': 'Order created by verifier',
        }
        resp = client.post(simulate_url, post_data)
        self.assertEqual(resp.status_code, 302)
        req = CommercialRequest.objects.get(idempotency_key='sim-admin-seq-1')
        self.assertEqual(req.status, 'pending')

        changelist = reverse('admin:monetization_commercialrequest_changelist')

        # 2. Verifier verifies payment receipt
        resp = client.post(changelist, {'action': 'verify', 'index': 0, '_selected_action': [str(req.pk)]}, follow=True)
        self.assertEqual(resp.status_code, 200)
        req.refresh_from_db()
        self.assertEqual(req.status, 'verified')

        # 3. Verifier CANNOT self-activate (Dual custody enforcement)
        resp = client.post(changelist, {'action': 'activate', 'index': 0, '_selected_action': [str(req.pk)]}, follow=True)
        self.assertEqual(resp.status_code, 200)
        req.refresh_from_db()
        self.assertEqual(req.status, 'verified')
        self.assertEqual(EntitlementGrant.objects.count(), 0)

        # 4. Independent Checker activates grant
        client.force_login(self.checker)
        resp = client.post(changelist, {'action': 'activate', 'index': 0, '_selected_action': [str(req.pk)]}, follow=True)
        self.assertEqual(resp.status_code, 200)
        req.refresh_from_db()
        self.assertEqual(req.status, 'activated')
        self.assertEqual(EntitlementGrant.objects.count(), 1)
        grant = EntitlementGrant.objects.first()
        self.assertIsNone(grant.revoked_at)

        # 5. Checker revokes grant
        resp = client.post(changelist, {'action': 'revoke', 'index': 0, '_selected_action': [str(req.pk)]}, follow=True)
        self.assertEqual(resp.status_code, 200)
        grant.refresh_from_db()
        self.assertIsNotNone(grant.revoked_at)

        # 6. Audit Trail verified
        actions = list(AuditEvent.objects.values_list('action', flat=True))
        self.assertIn('create_request', actions)
        self.assertIn('verify', actions)
        self.assertIn('activate', actions)
        self.assertIn('revoke', actions)

    def test_emergency_stop_action_and_policy_lockdown(self):
        client = Client()
        client.force_login(self.checker)
        policy_changelist = reverse('admin:monetization_commercialpolicy_changelist')

        # Trigger emergency stop admin action
        resp = client.post(policy_changelist, {'action': 'emergency_stop', 'index': 0, '_selected_action': [str(self.policy.pk)]}, follow=True)
        self.assertEqual(resp.status_code, 200)
        self.policy.refresh_from_db()
        self.assertTrue(self.policy.emergency_stop)
        self.assertFalse(self.policy.ads_enabled)
        self.assertEqual(self.policy.version, 2)

        # Verify audit log recorded emergency stop
        self.assertTrue(AuditEvent.objects.filter(action='stop_ads').exists())

    def test_read_only_protection_on_grants_and_audits(self):
        from monetization.admin import ReadOnlyAdmin
        from django.contrib.admin.sites import site
        grant_admin = site._registry[EntitlementGrant]
        audit_admin = site._registry[AuditEvent]
        self.assertIsInstance(grant_admin, ReadOnlyAdmin)
        self.assertIsInstance(audit_admin, ReadOnlyAdmin)
        client = Client()
        client.force_login(self.superadmin)
        self.assertFalse(grant_admin.has_add_permission(None))
        self.assertFalse(grant_admin.has_change_permission(None))
        self.assertFalse(grant_admin.has_delete_permission(None))
        self.assertFalse(audit_admin.has_add_permission(None))
        self.assertFalse(audit_admin.has_change_permission(None))
        self.assertFalse(audit_admin.has_delete_permission(None))

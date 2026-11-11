from datetime import timedelta

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.core.exceptions import PermissionDenied, ValidationError
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from .models import (CommercialPolicy, CommerceAccountState, PremiumFeature,
                     PremiumPlan, PaymentMethod, CommercialRequest,
                     EntitlementGrant, AuditEvent)
from . import services


class FoundationTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.a = User.objects.create_user('a')
        self.b = User.objects.create_user('b')
        self.verifier = User.objects.create_user('verifier', is_staff=True)
        self.approver = User.objects.create_user('approver', is_staff=True)
        self.verifier.user_permissions.add(*Permission.objects.filter(codename__in=['verify_payment','record_refund']))
        self.approver.user_permissions.add(*Permission.objects.filter(
            codename__in=['approve_payment', 'grant_entitlement', 'review_protected_account']))
        self.feature = PremiumFeature.objects.create(code='simulation.badge', label='Simulation')
        self.plan = PremiumPlan.objects.create(code='test', label='Simulation', simulation_available=True)
        self.plan.features.add(self.feature)
        self.method = PaymentMethod.objects.create(code='sim-cash', kind='cash', enabled=True)

    def request(self, user=None, key='one'):
        return services.create_request(actor=self.verifier, user=user or self.a,
            plan=self.plan, method=self.method, key=key, reason='Simulation QA')

    def verify(self, req, ref='SIM-RECEIPT-1'):
        return services.transition(actor=self.verifier, request_id=req.pk,
            action='verify', reason='Simulation rapprochee', receipt=ref)

    def test_staff_alone_cannot_verify_or_activate(self):
        self.verifier.user_permissions.clear()
        self.verifier = get_user_model().objects.get(pk=self.verifier.pk)
        with self.assertRaises(PermissionDenied):
            self.request()

    def test_double_activation_is_idempotent_and_snapshots_features(self):
        req = self.request()
        self.verify(req)
        for _ in range(2):
            services.transition(actor=self.approver, request_id=req.pk,
                action='activate', reason='Simulation approuvee')
        self.assertEqual(EntitlementGrant.objects.count(), 1)
        self.assertEqual(AuditEvent.objects.filter(action='activate').count(), 1)
        self.assertEqual(services.entitlements(self.a)['features'], ['simulation.badge'])

    def test_reference_unique_and_idempotency_conflict(self):
        first = self.request()
        self.assertEqual(self.request().pk, first.pk)
        with self.assertRaises(ValidationError):
            self.request(user=self.b)
        self.verify(first)
        second = self.request(user=self.b, key='two')
        with self.assertRaises(ValidationError):
            self.verify(second)

    def test_no_self_approval_or_skipped_verification(self):
        req = self.request()
        with self.assertRaises(ValidationError):
            services.transition(actor=self.approver, request_id=req.pk,
                action='activate', reason='Simulation')
        self.verify(req)
        self.verifier.user_permissions.add(*Permission.objects.filter(
            codename__in=['approve_payment', 'grant_entitlement', 'review_protected_account']))
        fresh = get_user_model().objects.get(pk=self.verifier.pk)
        with self.assertRaises(PermissionDenied):
            services.transition(actor=fresh, request_id=req.pk, action='activate', reason='Simulation')

    def test_unknown_age_requires_extra_review(self):
        req = self.request()
        self.verify(req)
        self.approver.user_permissions.remove(Permission.objects.get(codename='review_protected_account'))
        fresh = get_user_model().objects.get(pk=self.approver.pk)
        for age in ('unknown','minor'):
            state = services.state_for(self.a)
            state.age_band = age
            state.save()
            with self.assertRaises(PermissionDenied):
                services.transition(actor=fresh, request_id=req.pk, action='activate', reason='Simulation')

    def test_expiry_refund_and_free_invariants(self):
        req = self.request()
        self.verify(req)
        services.transition(actor=self.approver, request_id=req.pk, action='activate', reason='Simulation')
        services.transition(actor=self.verifier, request_id=req.pk, action='refund', reason='Simulation')
        self.assertEqual(services.entitlements(self.a)['features'], [])
        self.assertIn('alphabet', services.entitlements(self.a)['free_features'])
        self.assertFalse(services.public_config()['ads_enabled'])

    def test_public_api_and_owner_boundary(self):
        client = APIClient()
        self.assertEqual(client.get('/api/monetization/v1/public-config/').status_code, 200)
        self.assertIn(client.get('/api/monetization/v1/me/entitlements/').status_code, [401,403])
        client.force_authenticate(self.a)
        response = client.get('/api/monetization/v1/me/entitlements/', {'user_id': self.b.pk})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response['Cache-Control'], 'private, no-store')
        self.assertEqual(response.data['features'], [])

    def test_live_flags_and_real_payment_details_rejected(self):
        with self.assertRaises(ValidationError):
            CommercialPolicy(ads_enabled=True).save()
        with self.assertRaises(ValidationError):
            PaymentMethod(code='bad', instructions='real bank details').save()

    def test_database_constraint_blocks_live_flag_even_when_validation_bypassed(self):
        from django.db import IntegrityError, transaction
        CommercialPolicy.objects.create()
        with self.assertRaises(IntegrityError), transaction.atomic():
            CommercialPolicy.objects.update(premium_sales_enabled=True)

    def test_all_payment_kinds_are_simulation_only(self):
        for kind in ('bank','mobile_money','cash','online'):
            with self.subTest(kind=kind):
                method = PaymentMethod.objects.create(code='sim-kind-'+kind,kind=kind,enabled=True)
                req = services.create_request(actor=self.verifier,user=self.a,plan=self.plan,
                    method=method,key=kind,reason='Simulation')
                self.verify(req,ref='SIM-'+kind)
                services.transition(actor=self.approver,request_id=req.pk,action='activate',reason='Simulation')
                self.assertEqual(req.currency,'XXX')
        self.assertEqual(EntitlementGrant.objects.count(),4)

    def test_donation_never_activates_premium(self):
        req = services.create_request(actor=self.verifier,user=self.a,plan=None,method=self.method,
            key='donation',purpose='donation',reason='Simulation')
        self.verify(req)
        with self.assertRaises(ValidationError):
            services.transition(actor=self.approver,request_id=req.pk,action='activate',reason='Simulation')
        self.assertEqual(EntitlementGrant.objects.count(),0)

    def test_gratuitous_grants_have_no_fake_payment(self):
        from .models import PaymentTransaction
        for purpose in ('complimentary','scholarship'):
            permission = 'grant_'+purpose
            perm = Permission.objects.get(codename=permission)
            self.verifier.user_permissions.add(perm)
            self.approver.user_permissions.add(perm)
            maker = get_user_model().objects.get(pk=self.verifier.pk)
            checker = get_user_model().objects.get(pk=self.approver.pk)
            req = services.create_request(actor=maker,user=self.a,plan=self.plan,method=None,
                key=purpose,purpose=purpose,reason='Simulation')
            services.transition(actor=checker,request_id=req.pk,action='activate',reason='Simulation')
        self.assertEqual(PaymentTransaction.objects.count(),0)
        self.assertEqual(EntitlementGrant.objects.count(),2)

    def test_admin_cannot_edit_grant_or_audit_even_with_standard_change_permission(self):
        from django.conf import settings
        from django.test import Client
        self.approver.user_permissions.add(*Permission.objects.filter(codename__in=[
            'change_entitlementgrant','add_entitlementgrant','change_auditevent','delete_auditevent']))
        client = Client()
        client.force_login(self.approver)
        response = client.post('/'+settings.ADMIN_URL+'monetization/entitlementgrant/add/',{})
        self.assertEqual(response.status_code,403)
        req = self.request()
        self.verify(req)
        services.transition(actor=self.approver,request_id=req.pk,action='activate',reason='Simulation')
        grant = EntitlementGrant.objects.get()
        response = client.post('/'+settings.ADMIN_URL+f'monetization/entitlementgrant/{grant.pk}/change/',{'features':'[]'})
        self.assertEqual(response.status_code,403)
        grant.refresh_from_db()
        self.assertEqual(grant.features,['simulation.badge'])

    def test_minor_and_unknown_are_protected_adult_does_not_claim_legal_proof(self):
        for age in ('minor','unknown'):
            state = services.state_for(self.a)
            state.age_band = age
            state.save()
            self.assertFalse(services.public_config()['tracking_enabled'])
            self.assertFalse(services.public_config()['ads_enabled'])
        self.assertEqual(services.public_config()['parental_consent'],'not_implemented_no_consent_assumed')

    @override_settings(DJANGO_ENV='production')
    def test_no_ledger_writes_in_production(self):
        with self.assertRaises(PermissionDenied):
            self.request()

    def test_reject_cancel_and_disabled_methods(self):
        for action in ('reject','cancel'):
            req = self.request(key=action)
            for _ in range(2):
                services.transition(actor=self.approver,request_id=req.pk,action=action,reason='Simulation')
            req.refresh_from_db()
            self.assertIn(req.status,('rejected','cancelled'))
            with self.assertRaises(ValidationError):
                self.verify(req)
        self.method.enabled = False
        self.method.save()
        with self.assertRaises(ValidationError):
            self.request(key='disabled')

    def test_real_basic_authentication_rejects_inactive_and_ignores_foreign_owner(self):
        import base64
        self.a.set_password('synthetic-test-password-only')
        self.a.save()
        client = APIClient()
        auth = 'Basic '+base64.b64encode(b'a:synthetic-test-password-only').decode()
        response = client.get('/api/monetization/v1/me/entitlements/',{'user_id':self.b.pk},HTTP_AUTHORIZATION=auth)
        self.assertEqual(response.status_code,200)
        self.assertEqual(response.data['subject'],str(services.state_for(self.a).subject))
        self.a.is_active=False
        self.a.save()
        self.assertIn(client.get('/api/monetization/v1/me/entitlements/',HTTP_AUTHORIZATION=auth).status_code,[401,403])

    def test_admin_form_and_actions_execute_the_controlled_workflow(self):
        from django.conf import settings
        from django.test import Client
        from django.urls import reverse
        view = Permission.objects.get(codename='view_commercialrequest')
        self.verifier.user_permissions.add(view)
        self.approver.user_permissions.add(view)
        client = Client()
        client.force_login(self.verifier)
        url = reverse('admin:monetization_simulate')
        self.assertEqual(client.get(url).status_code,200)
        response = client.post(url,{'user':self.a.pk,'plan':self.plan.pk,'method':self.method.pk,
            'purpose':'purchase','key':'admin-one','reason':'Simulation Admin QA'})
        self.assertEqual(response.status_code,302)
        req = CommercialRequest.objects.get(idempotency_key='admin-one')
        listing = reverse('admin:monetization_commercialrequest_changelist')
        client.post(listing,{'action':'verify','index':0,'_selected_action':[str(req.pk)]})
        req.refresh_from_db()
        self.assertEqual(req.status,'verified')
        client.force_login(self.approver)
        client.post(listing,{'action':'activate','index':0,'_selected_action':[str(req.pk)]})
        req.refresh_from_db()
        self.assertEqual(req.status,'activated')
        self.assertEqual(EntitlementGrant.objects.count(),1)

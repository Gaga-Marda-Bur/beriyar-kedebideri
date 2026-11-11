"""Real row-lock tests, deliberately skipped on SQLite."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest import skipUnless

from django.contrib.auth import get_user_model
from django.db import connection, connections, close_old_connections
from django.test import TransactionTestCase

from . import services
from .models import EntitlementGrant, AuditEvent
from .tests import FoundationTests


@skipUnless(connection.vendor == 'postgresql', 'Requires real PostgreSQL row locks')
class ConcurrencyTests(TransactionTestCase):
    def setUp(self):
        FoundationTests.setUp(self)

    def test_simultaneous_approvals_produce_one_grant(self):
        req = FoundationTests.request(self)
        FoundationTests.verify(self, req)
        barrier = Barrier(2)
        actor_id = self.approver.pk
        def activate():
            close_old_connections()
            try:
                actor = get_user_model().objects.get(pk=actor_id)
                barrier.wait(timeout=10)
                return str(services.transition(actor=actor,request_id=req.pk,
                    action='activate',reason='Concurrent simulation').pk)
            finally:
                connections.close_all()
        with ThreadPoolExecutor(max_workers=2) as pool:
            values = list(pool.map(lambda _:activate(),range(2)))
        self.assertEqual(values[0],values[1])
        self.assertEqual(EntitlementGrant.objects.count(),1)
        self.assertEqual(AuditEvent.objects.filter(action='activate').count(),1)

    def test_simultaneous_idempotent_creation_produces_one_request(self):
        from .models import CommercialRequest
        barrier = Barrier(2)
        actor_id, user_id, plan_id, method_id = self.verifier.pk,self.a.pk,self.plan.pk,self.method.pk
        def create():
            from .models import PremiumPlan, PaymentMethod
            close_old_connections()
            try:
                actor=get_user_model().objects.get(pk=actor_id)
                user=get_user_model().objects.get(pk=user_id)
                plan=PremiumPlan.objects.get(pk=plan_id)
                method=PaymentMethod.objects.get(pk=method_id)
                barrier.wait(timeout=10)
                return str(services.create_request(actor=actor,user=user,plan=plan,method=method,
                    key='concurrent-key',reason='Concurrent simulation').pk)
            finally:
                connections.close_all()
        with ThreadPoolExecutor(max_workers=2) as pool:
            values=list(pool.map(lambda _:create(),range(2)))
        self.assertEqual(values[0],values[1])
        self.assertEqual(CommercialRequest.objects.count(),1)

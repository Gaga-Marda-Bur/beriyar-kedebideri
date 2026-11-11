from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from django.shortcuts import get_object_or_404
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.exceptions import PermissionDenied as DjangoPermissionDenied
from rest_framework.exceptions import ValidationError, PermissionDenied
from rest_framework import serializers

from . import services
from .models import PremiumPlan, CommercialRequest


class PublicConfig(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        response = Response(services.public_config())
        response['Cache-Control'] = 'public, max-age=60'
        return response


class PersonalView(APIView):
    permission_classes = [IsAuthenticated]

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response['Cache-Control'] = 'private, no-store'
        response['Vary'] = 'Cookie, Authorization'
        return response


class Catalog(PersonalView):
    def get(self, request):
        # Not a sales catalog; no real currency, external link or payee details.
        return Response({'mode':'simulation', 'purchasable':False, 'offers':[
            {'code':p.code,'revision':p.revision,'label':p.label,
             'features':list(p.features.values_list('code', flat=True)),
             'duration_days':p.duration_days, 'price':None}
            for p in PremiumPlan.objects.filter(simulation_available=True)]})


class Entitlements(PersonalView):
    def get(self, request):
        return Response(services.entitlements(request.user))


class Requests(PersonalView):
    def get(self, request, pk=None):
        records = CommercialRequest.objects.filter(user=request.user)
        def render(r):
            return {'id':str(r.pk), 'purpose':r.purpose,'status':r.status,
                    'simulated':True,'created_at':r.created_at.isoformat()}
        if pk is not None:
            return Response(render(get_object_or_404(records, pk=pk)))
        return Response({'requests':[render(r) for r in records.order_by('-created_at')[:100]]})


class ProofInput(serializers.Serializer):
    challenge_id = serializers.UUIDField()
    signature = serializers.CharField(max_length=160)
    public_key = serializers.CharField(max_length=200, required=False)
    device_id = serializers.UUIDField(required=False)


class DeviceChallengeView(PersonalView):
    def post(self, request):
        from . import licensing
        purpose = request.data.get('purpose')
        if purpose not in ('enroll','lease'):
            raise ValidationError('purpose must be enroll or lease')
        try:
            row = licensing.challenge(request.user, purpose)
        except DjangoValidationError as exc:
            raise ValidationError(exc.messages)
        return Response({'id':str(row.pk),'nonce':row.nonce,'purpose':row.purpose,
            'message':licensing.proof_message(row).decode('ascii'),
            'expires_at':int(row.expires_at.timestamp())})


class DeviceEnrollView(PersonalView):
    def post(self, request):
        from . import licensing
        data = ProofInput(data=request.data)
        data.is_valid(raise_exception=True)
        values = data.validated_data
        if not values.get('public_key'):
            raise ValidationError('public_key required')
        device = licensing.enroll(request.user, values['challenge_id'], values['public_key'], values['signature'])
        return Response({'device_id':str(device.pk),'thumbprint':device.thumbprint,
                         'subject':str(services.state_for(request.user).subject)}, status=201)


class OfflineLeaseView(PersonalView):
    def post(self, request):
        from . import licensing
        data = ProofInput(data=request.data)
        data.is_valid(raise_exception=True)
        values = data.validated_data
        if not values.get('device_id'):
            raise ValidationError('device_id required')
        try:
            result = licensing.issue_lease(request.user, values['challenge_id'], values['device_id'], values['signature'])
        except (DjangoValidationError, OSError, ValueError):
            return Response({'status':'verification_required','reason':'signer_or_resource_unavailable'}, status=503)
        return Response(result)

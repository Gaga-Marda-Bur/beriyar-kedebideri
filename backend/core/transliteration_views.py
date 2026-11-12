from rest_framework import serializers
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from .transliteration import SCRIPTS, transliterate


class ConversionInput(serializers.Serializer):
    text = serializers.CharField(max_length=100000, allow_blank=True, trim_whitespace=False)
    source_script = serializers.ChoiceField(choices=SCRIPTS)
    target_script = serializers.ChoiceField(choices=SCRIPTS)
    latin_lowercase = serializers.BooleanField(default=False)


class TransliterationAPIView(APIView):
    """Stateless public text utility; no save, no inferred language, no account data."""
    permission_classes = [AllowAny]

    def post(self, request):
        payload = ConversionInput(data=request.data)
        payload.is_valid(raise_exception=True)
        return Response(transliterate(**payload.validated_data))

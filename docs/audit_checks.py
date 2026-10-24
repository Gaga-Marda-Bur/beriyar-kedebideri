"""Reproductions d'audit, uniquement sur une base SQLite en mémoire.

Depuis la racine : backend/venv/Scripts/python.exe docs/audit_checks.py
Aucun accès à la base existante, au réseau ou au stockage de production.
"""
import json
import os
import sys
import logging
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))
os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings"
os.environ["DATABASE_URL"] = "sqlite:///:memory:"
os.environ["USE_R2"] = "False"
os.environ["DEBUG"] = "True"
os.environ["ALLOWED_HOSTS"] = "testserver,localhost"
os.environ["SECRET_KEY"] = "isolated-audit-only-not-a-production-secret"

import django
django.setup()

from django.conf import settings
from django.core.management import call_command
from rest_framework.test import APIClient
from learning.models import LearningTheme, LearningUnit
from progress.models import UnitProgress
from vocabulary.models import Word
from alphabet.models import Character, CharacterAudio
from audio_assets.models import AudioAsset
from offline_packs.models import LessonPack
from offline_packs.services.offline_pack_generator import OfflinePackGenerator

assert settings.DATABASES["default"]["NAME"] == ":memory:"
call_command("migrate", verbosity=0, interactive=False)
client = APIClient(raise_request_exception=False)
logging.getLogger("django.request").setLevel(logging.CRITICAL)
theme = LearningTheme.objects.create(slug="audit-theme", title_fr="Audit")
unit = LearningUnit.objects.create(theme=theme, slug="audit-unit", title_fr="Audit")
record = UnitProgress.objects.create(
    device_id="audit-victim", unit=unit, lessons_seen=8,
    client_updated_at="2026-10-23T10:00:00Z",
)

output = {}
listing = client.get("/api/progress/unit-progress/")
output["anonymous_progress_listing"] = {
    "http_status": listing.status_code,
    "count": listing.data.get("count"),
    "exposes_device_id": listing.data["results"][0]["device_id"] == "audit-victim",
}
sync = client.post("/api/progress/unit-progress/sync/", {"items": [{
    "unit_slug": unit.slug, "device_id": "audit-victim", "score_percent": 999,
    "lessons_seen": 1, "updated_at": "2020-01-01T00:00:00Z",
}]}, format="json")
record.refresh_from_db()
output["anonymous_stale_sync"] = {
    "http_status": sync.status_code, "lessons_seen_before": 8,
    "lessons_seen_after": record.lessons_seen,
    "best_score_after": record.best_score_percent,
    "client_updated_at_after": record.client_updated_at.isoformat(),
}
malformed = client.post("/api/progress/unit-progress/sync/", {"items": [None]}, format="json")
output["malformed_sync_item"] = {"http_status": malformed.status_code}

draft = client.get("/api/learning/units/")
output["anonymous_draft_unit"] = {
    "http_status": draft.status_code,
    "draft_returned": any(item["slug"] == unit.slug for item in draft.data["results"]),
    "stored_status": unit.status,
}
Word.objects.bulk_create([Word(beriya_text=f"audit-{i}") for i in range(51)])
page = client.get("/api/vocabulary/words/")
output["pagination_51_words"] = {
    "count": page.data["count"], "first_page": len(page.data["results"]),
    "has_next": bool(page.data["next"]),
}
audio = AudioAsset.objects.create(
    title="Audit", file="audio/audit.mp3", validation_status="draft",
    notes="audit-internal-note",
)
audio_response = client.get("/api/audio/")
if audio_response.status_code == 200:
    output["anonymous_draft_audio"] = {
        "http_status": audio_response.status_code,
        "draft_returned": any(str(a["id"]) == str(audio.id) for a in audio_response.data["results"]),
        "internal_notes_returned": any(a.get("notes") == "audit-internal-note"
                                       for a in audio_response.data["results"]),
    }
else:
    output["anonymous_draft_audio"] = {"http_status": audio_response.status_code}
audio.validation_status = "published"
audio.save(update_fields=["validation_status"])
character = Character.objects.create(symbol="audit", unicode_code="AUDIT")
CharacterAudio.objects.create(character=character, audio_asset=audio, role="normal")
unit.characters.add(character)
saved_pack = LessonPack.objects.create(slug="audit-flow", title_fr="Audit")
saved_pack.units.add(unit)
flow = OfflinePackGenerator(saved_pack)._serialize_units()[0]["core_flow"]
output["offline_core_flow_audio"] = flow[0]["audio_url"]

class RemoteField:
    @property
    def path(self):
        raise NotImplementedError("Remote storage has no local path")

pack = LessonPack(slug="audit", title_fr="Audit")
generator = OfflinePackGenerator(pack)
output["remote_media_copy"] = generator._copy_media(
    ROOT / "docs", RemoteField(), "audio", "test"
)
pack.file = "offline_packs/audit.zip"
from unittest.mock import PropertyMock, patch
with patch.object(type(pack.file), "path", new_callable=PropertyMock,
                  side_effect=NotImplementedError("Remote storage has no local path")):
    try:
        pack.update_file_metadata()
        output["remote_pack_metadata"] = "no error"
    except NotImplementedError:
        output["remote_pack_metadata"] = "NotImplementedError"

print(json.dumps(output, ensure_ascii=False, indent=2))

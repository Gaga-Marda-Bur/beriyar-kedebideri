"""Services métier pour les publications No Ena (audit A23).

Fournit l'incrémentation atomique des compteurs de vues avec protection
anti-rebond (session web et cache d'identifiant pour l'API).
"""
import hashlib
from django.core.cache import cache
from django.db.models import F


def _get_client_ident(request, device_id=None):
    """Calcule une empreinte anonyme pour dédoublonner les vues API sans session."""
    if device_id and isinstance(device_id, str) and device_id.strip():
        raw = f"dev:{device_id.strip()[:120]}"
    elif request:
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0].strip()
        else:
            ip = request.META.get('REMOTE_ADDR', '')
        user_agent = request.META.get('HTTP_USER_AGENT', '')
        raw = f"ip:{ip}:{user_agent[:60]}"
    else:
        raw = "anonymous"

    return hashlib.sha256(raw.encode('utf-8')).hexdigest()[:24]


def record_publication_view(publication, request=None, device_id=None, window_seconds=3600):
    """Enregistre une vue de façon atomique avec protection anti-rebond.

    - Sur le Web : utilise request.session pour ne pas compter les rafraîchissements (F5).
    - Sur l'API : utilise le cache avec un TTL glissant (par défaut 1h) basé sur le terminal/IP.
    - Utilise F('view_count') + 1 pour garantir l'absence de race condition en concurrence.

    Retourne:
        tuple (view_count: int, was_counted: bool)
    """
    publication_id = publication.id
    already_viewed = False

    # 1. Vérification session (navigation Web standard)
    if request and hasattr(request, 'session'):
        viewed_list = request.session.get('viewed_no_ena_ids', [])
        if publication_id in viewed_list:
            already_viewed = True
        else:
            # Conserver au maximum les 100 dernières publications vues dans la session
            if len(viewed_list) >= 100:
                viewed_list = viewed_list[-90:]
            viewed_list.append(publication_id)
            request.session['viewed_no_ena_ids'] = viewed_list

    # 2. Vérification cache glissant (appels API ou sessions anonymes sans cookie persistant)
    if not already_viewed:
        ident_hash = _get_client_ident(request, device_id)
        cache_key = f"no_ena_view:{publication_id}:{ident_hash}"
        if cache.get(cache_key):
            already_viewed = True
        else:
            cache.set(cache_key, 1, timeout=window_seconds)

    # 3. Incrémentation atomique si nouvelle vue
    from .models import NoEnaPublication

    if not already_viewed:
        NoEnaPublication.objects.filter(pk=publication.pk).update(
            view_count=F('view_count') + 1
        )
        publication.refresh_from_db(fields=['view_count'])
        return publication.view_count, True
    else:
        publication.refresh_from_db(fields=['view_count'])
        return publication.view_count, False

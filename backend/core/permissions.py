PILOT_GROUP_NAME = 'pilot_erfe_v1'


def is_staff_preview(request):
    """
    Returns True if the request is made by an authenticated staff/superuser.
    Allows staff to preview draft, review, and archived content without
    leaking unvalidated content to public users.
    """
    if not request:
        return False
    user = getattr(request, 'user', None)
    return bool(user and user.is_authenticated and user.is_staff)


def is_pilot_user(request):
    """
    Returns True if the request is made by an authenticated learner enrolled
    in the private pilot group (`pilot_erfe_v1`).
    """
    if not request:
        return False
    user = getattr(request, 'user', None)
    if not (user and user.is_authenticated):
        return False
    if hasattr(request, '_bk_is_pilot_user'):
        return request._bk_is_pilot_user
    result = user.groups.filter(name=PILOT_GROUP_NAME).exists()
    request._bk_is_pilot_user = result
    return result


def allowed_statuses_for_request(request):
    """
    Returns allowed publication statuses for the caller, or None for staff
    (unrestricted preview). Pilot users may access `published` and `validated`
    content only (never `draft`).
    """
    if is_staff_preview(request):
        return None
    if is_pilot_user(request):
        return ('published', 'validated')
    return ('published',)


def filter_by_access(queryset, request, status_field='status', status_param=None):
    """Filters a queryset according to staff, private pilot, or public rights."""
    allowed = allowed_statuses_for_request(request)
    if allowed is None:
        if status_param:
            return queryset.filter(**{status_field: status_param})
        return queryset
    if status_param and status_param in allowed:
        return queryset.filter(**{status_field: status_param})
    if len(allowed) == 1:
        return queryset.filter(**{status_field: allowed[0]})
    return queryset.filter(**{f'{status_field}__in': allowed})

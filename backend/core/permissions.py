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

def build_file_url(file_field, request=None):
    if not file_field:
        return None

    if request:
        return request.build_absolute_uri(file_field.url)

    return file_field.url


def get_primary_audio_link(audio_links, role):
    valid_links = [
        link for link in audio_links
        if link.role == role
        and link.audio_asset.validation_status == 'published'
        and link.audio_asset.file
    ]

    valid_links.sort(
        key=lambda link: (
            not link.is_primary,
            link.order,
            str(link.audio_asset_id),
        )
    )

    if valid_links:
        return valid_links[0]

    return None


def get_linked_audio_url(
    obj,
    role,
    legacy_field_name=None,
    request=None,
):
    links = list(obj.audio_links.all())

    primary_link = get_primary_audio_link(links, role)

    if primary_link:
        return build_file_url(primary_link.audio_asset.file, request=request)

    if legacy_field_name:
        legacy_file = getattr(obj, legacy_field_name, None)

        if legacy_file:
            return build_file_url(legacy_file, request=request)

    return None


def get_linked_audio_file(
    obj,
    role,
    legacy_field_name=None,
):
    links = list(obj.audio_links.all())

    primary_link = get_primary_audio_link(links, role)

    if primary_link:
        return primary_link.audio_asset.file

    if legacy_field_name:
        legacy_file = getattr(obj, legacy_field_name, None)

        if legacy_file:
            return legacy_file

    return None
"""Crée de manière idempotente les tables DatabaseCache configurées lors de migrate."""
from django.core.management import call_command
from django.db import migrations


def create_configured_cache_tables(apps, schema_editor):
    call_command('createcachetable', database=schema_editor.connection.alias, verbosity=0)


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.RunPython(
            create_configured_cache_tables,
            reverse_code=migrations.RunPython.noop,
        ),
    ]

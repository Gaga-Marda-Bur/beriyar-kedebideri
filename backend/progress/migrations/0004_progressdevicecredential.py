from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


def mark_account_history(apps, schema_editor):
    # Existing FK is proof of a known account owner; do not claim guest histories.
    apps.get_model('progress', 'UnitProgress').objects.using(schema_editor.connection.alias).filter(
        user__isnull=False).update(account_bound=True)


class Migration(migrations.Migration):
    dependencies = [
        ('progress', '0003_unitprogress_scoring_metadata'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]
    operations = [
        migrations.AddField(model_name='unitprogress', name='account_bound',
                            field=models.BooleanField(default=False)),
        migrations.RunPython(mark_account_history, migrations.RunPython.noop),
        migrations.CreateModel(
            name='ProgressDeviceCredential',
            fields=[
                ('device_id', models.CharField(max_length=120, primary_key=True, serialize=False)),
                ('token_digest', models.CharField(max_length=64)),
                ('account_bound', models.BooleanField(default=False)),
                ('user', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL,
                                           related_name='+', to=settings.AUTH_USER_MODEL)),
            ],
        ),
    ]

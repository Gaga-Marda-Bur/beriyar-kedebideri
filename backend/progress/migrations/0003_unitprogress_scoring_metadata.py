from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [('progress', '0002_unitprogress_device_token')]
    operations = [
        migrations.AddField(model_name='unitprogress', name='scoring_version',
                            field=models.PositiveSmallIntegerField(default=1)),
        migrations.AddField(model_name='unitprogress', name='last_session_score',
                            field=models.PositiveSmallIntegerField(blank=True, null=True)),
    ]

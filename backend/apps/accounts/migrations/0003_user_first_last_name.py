"""Replace the full_name column with first_name + last_name on the users table."""
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0002_emailverificationtoken"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="user",
            name="full_name",
        ),
        migrations.AddField(
            model_name="user",
            name="first_name",
            field=models.CharField(default="", max_length=150),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name="user",
            name="last_name",
            field=models.CharField(blank=True, default="", max_length=150),
        ),
    ]

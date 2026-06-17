"""Seed the bootstrap 'System NGO' so the first admin (createsuperuser) and
admin-provisioned accounts have a non-null ngo to belong to."""
from django.db import migrations

SYSTEM_REG_NO = "SYSTEM-0001"


def create_system_ngo(apps, schema_editor):
    NGO = apps.get_model("ngos", "NGO")
    NGO.objects.get_or_create(
        registration_no=SYSTEM_REG_NO,
        defaults={
            "name": "System NGO",
            "description": "Bootstrap NGO for system administrators.",
        },
    )


def remove_system_ngo(apps, schema_editor):
    NGO = apps.get_model("ngos", "NGO")
    NGO.objects.filter(registration_no=SYSTEM_REG_NO).delete()


class Migration(migrations.Migration):
    dependencies = [("ngos", "0001_initial")]
    operations = [migrations.RunPython(create_system_ngo, remove_system_ngo)]

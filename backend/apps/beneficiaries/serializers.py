from datetime import date

from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from .models import Beneficiary


class BeneficiarySerializer(serializers.ModelSerializer):
    # Age is derived from date_of_birth on read — never stored.
    age = serializers.SerializerMethodField()
    # Display name so clients need not resolve the project id themselves.
    project_name = serializers.CharField(
        source="project.project_name", read_only=True
    )

    class Meta:
        model = Beneficiary
        fields = [
            "id",
            "name",
            "gender",
            "date_of_birth",
            "age",
            "phone",
            "location",
            "project",
            "project_name",
            "is_active",
            "created_at",
        ]
        # is_active is managed via soft-delete, not direct writes.
        read_only_fields = ["id", "is_active", "created_at"]

    @extend_schema_field(serializers.IntegerField(allow_null=True))
    def get_age(self, obj):
        dob = obj.date_of_birth
        if not dob:
            return None
        today = date.today()
        return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))

    def validate_date_of_birth(self, value):
        if value and value > date.today():
            raise serializers.ValidationError("Date of birth cannot be in the future.")
        return value

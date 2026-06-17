from rest_framework import serializers

from .models import NGO


class NGOSerializer(serializers.ModelSerializer):
    class Meta:
        model = NGO
        fields = [
            "id",
            "name",
            "registration_no",
            "description",
            "address",
            "contact",
            "logo",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

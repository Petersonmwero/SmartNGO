from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from .models import Indicator


class IndicatorSerializer(serializers.ModelSerializer):
    # Convenience for KPI displays; not stored.
    progress_percent = serializers.SerializerMethodField()

    class Meta:
        model = Indicator
        fields = [
            "id",
            "project",
            "indicator_name",
            "target_value",
            "current_value",
            "unit",
            "progress_percent",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    @extend_schema_field(serializers.FloatField(allow_null=True))
    def get_progress_percent(self, obj):
        if obj.target_value and obj.target_value > 0:
            return round(float(obj.current_value) / float(obj.target_value) * 100, 2)
        return None

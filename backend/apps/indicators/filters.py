import django_filters

from .models import Indicator


class IndicatorFilter(django_filters.FilterSet):
    project_id = django_filters.NumberFilter(field_name="project_id")

    class Meta:
        model = Indicator
        fields = ["project_id"]

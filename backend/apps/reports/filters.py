import django_filters

from .models import Report


class ReportFilter(django_filters.FilterSet):
    project_id = django_filters.NumberFilter(field_name="project_id")

    class Meta:
        model = Report
        fields = ["project_id", "status", "report_type"]

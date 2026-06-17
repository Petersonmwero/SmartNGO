import django_filters

from .models import Beneficiary


class BeneficiaryFilter(django_filters.FilterSet):
    project_id = django_filters.NumberFilter(field_name="project_id")

    class Meta:
        model = Beneficiary
        fields = ["project_id", "gender", "is_active"]

import django_filters

from .models import Milestone, Project


class ProjectFilter(django_filters.FilterSet):
    # Support ?ngo_id=<n> in addition to ?status=<s>.
    ngo_id = django_filters.NumberFilter(field_name="ngo_id")

    class Meta:
        model = Project
        fields = ["status", "ngo_id"]


class MilestoneFilter(django_filters.FilterSet):
    project_id = django_filters.NumberFilter(field_name="project_id")

    class Meta:
        model = Milestone
        fields = ["status", "project_id"]

from rest_framework import serializers

from .models import Milestone, Project, ProjectAssignment, ProjectPhase

# Milestone weights are a bounded 1-10 scale (1 = minor, 10 = critical).
MILESTONE_WEIGHT_MIN = 1
MILESTONE_WEIGHT_MAX = 10


class ProjectPhaseSerializer(serializers.ModelSerializer):
    utilization_percentage = serializers.ReadOnlyField()

    class Meta:
        model = ProjectPhase
        fields = [
            "id",
            "project",
            "phase_name",
            "phase_type",
            "allocated_budget",
            "spent_budget",
            "start_date",
            "end_date",
            "status",
            "description",
            "utilization_percentage",
            "created_at",
        ]
        # project comes from the URL, not the request body.
        read_only_fields = ["id", "project", "created_at"]

    def validate(self, attrs):
        """Cross-field checks: dates ordered, spending non-negative."""
        start = attrs.get("start_date", getattr(self.instance, "start_date", None))
        end = attrs.get("end_date", getattr(self.instance, "end_date", None))
        if start and end and end < start:
            raise serializers.ValidationError(
                {"end_date": "End date must be on or after the start date."}
            )
        for field in ("allocated_budget", "spent_budget"):
            value = attrs.get(field)
            if value is not None and value < 0:
                raise serializers.ValidationError(
                    {field: "Must be zero or a positive amount."}
                )
        return attrs


class ProjectSerializer(serializers.ModelSerializer):
    # Weighted Composite Progress (EVM) — all computed server-side.
    progress_percentage = serializers.ReadOnlyField()
    financial_progress = serializers.ReadOnlyField()
    physical_progress = serializers.ReadOnlyField()
    time_progress = serializers.ReadOnlyField()
    planned_value_progress = serializers.ReadOnlyField()
    cost_performance_index = serializers.ReadOnlyField()
    schedule_performance_index = serializers.ReadOnlyField()
    health_status = serializers.ReadOnlyField()
    total_spent = serializers.DecimalField(
        max_digits=15, decimal_places=2, read_only=True
    )
    budget_remaining = serializers.DecimalField(
        max_digits=15, decimal_places=2, read_only=True
    )
    phases = ProjectPhaseSerializer(many=True, read_only=True)

    class Meta:
        model = Project
        fields = [
            "id",
            "project_name",
            "description",
            "budget",
            "start_date",
            "end_date",
            "status",
            "ngo",
            "progress_percentage",
            "financial_progress",
            "physical_progress",
            "time_progress",
            "planned_value_progress",
            "cost_performance_index",
            "schedule_performance_index",
            "health_status",
            "total_spent",
            "budget_remaining",
            "phases",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]
        # ngo is optional in the payload: for non-admins it is forced to the
        # caller's own NGO in the view; admins must supply it explicitly.
        extra_kwargs = {"ngo": {"required": False}}


class ProjectAssignmentSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source="user.full_name", read_only=True)

    class Meta:
        model = ProjectAssignment
        fields = ["id", "project", "user", "user_name", "role", "assigned_at"]
        # project comes from the URL, not the request body.
        read_only_fields = ["id", "project", "assigned_at"]


class MilestoneSerializer(serializers.ModelSerializer):
    weight = serializers.IntegerField(
        min_value=MILESTONE_WEIGHT_MIN,
        max_value=MILESTONE_WEIGHT_MAX,
        default=MILESTONE_WEIGHT_MIN,
    )

    class Meta:
        model = Milestone
        fields = [
            "id",
            "project",
            "title",
            "description",
            "due_date",
            "status",
            "weight",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

from rest_framework import serializers

from .models import Milestone, Project, ProjectAssignment


class ProjectSerializer(serializers.ModelSerializer):
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
    class Meta:
        model = Milestone
        fields = [
            "id",
            "project",
            "title",
            "description",
            "due_date",
            "status",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

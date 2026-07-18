from django.contrib import admin

from .models import Milestone, Project, ProjectAssignment, ProjectPhase


@admin.register(Project)
class ProjectAdmin(admin.ModelAdmin):
    list_display = ("id", "project_name", "ngo", "status", "budget", "start_date")
    list_filter = ("status", "ngo")
    search_fields = ("project_name",)


@admin.register(ProjectAssignment)
class ProjectAssignmentAdmin(admin.ModelAdmin):
    list_display = ("id", "project", "user", "role", "assigned_at")
    list_filter = ("role",)


@admin.register(Milestone)
class MilestoneAdmin(admin.ModelAdmin):
    list_display = ("id", "title", "project", "due_date", "status", "weight")
    list_filter = ("status",)


@admin.register(ProjectPhase)
class ProjectPhaseAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "phase_name",
        "project",
        "phase_type",
        "allocated_budget",
        "spent_budget",
        "status",
    )
    list_filter = ("phase_type", "status")

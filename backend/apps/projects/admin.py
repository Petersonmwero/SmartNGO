from django.contrib import admin

from .models import Milestone, Project, ProjectAssignment


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
    list_display = ("id", "title", "project", "due_date", "status")
    list_filter = ("status",)

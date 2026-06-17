"""Reusable DRF view mixins shared across resource apps."""
from rest_framework.exceptions import PermissionDenied

from apps.accounts.models import Role


class ProjectScopedViewSetMixin:
    """Role/NGO scoping for resources that belong to a Project.

    Subclasses must set ``model``. Read access is scoped by role:
      - admin  -> all rows
      - officer-> rows whose project they are assigned to
      - manager/donor -> rows whose project is in their NGO

    Write access (create/update) additionally validates that the target
    project is one the caller may write to. Per-action role gating (who may
    write at all) is left to each ViewSet's ``get_permissions``.
    """

    model = None
    project_lookup = "project"  # FK field name to Project on the model

    def base_queryset(self):
        return self.model._default_manager.all()

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return self.model._default_manager.none()
        user = self.request.user
        qs = self.base_queryset()
        if user.role == Role.ADMIN:
            return qs
        if user.role == Role.OFFICER:
            return qs.filter(
                **{f"{self.project_lookup}__assignments__user": user}
            ).distinct()
        return qs.filter(**{f"{self.project_lookup}__ngo_id": user.ngo_id})

    def _resolve_project(self, serializer):
        return serializer.validated_data.get(self.project_lookup) or getattr(
            serializer.instance, self.project_lookup, None
        )

    def validate_project_access(self, project):
        user = self.request.user
        if user.role == Role.ADMIN:
            return
        if user.role == Role.OFFICER:
            if not project.assignments.filter(user=user).exists():
                raise PermissionDenied("You are not assigned to this project.")
            return
        # manager / donor
        if project.ngo_id != user.ngo_id:
            raise PermissionDenied("Project is not in your NGO.")

    def perform_create(self, serializer):
        self.validate_project_access(self._resolve_project(serializer))
        serializer.save()

    def perform_update(self, serializer):
        self.validate_project_access(self._resolve_project(serializer))
        serializer.save()

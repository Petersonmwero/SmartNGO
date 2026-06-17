"""
Role-based permission classes (server-side RBAC).

Per-role gate classes plus a couple of composable helpers. These are DRF
``BasePermission`` subclasses, so they support the ``&`` / ``|`` / ``~``
operators and can be combined in a ViewSet's ``permission_classes`` —
e.g. ``[IsSystemAdmin | IsProjectManager]``.

Note: ``IsSystemAdmin`` is intentionally named to avoid colliding with DRF's
built-in ``IsAdminUser`` (which checks ``is_staff``, not our ``role`` field).

Row-level "own NGO" scoping is enforced primarily by filtering each ViewSet's
queryset in Phase 2; ``IsSameNGO`` below provides the matching object-level
check for detail/update/delete requests.
"""
from rest_framework.permissions import SAFE_METHODS, BasePermission

from .models import Role


class RolePermission(BasePermission):
    """Base class: grant access only to authenticated users in ``allowed_roles``."""

    allowed_roles = ()

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and getattr(user, "role", None) in self.allowed_roles
        )


class IsSystemAdmin(RolePermission):
    """Application administrator (role='admin') — full access."""

    allowed_roles = (Role.ADMIN,)


class IsProjectManager(RolePermission):
    """Project manager (role='manager')."""

    allowed_roles = (Role.MANAGER,)


class IsFieldOfficer(RolePermission):
    """Field officer (role='officer')."""

    allowed_roles = (Role.OFFICER,)


class IsDonor(RolePermission):
    """Donor (role='donor') — read-only consumer."""

    allowed_roles = (Role.DONOR,)


class ReadOnly(BasePermission):
    """Allow only safe (GET/HEAD/OPTIONS) methods. Compose with role classes."""

    def has_permission(self, request, view):
        return request.method in SAFE_METHODS


class IsSameNGO(BasePermission):
    """Object-level: non-admins may only act on objects within their own NGO.

    Resolves the object's NGO from ``obj.ngo_id`` directly, or via a related
    ``project`` (for project-scoped models like reports, beneficiaries,
    indicators, milestones). Admins bypass the check.
    """

    def has_object_permission(self, request, view, obj):
        user = request.user
        if getattr(user, "role", None) == Role.ADMIN:
            return True

        ngo_id = getattr(obj, "ngo_id", None)
        if ngo_id is None:
            project = getattr(obj, "project", None)
            ngo_id = getattr(project, "ngo_id", None)
        return ngo_id is not None and ngo_id == user.ngo_id

"""Tests for the role permission classes."""
import pytest
from django.contrib.auth.models import AnonymousUser
from rest_framework.test import APIRequestFactory

from apps.accounts.permissions import (
    IsDonor,
    IsFieldOfficer,
    IsProjectManager,
    IsSameNGO,
    IsSystemAdmin,
    ReadOnly,
)
from apps.projects.models import Project

pytestmark = pytest.mark.django_db

rf = APIRequestFactory()


def _grants(perm, user, method="get"):
    request = getattr(rf, method)("/")
    request.user = user
    return perm.has_permission(request, view=None)


@pytest.fixture
def role_users(admin_user, manager_user, officer_user, donor_user):
    return {
        "admin": admin_user,
        "manager": manager_user,
        "officer": officer_user,
        "donor": donor_user,
    }


@pytest.mark.parametrize(
    "perm,allowed_role",
    [
        (IsSystemAdmin(), "admin"),
        (IsProjectManager(), "manager"),
        (IsFieldOfficer(), "officer"),
        (IsDonor(), "donor"),
    ],
)
def test_role_gate_grants_only_matching_role(perm, allowed_role, role_users):
    for role, user in role_users.items():
        assert _grants(perm, user) is (role == allowed_role)


def test_anonymous_is_denied():
    request = rf.get("/")
    request.user = AnonymousUser()
    assert IsSystemAdmin().has_permission(request, None) is False


def test_readonly_allows_safe_blocks_unsafe(donor_user):
    assert _grants(ReadOnly(), donor_user, "get") is True
    assert _grants(ReadOnly(), donor_user, "post") is False


class TestIsSameNGO:
    def test_manager_can_access_own_ngo_object(self, manager_user, ngo):
        project = Project.objects.create(project_name="P", ngo=ngo)
        request = rf.get("/")
        request.user = manager_user
        assert IsSameNGO().has_object_permission(request, None, project) is True

    def test_manager_blocked_on_other_ngo_object(self, manager_user, other_ngo):
        project = Project.objects.create(project_name="P", ngo=other_ngo)
        request = rf.get("/")
        request.user = manager_user
        assert IsSameNGO().has_object_permission(request, None, project) is False

    def test_admin_bypasses_ngo_scope(self, admin_user, other_ngo):
        project = Project.objects.create(project_name="P", ngo=other_ngo)
        request = rf.get("/")
        request.user = admin_user
        assert IsSameNGO().has_object_permission(request, None, project) is True

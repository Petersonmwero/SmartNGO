"""
Security boundary pass (Phase 5, step 26).

Consolidated, deliberate probing of:
  - role permission boundaries (cross-role denials)
  - JWT access-token expiry rejection
  - refresh-token blacklist enforcement after logout
  - anonymous rate limiting (429)
"""
from datetime import timedelta

import pytest
from rest_framework_simplejwt.tokens import AccessToken

from apps.projects.models import Project
from conftest import PASSWORD

LOGIN = "/api/v1/auth/login/"
LOGOUT = "/api/v1/auth/logout/"
REFRESH = "/api/v1/auth/token/refresh/"
PROJECTS = "/api/v1/projects/"
NGOS = "/api/v1/ngos/"
REPORTS = "/api/v1/reports/"
BENEFICIARIES = "/api/v1/beneficiaries/"
INDICATORS = "/api/v1/indicators/"
MILESTONES = "/api/v1/milestones/"

pytestmark = pytest.mark.django_db


class TestRolePermissionBoundaries:
    @pytest.mark.parametrize("fixture", ["officer_user", "donor_user"])
    def test_non_managers_cannot_create_projects(self, auth_client, request, fixture):
        user = request.getfixturevalue(fixture)
        resp = auth_client(user).post(
            PROJECTS, {"project_name": "X", "status": "planning"}, format="json"
        )
        assert resp.status_code == 403

    @pytest.mark.parametrize("fixture", ["manager_user", "officer_user", "donor_user"])
    def test_only_admin_can_reach_ngos(self, auth_client, request, fixture):
        user = request.getfixturevalue(fixture)
        assert auth_client(user).get(NGOS).status_code == 403

    def test_donor_is_read_only_across_resources(self, auth_client, donor_user, ngo):
        project = Project.objects.create(project_name="P", ngo=ngo)
        client = auth_client(donor_user)
        assert client.post(REPORTS, {"project": project.id, "title": "t", "report_type": "daily"}, format="json").status_code == 403
        assert client.post(BENEFICIARIES, {"project": project.id, "name": "n", "gender": "male"}, format="json").status_code == 403
        assert client.post(INDICATORS, {"project": project.id, "indicator_name": "i", "target_value": "1"}, format="json").status_code == 403
        assert client.post(MILESTONES, {"project": project.id, "title": "m"}, format="json").status_code == 403

    def test_officer_cannot_create_indicators_or_milestones(self, auth_client, officer_user, ngo):
        project = Project.objects.create(project_name="P", ngo=ngo)
        client = auth_client(officer_user)
        assert client.post(INDICATORS, {"project": project.id, "indicator_name": "i", "target_value": "1"}, format="json").status_code == 403
        assert client.post(MILESTONES, {"project": project.id, "title": "m"}, format="json").status_code == 403

    def test_manager_cannot_see_other_ngo_projects(self, auth_client, manager_user, other_ngo):
        foreign = Project.objects.create(project_name="Foreign", ngo=other_ngo)
        # Not in the manager's queryset -> 404 on detail.
        assert auth_client(manager_user).get(f"{PROJECTS}{foreign.id}/").status_code == 404

    def test_unauthenticated_is_rejected(self, api_client):
        assert api_client.get(PROJECTS).status_code == 401


class TestTokenLifecycle:
    def test_expired_access_token_is_rejected(self, api_client, officer_user):
        token = AccessToken.for_user(officer_user)
        token.set_exp(lifetime=-timedelta(minutes=1))  # already expired
        api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
        assert api_client.get(PROJECTS).status_code == 401

    def test_tampered_token_is_rejected(self, api_client, officer_user):
        token = str(AccessToken.for_user(officer_user))
        api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}corrupted")
        assert api_client.get(PROJECTS).status_code == 401

    def test_blacklisted_refresh_cannot_mint_access(self, api_client, officer_user):
        login = api_client.post(
            LOGIN, {"email": officer_user.email, "password": PASSWORD}, format="json"
        )
        access = login.data["access"]
        refresh = login.data["refresh"]

        api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
        assert api_client.post(LOGOUT, {"refresh": refresh}, format="json").status_code == 204

        api_client.credentials()  # drop auth header
        assert api_client.post(REFRESH, {"refresh": refresh}, format="json").status_code == 401


class TestRateLimiting:
    def test_anonymous_requests_are_throttled(self, api_client):
        # AnonRateThrottle is 20/min; the 21st anonymous request should be 429.
        statuses = [
            api_client.post(
                LOGIN, {"email": "x@y.z", "password": "nope"}, format="json"
            ).status_code
            for _ in range(25)
        ]
        assert 429 in statuses
        assert statuses[:20].count(429) == 0  # first 20 within the limit

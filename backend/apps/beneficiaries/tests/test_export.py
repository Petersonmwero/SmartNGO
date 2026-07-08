"""Tests for GET /api/v1/beneficiaries/export/ — CSV download."""
import csv
import io
from datetime import date

import pytest

from apps.beneficiaries.models import Beneficiary
from apps.projects.models import Project, ProjectAssignment

EXPORT = "/api/v1/beneficiaries/export/"

pytestmark = pytest.mark.django_db


@pytest.fixture
def project(ngo):
    return Project.objects.create(project_name="WASH", ngo=ngo)


@pytest.fixture
def beneficiary(project):
    return Beneficiary.objects.create(
        name="Alice Mwangi",
        gender="female",
        date_of_birth=date(1995, 3, 14),
        phone="0712345678",
        location="Nairobi",
        project=project,
    )


class TestBeneficiaryExport:
    def test_admin_downloads_csv(self, auth_client, admin_user, beneficiary):
        resp = auth_client(admin_user).get(EXPORT)
        assert resp.status_code == 200
        assert resp["Content-Type"] == "text/csv"
        assert "attachment" in resp["Content-Disposition"]

    def test_csv_contains_header_and_row(self, auth_client, admin_user, beneficiary):
        resp = auth_client(admin_user).get(EXPORT)
        reader = csv.reader(io.StringIO(resp.content.decode()))
        rows = list(reader)
        assert rows[0][1] == "Name"          # header row
        assert rows[1][1] == "Alice Mwangi"  # data row

    def test_csv_contains_project_name(self, auth_client, admin_user, beneficiary):
        resp = auth_client(admin_user).get(EXPORT)
        content = resp.content.decode()
        assert "WASH" in content

    def test_soft_deleted_beneficiary_excluded(self, auth_client, admin_user, beneficiary):
        beneficiary.is_active = False
        beneficiary.save(update_fields=["is_active"])
        resp = auth_client(admin_user).get(EXPORT)
        reader = csv.reader(io.StringIO(resp.content.decode()))
        rows = list(reader)
        # Only the header row; no data rows.
        assert len(rows) == 1

    def test_officer_sees_only_assigned_project_beneficiaries(
        self, auth_client, officer_user, project, beneficiary
    ):
        # Officer has no assignment → should get empty export.
        resp = auth_client(officer_user).get(EXPORT)
        reader = csv.reader(io.StringIO(resp.content.decode()))
        rows = list(reader)
        assert len(rows) == 1  # header only

    def test_officer_with_assignment_sees_beneficiary(
        self, auth_client, officer_user, project, beneficiary
    ):
        ProjectAssignment.objects.create(project=project, user=officer_user, role="officer")
        resp = auth_client(officer_user).get(EXPORT)
        reader = csv.reader(io.StringIO(resp.content.decode()))
        rows = list(reader)
        assert len(rows) == 2  # header + 1 data row

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.get(EXPORT)
        assert resp.status_code == 401

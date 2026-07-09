"""Tests for the nested report-images multipart upload sub-resource."""
import pytest

from apps.reports.models import Report, ReportImage

from .conftest import make_image_file

pytestmark = pytest.mark.django_db


def _images_url(report_id):
    return f"/api/v1/reports/{report_id}/images/"


class TestUpload:
    def test_officer_uploads_image(self, auth_client, officer_user, draft_report):
        resp = auth_client(officer_user).post(
            _images_url(draft_report.id),
            {"image": make_image_file(), "caption": "site"},
            format="multipart",
        )
        assert resp.status_code == 201
        assert resp.data["caption"] == "site"

    def test_multiple_images_per_report(self, auth_client, officer_user, draft_report):
        client = auth_client(officer_user)
        client.post(_images_url(draft_report.id), {"image": make_image_file("a.png")}, format="multipart")
        client.post(_images_url(draft_report.id), {"image": make_image_file("b.png")}, format="multipart")
        assert ReportImage.objects.filter(report=draft_report).count() == 2

    def test_non_image_rejected(self, auth_client, officer_user, draft_report):
        from django.core.files.uploadedfile import SimpleUploadedFile

        bad = SimpleUploadedFile("notes.txt", b"hello", content_type="text/plain")
        resp = auth_client(officer_user).post(
            _images_url(draft_report.id), {"image": bad}, format="multipart"
        )
        assert resp.status_code == 400

    def test_oversize_image_rejected(self, auth_client, officer_user, draft_report, settings):
        # Force the limit low so we don't have to build a 5MB file.
        import apps.reports.serializers as ser

        original = ser.MAX_IMAGE_SIZE
        ser.MAX_IMAGE_SIZE = 10  # bytes
        try:
            resp = auth_client(officer_user).post(
                _images_url(draft_report.id), {"image": make_image_file()}, format="multipart"
            )
            assert resp.status_code == 400
        finally:
            ser.MAX_IMAGE_SIZE = original

    def test_cannot_upload_to_approved_report(self, auth_client, officer_user, manager_user, draft_report):
        auth_client(officer_user).post(f"/api/v1/reports/{draft_report.id}/submit/")
        auth_client(manager_user).post(f"/api/v1/reports/{draft_report.id}/approve/")
        resp = auth_client(officer_user).post(
            _images_url(draft_report.id), {"image": make_image_file()}, format="multipart"
        )
        assert resp.status_code == 400


class TestAccess:
    def test_image_nested_in_report_serializer(self, auth_client, officer_user, draft_report):
        auth_client(officer_user).post(
            _images_url(draft_report.id), {"image": make_image_file()}, format="multipart"
        )
        detail = auth_client(officer_user).get(f"/api/v1/reports/{draft_report.id}/")
        assert len(detail.data["images"]) == 1

    def test_outsider_officer_cannot_upload(self, auth_client, other_ngo, draft_report):
        from apps.accounts.models import Role, User

        outsider = User.objects.create_user(
            "out@x.org", "Pw!12345", first_name="Out", last_name="", role=Role.OFFICER, ngo=other_ngo
        )
        resp = auth_client(outsider).post(
            _images_url(draft_report.id), {"image": make_image_file()}, format="multipart"
        )
        assert resp.status_code in (403, 404)

"""Fixtures shared by report tests."""
import io

import pytest
from PIL import Image

from apps.projects.models import Project, ProjectAssignment
from apps.reports.models import Report


@pytest.fixture
def assigned_project(ngo, officer_user):
    project = Project.objects.create(project_name="Field Survey", ngo=ngo)
    ProjectAssignment.objects.create(project=project, user=officer_user, role="officer")
    return project


@pytest.fixture
def draft_report(assigned_project, officer_user):
    return Report.objects.create(
        project=assigned_project,
        officer=officer_user,
        title="Day 1",
        report_type="daily",
        status=Report.Status.DRAFT,
    )


def make_image_file(name="photo.png", size_px=(16, 16), fmt="PNG"):
    """Return an in-memory uploadable image file."""
    from django.core.files.uploadedfile import SimpleUploadedFile

    buffer = io.BytesIO()
    Image.new("RGB", size_px, (120, 80, 200)).save(buffer, format=fmt)
    buffer.seek(0)
    content_type = f"image/{fmt.lower()}"
    return SimpleUploadedFile(name, buffer.read(), content_type=content_type)

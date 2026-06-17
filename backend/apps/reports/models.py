"""Field reports and their attached images."""
from django.conf import settings
from django.db import models


class Report(models.Model):
    class ReportType(models.TextChoices):
        DAILY = "daily", "Daily"
        WEEKLY = "weekly", "Weekly"
        MONTHLY = "monthly", "Monthly"

    class Status(models.TextChoices):
        DRAFT = "draft", "Draft"
        SUBMITTED = "submitted", "Submitted"
        APPROVED = "approved", "Approved"

    project = models.ForeignKey(
        "projects.Project",
        on_delete=models.CASCADE,
        related_name="reports",
        db_column="project_id",
    )
    # PROTECT: a report's authoring officer is preserved even if the officer is
    # later removed from the project. Users are soft-deleted, never hard
    # deleted, so this FK is never orphaned.
    officer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="reports",
        db_column="officer_id",
    )
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    gps_latitude = models.DecimalField(
        max_digits=10, decimal_places=7, null=True, blank=True
    )
    gps_longitude = models.DecimalField(
        max_digits=10, decimal_places=7, null=True, blank=True
    )
    report_type = models.CharField(max_length=10, choices=ReportType.choices)
    status = models.CharField(
        max_length=10, choices=Status.choices, default=Status.DRAFT
    )
    # Null while the report is a draft; set when it transitions to submitted.
    date_submitted = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "reports"
        ordering = ["-date_submitted", "-id"]

    def __str__(self):
        return self.title


class ReportImage(models.Model):
    """One of potentially many photos attached to a report."""

    report = models.ForeignKey(
        Report,
        on_delete=models.CASCADE,
        related_name="images",
        db_column="report_id",
    )
    # Field name kept pythonic; DB column matches the schema's `image_url`.
    image = models.ImageField(upload_to="report_images/", db_column="image_url")
    caption = models.CharField(max_length=255, blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "report_images"
        ordering = ["uploaded_at"]

    def __str__(self):
        return f"image for report {self.report_id}"

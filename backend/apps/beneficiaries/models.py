from django.conf import settings
from django.db import models

from core.utils import compute_age


class Beneficiary(models.Model):
    class Gender(models.TextChoices):
        MALE = "male", "Male"
        FEMALE = "female", "Female"
        OTHER = "other", "Other"

    class ApprovalStatus(models.TextChoices):
        PENDING = "pending", "Pending"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    name = models.CharField(max_length=255)
    gender = models.CharField(max_length=10, choices=Gender.choices)
    # Store date_of_birth; age is computed in the serializer (never stored).
    date_of_birth = models.DateField(null=True, blank=True)
    phone = models.CharField(max_length=30, blank=True)
    # Kenya administrative hierarchy (eCitizen-style). `location` here is
    # the administrative unit below ward, NOT the old free-text column —
    # the joined display string is the `full_location` property below.
    country = models.CharField(max_length=100, default="Kenya")
    county = models.CharField(max_length=100, blank=True)
    constituency = models.CharField(max_length=100, blank=True)
    ward = models.CharField(max_length=100, blank=True)
    location = models.CharField(
        max_length=255, blank=True, help_text="Location within ward"
    )
    sub_location = models.CharField(
        max_length=255, blank=True, help_text="Sub-location within location"
    )
    village = models.CharField(
        max_length=255, blank=True, help_text="Village (free text)"
    )
    project = models.ForeignKey(
        "projects.Project",
        on_delete=models.CASCADE,
        related_name="beneficiaries",
        db_column="project_id",
    )

    # ── Identity / verification ───────────────────────────────────────────
    # Optional at registration (officers often have no camera); required only
    # to APPROVE — enforced in the approve action, not on the model.
    photo = models.ImageField(
        upload_to="beneficiary_photos/", null=True, blank=True
    )
    # NO uniqueness: minors legitimately share the blank value and lack IDs.
    national_id = models.CharField(max_length=20, blank=True)
    guardian_name = models.CharField(max_length=255, blank=True)
    guardian_phone = models.CharField(max_length=30, blank=True)
    postal_address = models.CharField(max_length=255, blank=True)
    # Kenya Data Protection Act 2019: consent must be recorded to register.
    consent_given = models.BooleanField(default=False)

    # ── Approval workflow ─────────────────────────────────────────────────
    approval_status = models.CharField(
        max_length=10,
        choices=ApprovalStatus.choices,
        default=ApprovalStatus.PENDING,
    )
    # SET_NULL: audit links survive a reviewer's later soft-delete/removal.
    approved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="approved_beneficiaries",
    )
    approved_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.TextField(blank=True)
    registered_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="registered_beneficiaries",
    )

    # Soft-delete flag — beneficiaries are never hard deleted.
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "beneficiaries"
        ordering = ["name"]
        verbose_name_plural = "beneficiaries"

    def __str__(self):
        return self.name

    def age_at_registration(self):
        """Age in whole years on the registration date, or None without a DOB.

        The age-conditional rules (ID/guardian requirements) are frozen at the
        registration date — measured against ``created_at`` for saved records,
        or today for one being registered now — so someone who later turns 18
        never becomes retroactively invalid.
        """
        if not self.date_of_birth:
            return None
        reference = self.created_at.date() if self.created_at else None
        return compute_age(self.date_of_birth, reference)

    @property
    def full_location(self):
        """Joined address string, most specific part first."""
        parts = filter(
            None,
            [self.village, self.sub_location, self.location, self.ward,
             self.constituency, self.county, self.country],
        )
        return ", ".join(parts)

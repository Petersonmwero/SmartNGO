from django.db import models


class Beneficiary(models.Model):
    class Gender(models.TextChoices):
        MALE = "male", "Male"
        FEMALE = "female", "Female"
        OTHER = "other", "Other"

    name = models.CharField(max_length=255)
    gender = models.CharField(max_length=10, choices=Gender.choices)
    # Store date_of_birth; age is computed in the serializer (never stored).
    date_of_birth = models.DateField(null=True, blank=True)
    phone = models.CharField(max_length=30, blank=True)
    # Kenya administrative hierarchy (eCitizen-style), replacing the old
    # free-text `location` column. `location` lives on as a property below.
    country = models.CharField(max_length=100, default="Kenya")
    county = models.CharField(max_length=100, blank=True)
    constituency = models.CharField(max_length=100, blank=True)
    ward = models.CharField(max_length=100, blank=True)
    village = models.CharField(
        max_length=255, blank=True, help_text="Village or sub-location"
    )
    project = models.ForeignKey(
        "projects.Project",
        on_delete=models.CASCADE,
        related_name="beneficiaries",
        db_column="project_id",
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

    @property
    def location(self):
        """Backwards-compatible joined address, most specific part first."""
        parts = filter(
            None,
            [self.village, self.ward, self.constituency, self.county,
             self.country],
        )
        return ", ".join(parts)

from django.db import models


class Indicator(models.Model):
    """A measurable KPI for a project (target vs. current value)."""

    project = models.ForeignKey(
        "projects.Project",
        on_delete=models.CASCADE,
        related_name="indicators",
        db_column="project_id",
    )
    indicator_name = models.CharField(max_length=255)
    target_value = models.DecimalField(max_digits=15, decimal_places=2)
    current_value = models.DecimalField(max_digits=15, decimal_places=2, default=0)
    unit = models.CharField(max_length=50, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "indicators"
        ordering = ["-created_at"]

    def __str__(self):
        return self.indicator_name

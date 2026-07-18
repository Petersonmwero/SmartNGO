"""Projects, their officer/manager assignments, phases, and milestones."""
from datetime import date
from decimal import Decimal

from django.conf import settings
from django.db import models


class Project(models.Model):
    class Status(models.TextChoices):
        PLANNING = "planning", "Planning"
        ACTIVE = "active", "Active"
        ON_HOLD = "on_hold", "On Hold"
        COMPLETED = "completed", "Completed"
        CANCELLED = "cancelled", "Cancelled"

    # Weighted Composite Progress Model (Earned Value Management, per PMBOK).
    # Physical delivery carries the highest weight because donors care most
    # about deliverables, not money consumed or calendar time elapsed.
    FINANCIAL_WEIGHT = Decimal("0.30")
    PHYSICAL_WEIGHT = Decimal("0.50")
    TIME_WEIGHT = Decimal("0.20")

    project_name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    budget = models.DecimalField(max_digits=15, decimal_places=2, default=0)
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PLANNING
    )
    ngo = models.ForeignKey(
        "ngos.NGO",
        on_delete=models.PROTECT,
        related_name="projects",
        db_column="ngo_id",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "projects"
        ordering = ["-created_at"]

    def __str__(self):
        return self.project_name

    # ── Weighted Composite Progress engine (EVM) ─────────────────────────
    @property
    def total_spent(self):
        """Sum of spent_budget across all phases, as a Decimal."""
        return sum((p.spent_budget for p in self.phases.all()), Decimal("0"))

    @property
    def budget_remaining(self):
        """Unspent budget (may be negative if phases overran)."""
        return self.budget - self.total_spent

    @property
    def financial_progress(self):
        """Percentage of the total budget spent across phases (0-100)."""
        if self.budget <= 0:
            return 0.0
        return min(round(float(self.total_spent / self.budget * 100), 1), 100.0)

    @property
    def physical_progress(self):
        """Weight-adjusted percentage of milestones completed (0-100)."""
        milestones = list(self.milestones.all())
        if not milestones:
            return 0.0
        total_weight = sum(m.weight for m in milestones)
        if total_weight == 0:
            return 0.0
        completed_weight = sum(
            m.weight for m in milestones if m.status == Milestone.Status.COMPLETED
        )
        return round(completed_weight / total_weight * 100, 1)

    @property
    def time_progress(self):
        """Percentage of the project timeline elapsed (0-100)."""
        if self.start_date is None or self.end_date is None:
            return 0.0
        today = date.today()
        if today <= self.start_date:
            return 0.0
        if today >= self.end_date:
            return 100.0
        total_days = (self.end_date - self.start_date).days
        if total_days <= 0:
            return 100.0
        elapsed = (today - self.start_date).days
        return round(elapsed / total_days * 100, 1)

    @property
    def progress_percentage(self):
        """Weighted composite progress (EVM-based).

        Progress = Financial x 30% + Physical x 50% + Time x 20%
        """
        composite = (
            Decimal(str(self.financial_progress)) * self.FINANCIAL_WEIGHT
            + Decimal(str(self.physical_progress)) * self.PHYSICAL_WEIGHT
            + Decimal(str(self.time_progress)) * self.TIME_WEIGHT
        )
        return min(round(float(composite), 1), 100.0)

    @property
    def cost_performance_index(self):
        """CPI = physical / financial progress.

        > 1.0 means delivering more than spending; < 1.0 means spending
        faster than delivering. None until any money is spent.
        """
        if self.financial_progress <= 0:
            return None
        return round(self.physical_progress / self.financial_progress, 2)

    @property
    def schedule_performance_index(self):
        """SPI = physical / time progress.

        > 1.0 means ahead of schedule; < 1.0 behind. None before the
        project timeline starts.
        """
        if self.time_progress <= 0:
            return None
        return round(self.physical_progress / self.time_progress, 2)

    @property
    def health_status(self):
        """Overall project health derived from CPI/SPI thresholds."""
        cpi = self.cost_performance_index
        spi = self.schedule_performance_index
        if cpi is None or spi is None:
            return "not_started"
        if cpi >= 0.95 and spi >= 0.95:
            return "healthy"
        if cpi >= 0.8 and spi >= 0.8:
            return "at_risk"
        return "critical"


class ProjectPhase(models.Model):
    """A budgeted stage of a project (planning, implementation, ...).

    Phase spending feeds the project's financial-progress dimension in the
    weighted composite progress model.
    """

    class PhaseType(models.TextChoices):
        PLANNING = "planning", "Planning"
        IMPLEMENTATION = "implementation", "Implementation"
        MONITORING = "monitoring", "Monitoring & Evaluation"
        CLOSEOUT = "closeout", "Closeout"

    class Status(models.TextChoices):
        NOT_STARTED = "not_started", "Not Started"
        IN_PROGRESS = "in_progress", "In Progress"
        COMPLETED = "completed", "Completed"

    project = models.ForeignKey(
        Project,
        on_delete=models.CASCADE,
        related_name="phases",
        db_column="project_id",
    )
    phase_name = models.CharField(max_length=255)
    phase_type = models.CharField(max_length=50, choices=PhaseType.choices)
    allocated_budget = models.DecimalField(max_digits=15, decimal_places=2)
    spent_budget = models.DecimalField(max_digits=15, decimal_places=2, default=0)
    start_date = models.DateField()
    end_date = models.DateField()
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.NOT_STARTED
    )
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "project_phases"
        ordering = ["start_date"]

    def __str__(self):
        return f"{self.phase_name} ({self.project_id})"

    @property
    def utilization_percentage(self):
        """Spent as a percentage of allocated budget, capped at 100."""
        if self.allocated_budget <= 0:
            return 0
        return min(
            round(float(self.spent_budget / self.allocated_budget) * 100, 1), 100
        )


class ProjectAssignment(models.Model):
    """Links a user to a project as either its manager or a field officer."""

    class Role(models.TextChoices):
        MANAGER = "manager", "Manager"
        OFFICER = "officer", "Officer"

    project = models.ForeignKey(
        Project,
        on_delete=models.CASCADE,
        related_name="assignments",
        db_column="project_id",
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="project_assignments",
        db_column="user_id",
    )
    role = models.CharField(max_length=20, choices=Role.choices)
    assigned_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "project_assignments"
        constraints = [
            models.UniqueConstraint(
                fields=["project", "user"],
                name="uniq_project_user_assignment",
            )
        ]
        ordering = ["-assigned_at"]

    def __str__(self):
        return f"{self.user_id} -> {self.project_id} ({self.role})"


class Milestone(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        COMPLETED = "completed", "Completed"
        OVERDUE = "overdue", "Overdue"

    project = models.ForeignKey(
        Project,
        on_delete=models.CASCADE,
        related_name="milestones",
        db_column="project_id",
    )
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    due_date = models.DateField(null=True, blank=True)
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING
    )
    weight = models.PositiveIntegerField(
        default=1,
        help_text=(
            "Relative importance weight (e.g. major milestone = 5, minor = 1). "
            "Used in physical progress calculation."
        ),
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "milestones"
        ordering = ["due_date"]

    def __str__(self):
        return self.title

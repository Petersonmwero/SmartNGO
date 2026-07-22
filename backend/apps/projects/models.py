"""Projects, their officer/manager assignments, phases, and milestones."""
from datetime import date
from decimal import Decimal
from typing import Optional

from django.conf import settings
from django.db import models


def _elapsed_fraction(start, end, today):
    """Fraction of the [start, end] window elapsed as of today, clamped 0-1.

    The `today >= end` check comes first so a zero-length window in the
    past counts as fully elapsed and the division below can never see a
    zero-day span.
    """
    if today >= end:
        return 1.0
    if today <= start:
        return 0.0
    return (today - start).days / (end - start).days


class Project(models.Model):
    class Status(models.TextChoices):
        PLANNING = "planning", "Planning"
        ACTIVE = "active", "Active"
        ON_HOLD = "on_hold", "On Hold"
        COMPLETED = "completed", "Completed"
        CANCELLED = "cancelled", "Cancelled"

    # Weighted Composite Progress Model built on Earned Value Management.
    # CPI = EV/AC and SPI = EV/PV follow PMBOK; the headline composite is a
    # weighted blend of the three dimensions (a reporting choice, not a
    # PMBOK formula). Physical delivery carries the highest weight because
    # donors care most about deliverables, not money consumed or calendar
    # time elapsed.
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
    def reported_spend(self):
        """Spend posted by approved reports, across every phase."""
        return sum((p.reported_spend for p in self.phases.all()), Decimal("0"))

    @property
    def beneficiaries_reached(self):
        """People reached according to approved reports.

        A headcount of reporting, not of distinct individuals — the same
        person attending two activities is counted by both reports.
        """
        return sum(
            r.beneficiaries_reached
            for r in self.reports.all()
            if r.status == "approved" and r.posted_at is not None
        )

    @property
    def cost_per_beneficiary(self) -> Optional[float]:
        """Total spend divided by people reached; None when none reached."""
        reached = self.beneficiaries_reached
        if reached <= 0:
            return None
        return round(float(self.total_spent) / reached, 2)

    @property
    def budget_remaining(self):
        """Unspent budget (may be negative if phases overran)."""
        return self.budget - self.total_spent

    @property
    def financial_progress(self) -> float:
        """Percentage of the total budget spent across phases (0-100)."""
        if self.budget <= 0:
            return 0.0
        return min(round(float(self.total_spent / self.budget * 100), 1), 100.0)

    @property
    def physical_progress(self) -> float:
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
    def time_progress(self) -> float:
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
    def progress_percentage(self) -> float:
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
    def cost_performance_index(self) -> Optional[float]:
        """CPI = physical / financial progress.

        > 1.0 means delivering more than spending; < 1.0 means spending
        faster than delivering. None until any money is spent.
        """
        if self.financial_progress <= 0:
            return None
        return round(self.physical_progress / self.financial_progress, 2)

    @property
    def planned_value_progress(self) -> float:
        """Planned Value (PV) as a percentage of the project budget (0-100).

        PV per PMBOK: the budgeted cost of the work *scheduled* to be done
        by today. Computed from the phase baseline — each phase contributes
        its allocated budget multiplied by the elapsed fraction of that
        phase's own timeline — so a front-loaded plan yields a front-loaded
        PV curve instead of a straight line.

        Degenerate case (documented): a project with no phase plan, or a
        zero/negative budget, falls back to linear accrual over the project
        timeline, i.e. time_progress. That linear assumption was the entire
        old SPI model; here it is only the fallback.
        """
        phases = list(self.phases.all())
        if not phases or self.budget <= 0:
            return self.time_progress
        today = date.today()
        planned = sum(
            float(phase.allocated_budget)
            * _elapsed_fraction(phase.start_date, phase.end_date, today)
            for phase in phases
        )
        return min(round(planned / float(self.budget) * 100, 1), 100.0)

    @property
    def schedule_performance_index(self) -> Optional[float]:
        """SPI = EV / PV (Earned Value over Planned Value, per PMBOK).

        EV is physical progress expressed against the budget; PV accrues
        per the phase baseline (see planned_value_progress). Because both
        are percentages of the same budget, the budget cancels and
        SPI = physical_progress / planned_value_progress.

        > 1.0 means ahead of the plan; < 1.0 behind. None before any work
        was planned to have started.
        """
        pv = self.planned_value_progress
        if pv <= 0:
            return None
        return round(self.physical_progress / pv, 2)

    @property
    def health_status(self) -> str:
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
    # Renamed from spent_budget; db_column keeps the existing column so no
    # data moves. Actual spend is now this baseline plus the approved-report
    # ledger — see the spent_budget property below.
    opening_spend = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        default=0,
        db_column="spent_budget",
        help_text=(
            "Expenditure recorded at baseline, before report-based tracking. "
            "Actual spend = this plus approved report spend."
        ),
    )
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
    def reported_spend(self):
        """Spend from approved reports linked to this phase.

        Filtered in Python rather than by queryset so a prefetched
        `phases__reports` serves every phase from one query.
        """
        return sum(
            (
                r.amount_spent
                for r in self.reports.all()
                if r.status == "approved" and r.posted_at is not None
            ),
            Decimal("0"),
        )

    @property
    def spent_budget(self):
        """Actual spend: baseline opening figure + approved report ledger."""
        return self.opening_spend + self.reported_spend

    @property
    def utilization_percentage(self) -> float:
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
    # Set when an approved report completed this milestone. Null for
    # milestones ticked off by hand, which un-approving a report must not
    # revert.
    completed_by_report = models.ForeignKey(
        "reports.Report",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="completed_milestones",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "milestones"
        ordering = ["due_date"]

    def __str__(self):
        return self.title

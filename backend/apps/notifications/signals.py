"""Signal handlers that emit notifications on key domain events.

Connected in NotificationsConfig.ready(). Date-based reminders (e.g. milestone
due in 3 days) cannot be driven by signals — see the `notify_due_milestones`
management command for those.
"""
from django.db.models.signals import post_delete, post_save, pre_save
from django.dispatch import receiver

from apps.beneficiaries.models import Beneficiary
from apps.projects.models import ProjectAssignment
from apps.reports.models import Report

from .services import notify, notify_users


@receiver(post_save, sender=ProjectAssignment)
def notify_on_assignment(sender, instance, created, **kwargs):
    if created:
        notify(
            instance.user,
            "Added to a project",
            f"You have been assigned to '{instance.project.project_name}' "
            f"as {instance.get_role_display().lower()}.",
        )


@receiver(post_delete, sender=ProjectAssignment)
def notify_on_unassignment(sender, instance, **kwargs):
    notify(
        instance.user,
        "Removed from a project",
        f"You have been removed from '{instance.project.project_name}'.",
    )


@receiver(pre_save, sender=Report)
def _stash_report_status(sender, instance, **kwargs):
    """Record the previous status so post_save can detect a transition."""
    if instance.pk:
        instance._old_status = (
            sender.objects.filter(pk=instance.pk)
            .values_list("status", flat=True)
            .first()
        )
    else:
        instance._old_status = None


@receiver(post_save, sender=Beneficiary)
def notify_on_beneficiary_registered(sender, instance, created, **kwargs):
    """Notify the project's manager(s) that a beneficiary awaits approval."""
    if not created:
        return
    managers = {
        assignment.user
        for assignment in instance.project.assignments.select_related("user").filter(
            role=ProjectAssignment.Role.MANAGER
        )
    }
    if managers:
        notify_users(
            managers,
            "Beneficiary awaiting approval",
            f"'{instance.name}' was registered on "
            f"'{instance.project.project_name}' and needs approval.",
        )


@receiver(post_save, sender=Report)
def notify_on_report_approved(sender, instance, created, **kwargs):
    if created:
        return
    old_status = getattr(instance, "_old_status", None)
    if old_status != Report.Status.APPROVED and instance.status == Report.Status.APPROVED:
        notify(
            instance.officer,
            "Report approved",
            f"Your report '{instance.title}' has been approved.",
        )

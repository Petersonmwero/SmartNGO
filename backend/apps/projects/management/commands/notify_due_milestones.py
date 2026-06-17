"""
Daily cron job: notify project teams of milestones due soon, and flag overdue
milestones.

Run daily, e.g. crontab:
    0 7 * * *  cd /path/to/backend && venv/bin/python manage.py notify_due_milestones

Signals cannot fire on a future date, so this date-based reminder is a
management command instead.
"""
from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.accounts.models import User
from apps.notifications.services import notify
from apps.projects.models import Milestone


class Command(BaseCommand):
    help = "Notify teams of milestones due in N days and mark overdue milestones."

    def add_arguments(self, parser):
        parser.add_argument(
            "--days",
            type=int,
            default=3,
            help="Days ahead to look for due milestones (default: 3).",
        )

    def handle(self, *args, **options):
        days = options["days"]
        today = timezone.localdate()
        target = today + timedelta(days=days)

        due_soon = Milestone.objects.filter(
            status=Milestone.Status.PENDING, due_date=target
        ).select_related("project")

        notified = 0
        for milestone in due_soon:
            team = User.objects.filter(
                project_assignments__project=milestone.project, is_active=True
            ).distinct()
            for user in team:
                notify(
                    user,
                    "Milestone due soon",
                    f"Milestone '{milestone.title}' for project "
                    f"'{milestone.project.project_name}' is due on {milestone.due_date}.",
                )
                notified += 1

        # Flag any pending milestones whose due date has already passed.
        overdue = Milestone.objects.filter(
            status=Milestone.Status.PENDING, due_date__lt=today
        ).update(status=Milestone.Status.OVERDUE)

        self.stdout.write(
            self.style.SUCCESS(
                f"Sent {notified} due-soon notification(s); "
                f"marked {overdue} milestone(s) overdue."
            )
        )

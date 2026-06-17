"""Helpers for creating notifications (used by signals and management commands)."""
from .models import Notification


def notify(user, title, message=""):
    return Notification.objects.create(user=user, title=title, message=message)


def notify_users(users, title, message=""):
    """Bulk-create one notification per user. Returns the created objects."""
    objs = [Notification(user=u, title=title, message=message) for u in users]
    return Notification.objects.bulk_create(objs)

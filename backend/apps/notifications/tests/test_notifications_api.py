"""Tests for the notifications API (list own, mark read, delete, badge filter)."""
import pytest

from apps.notifications.models import Notification

NOTIFS = "/api/v1/notifications/"

pytestmark = pytest.mark.django_db


class TestNotificationsApi:
    def test_user_sees_only_own_notifications(self, auth_client, officer_user, manager_user):
        Notification.objects.create(user=officer_user, title="mine")
        Notification.objects.create(user=manager_user, title="theirs")
        resp = auth_client(officer_user).get(NOTIFS)
        assert resp.status_code == 200
        assert {n["title"] for n in resp.data["results"]} == {"mine"}

    def test_unread_filter_for_badge(self, auth_client, officer_user):
        Notification.objects.create(user=officer_user, title="a", status="unread")
        Notification.objects.create(user=officer_user, title="b", status="read")
        resp = auth_client(officer_user).get(NOTIFS, {"status": "unread"})
        assert resp.data["count"] == 1

    def test_mark_read(self, auth_client, officer_user):
        n = Notification.objects.create(user=officer_user, title="a", status="unread")
        resp = auth_client(officer_user).patch(
            f"{NOTIFS}{n.id}/", {"status": "read"}, format="json"
        )
        assert resp.status_code == 200
        n.refresh_from_db()
        assert n.status == "read"

    def test_delete(self, auth_client, officer_user):
        n = Notification.objects.create(user=officer_user, title="a")
        resp = auth_client(officer_user).delete(f"{NOTIFS}{n.id}/")
        assert resp.status_code == 204
        assert not Notification.objects.filter(id=n.id).exists()

    def test_cannot_touch_others_notification(self, auth_client, officer_user, manager_user):
        n = Notification.objects.create(user=manager_user, title="theirs")
        # Out of the officer's queryset -> 404.
        assert auth_client(officer_user).patch(
            f"{NOTIFS}{n.id}/", {"status": "read"}, format="json"
        ).status_code == 404

    def test_put_not_allowed(self, auth_client, officer_user):
        n = Notification.objects.create(user=officer_user, title="a")
        assert auth_client(officer_user).put(
            f"{NOTIFS}{n.id}/", {"status": "read"}, format="json"
        ).status_code == 405

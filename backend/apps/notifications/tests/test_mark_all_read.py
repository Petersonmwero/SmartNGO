"""Tests for POST /api/v1/notifications/mark-all-read/."""
import pytest

from apps.notifications.models import Notification

MARK_ALL = "/api/v1/notifications/mark-all-read/"
NOTIFS = "/api/v1/notifications/"

pytestmark = pytest.mark.django_db


class TestMarkAllRead:
    def test_marks_all_unread_for_current_user(self, auth_client, officer_user):
        Notification.objects.create(user=officer_user, title="a", status="unread")
        Notification.objects.create(user=officer_user, title="b", status="unread")
        Notification.objects.create(user=officer_user, title="c", status="read")

        resp = auth_client(officer_user).post(MARK_ALL)
        assert resp.status_code == 200
        assert resp.data["status"] == "success"
        assert resp.data["data"]["updated"] == 2

        remaining = Notification.objects.filter(user=officer_user, status="unread").count()
        assert remaining == 0

    def test_does_not_affect_other_users_notifications(
        self, auth_client, officer_user, manager_user
    ):
        Notification.objects.create(user=manager_user, title="theirs", status="unread")
        auth_client(officer_user).post(MARK_ALL)

        # Manager's notification must remain unread.
        assert Notification.objects.filter(user=manager_user, status="unread").count() == 1

    def test_returns_zero_when_nothing_to_mark(self, auth_client, officer_user):
        resp = auth_client(officer_user).post(MARK_ALL)
        assert resp.status_code == 200
        assert resp.data["data"]["updated"] == 0

    def test_unauthenticated_returns_401(self, api_client):
        resp = api_client.post(MARK_ALL)
        assert resp.status_code == 401

    def test_get_not_allowed_on_action(self, auth_client, officer_user):
        # The action only accepts POST; GET should 405.
        resp = auth_client(officer_user).get(MARK_ALL)
        assert resp.status_code == 405

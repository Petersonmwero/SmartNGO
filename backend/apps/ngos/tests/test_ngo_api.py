"""Tests for the admin-only NGO CRUD endpoints."""
import pytest

from apps.ngos.models import NGO

NGOS = "/api/v1/ngos/"

pytestmark = pytest.mark.django_db


def _payload(**over):
    data = {
        "name": "Helping Hands",
        "registration_no": "REG-1234",
        "description": "A test NGO",
        "address": "Eldoret",
        "contact": "0700111222",
    }
    data.update(over)
    return data


class TestNGOPermissions:
    def test_admin_can_list(self, auth_client, admin_user):
        resp = auth_client(admin_user).get(NGOS)
        assert resp.status_code == 200
        # Paginated envelope.
        assert set(resp.data) == {"count", "next", "previous", "results"}

    @pytest.mark.parametrize("fixture", ["manager_user", "officer_user", "donor_user"])
    def test_non_admin_forbidden(self, auth_client, request, fixture):
        user = request.getfixturevalue(fixture)
        assert auth_client(user).get(NGOS).status_code == 403
        assert auth_client(user).post(NGOS, _payload(), format="json").status_code == 403

    def test_anonymous_unauthorized(self, api_client):
        assert api_client.get(NGOS).status_code == 401


class TestNGOCrud:
    def test_admin_full_crud(self, auth_client, admin_user):
        client = auth_client(admin_user)

        created = client.post(NGOS, _payload(), format="json")
        assert created.status_code == 201
        ngo_id = created.data["id"]

        assert client.get(f"{NGOS}{ngo_id}/").status_code == 200

        patched = client.patch(f"{NGOS}{ngo_id}/", {"contact": "0799"}, format="json")
        assert patched.status_code == 200
        assert patched.data["contact"] == "0799"

        assert client.delete(f"{NGOS}{ngo_id}/").status_code == 204
        assert not NGO.objects.filter(id=ngo_id).exists()

    def test_duplicate_registration_no_rejected(self, auth_client, admin_user):
        client = auth_client(admin_user)
        client.post(NGOS, _payload(registration_no="DUP-1"), format="json")
        dup = client.post(NGOS, _payload(name="Other", registration_no="DUP-1"), format="json")
        assert dup.status_code == 400
        assert set(dup.data) == {"error", "code"}

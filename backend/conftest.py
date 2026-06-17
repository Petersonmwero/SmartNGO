"""Shared pytest fixtures for the backend test suite.

Provides an API client, an NGO, and one authenticated user per role, plus an
``auth_client`` helper that returns an API client carrying a given user's
bearer token. Reused across all apps' tests (and by Phase 2 endpoints).
"""
import pytest
from django.core.cache import cache
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import Role, User
from apps.ngos.models import NGO

PASSWORD = "Pw!12345"


@pytest.fixture(autouse=True)
def _reset_throttle_cache():
    """DRF throttles persist counts in the cache; reset per test for isolation.

    (Dedicated throttling/rate-limit assertions belong in their own test that
    deliberately exhausts the limit.)
    """
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def ngo(db):
    # Seeded by the ngos 0002 data migration; get_or_create keeps tests robust.
    obj, _ = NGO.objects.get_or_create(
        registration_no="SYSTEM-0001", defaults={"name": "System NGO"}
    )
    return obj


@pytest.fixture
def other_ngo(db):
    return NGO.objects.create(name="Other NGO", registration_no="OTHER-0002")


def _make_user(ngo, role, email):
    return User.objects.create_user(
        email=email,
        password=PASSWORD,
        full_name=f"{role} user",
        role=role,
        ngo=ngo,
    )


@pytest.fixture
def admin_user(ngo):
    return _make_user(ngo, Role.ADMIN, "admin@test.org")


@pytest.fixture
def manager_user(ngo):
    return _make_user(ngo, Role.MANAGER, "manager@test.org")


@pytest.fixture
def officer_user(ngo):
    return _make_user(ngo, Role.OFFICER, "officer@test.org")


@pytest.fixture
def donor_user(ngo):
    return _make_user(ngo, Role.DONOR, "donor@test.org")


@pytest.fixture
def auth_client():
    """Return a callable: auth_client(user) -> APIClient authenticated as user."""

    def _login(user):
        client = APIClient()
        access = RefreshToken.for_user(user).access_token
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
        return client

    return _login

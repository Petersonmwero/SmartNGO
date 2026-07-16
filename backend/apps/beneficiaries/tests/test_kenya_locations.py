"""Tests for GET /api/v1/locations/kenya/ — cascading location reference data."""
import pytest

from apps.beneficiaries.kenya_locations import (
    CONSTITUENCY_WARDS,
    COUNTY_CONSTITUENCIES,
    KENYA_COUNTIES,
    LOCATION_SUBLOCATION,
    WARD_LOCATIONS,
)

LOCATIONS = "/api/v1/locations/kenya/"

pytestmark = pytest.mark.django_db


class TestKenyaLocationData:
    def test_all_47_counties_present(self):
        assert len(KENYA_COUNTIES) == 47
        assert len(set(KENYA_COUNTIES)) == 47

    def test_every_county_has_constituencies(self):
        for county in KENYA_COUNTIES:
            assert COUNTY_CONSTITUENCIES.get(county), (
                f"{county} has no constituencies"
            )

    def test_ward_keys_are_real_constituencies(self):
        all_constituencies = {
            c for lst in COUNTY_CONSTITUENCIES.values() for c in lst
        }
        for constituency in CONSTITUENCY_WARDS:
            assert constituency in all_constituencies, (
                f"Ward key {constituency!r} is not a known constituency"
            )

    def test_every_constituency_has_wards(self):
        # Full national coverage: all 290 constituencies resolve to a
        # non-empty ward list.
        for county, constituencies in COUNTY_CONSTITUENCIES.items():
            for constituency in constituencies:
                assert CONSTITUENCY_WARDS.get(constituency), (
                    f"{constituency} ({county}) has no wards"
                )

    def test_every_ward_has_locations(self):
        # Curated or generated "<ward> A/B" — the Location level is always
        # selectable.
        for constituency, wards in CONSTITUENCY_WARDS.items():
            for ward in wards:
                assert WARD_LOCATIONS.get(ward), (
                    f"Ward {ward} ({constituency}) has no locations"
                )

    def test_location_keys_are_real_wards(self):
        all_wards = {w for lst in CONSTITUENCY_WARDS.values() for w in lst}
        for ward in WARD_LOCATIONS:
            assert ward in all_wards, (
                f"Location key {ward!r} is not a known ward"
            )

    def test_sublocation_keys_are_real_locations(self):
        all_locations = {
            loc for lst in WARD_LOCATIONS.values() for loc in lst
        }
        for location in LOCATION_SUBLOCATION:
            assert location in all_locations, (
                f"Sub-location key {location!r} is not a known location"
            )


class TestKenyaLocationView:
    def test_counties_sorted(self, api_client):
        resp = api_client.get(LOCATIONS, {"counties": "true"})
        assert resp.status_code == 200
        assert resp.data["status"] == "success"
        assert len(resp.data["data"]) == 47
        assert resp.data["data"] == sorted(resp.data["data"])
        assert resp.data["data"][0] == "Baringo"

    def test_constituencies_for_county(self, api_client):
        resp = api_client.get(LOCATIONS, {"county": "Kisumu"})
        assert resp.status_code == 200
        assert "Kisumu East" in resp.data["data"]
        assert len(resp.data["data"]) == 7

    def test_wards_for_constituency(self, api_client):
        resp = api_client.get(LOCATIONS, {"constituency": "Westlands"})
        assert resp.status_code == 200
        assert "Kitisuru" in resp.data["data"]

    def test_locations_for_ward(self, api_client):
        resp = api_client.get(LOCATIONS, {"ward": "Lodwar Township"})
        assert resp.status_code == 200
        assert "Lodwar" in resp.data["data"]

    def test_sublocations_for_location(self, api_client):
        resp = api_client.get(LOCATIONS, {"location": "Lodwar"})
        assert resp.status_code == 200
        assert "Lodwar A" in resp.data["data"]

    def test_unknown_names_return_empty_list(self, api_client):
        for params in (
            {"county": "Atlantis"},
            {"constituency": "Atlantis"},
            {"ward": "Atlantis"},
            {"location": "Atlantis"},
        ):
            resp = api_client.get(LOCATIONS, params)
            assert resp.status_code == 200
            assert resp.data["data"] == []

    def test_missing_parameter_is_400(self, api_client):
        resp = api_client.get(LOCATIONS)
        assert resp.status_code == 400
        assert resp.data["status"] == "error"

    def test_no_auth_required(self, api_client):
        # Public reference data — anonymous client must succeed.
        resp = api_client.get(LOCATIONS, {"counties": "1"})
        assert resp.status_code == 200

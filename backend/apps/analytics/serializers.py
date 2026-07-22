"""Response shapes for the analytics endpoints.

Declared so drf-spectacular can document them rather than falling back to a
guess — these are read-only projections, never inputs.
"""
from rest_framework import serializers


class MonthlyReportPointSerializer(serializers.Serializer):
    """One month in the reporting series."""

    year = serializers.IntegerField()
    month = serializers.IntegerField()
    # "Jul 2026" — precomputed so every client labels axes identically.
    label = serializers.CharField()
    submitted = serializers.IntegerField()
    approved = serializers.IntegerField()
    beneficiaries_reached = serializers.IntegerField()
    amount_spent = serializers.DecimalField(max_digits=15, decimal_places=2)


class ReportSeriesSerializer(serializers.Serializer):
    """A contiguous run of months, oldest first."""

    months = serializers.IntegerField()
    series = MonthlyReportPointSerializer(many=True)


class _ProjectStatusCountsSerializer(serializers.Serializer):
    """Project counts broken down by status."""

    planning = serializers.IntegerField()
    active = serializers.IntegerField()
    on_hold = serializers.IntegerField()
    completed = serializers.IntegerField()
    cancelled = serializers.IntegerField()


class _DashboardProjectsSerializer(serializers.Serializer):
    total = serializers.IntegerField()
    by_status = _ProjectStatusCountsSerializer()


class _DashboardBeneficiariesSerializer(serializers.Serializer):
    total = serializers.IntegerField()


class _DashboardReportsSerializer(serializers.Serializer):
    draft = serializers.IntegerField()
    submitted = serializers.IntegerField()
    approved = serializers.IntegerField()


class _DashboardNotificationsSerializer(serializers.Serializer):
    unread = serializers.IntegerField()


class DashboardStatsSerializer(serializers.Serializer):
    """The `data` payload of the analytics dashboard endpoint (read-only)."""

    projects = _DashboardProjectsSerializer()
    beneficiaries = _DashboardBeneficiariesSerializer()
    reports = _DashboardReportsSerializer()
    notifications = _DashboardNotificationsSerializer()

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

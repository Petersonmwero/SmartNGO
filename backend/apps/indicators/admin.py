from django.contrib import admin

from .models import Indicator


@admin.register(Indicator)
class IndicatorAdmin(admin.ModelAdmin):
    list_display = ("id", "indicator_name", "project", "target_value", "current_value", "unit")
    search_fields = ("indicator_name",)

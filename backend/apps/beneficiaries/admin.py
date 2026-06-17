from django.contrib import admin

from .models import Beneficiary


@admin.register(Beneficiary)
class BeneficiaryAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "gender", "date_of_birth", "project", "is_active")
    list_filter = ("gender", "is_active")
    search_fields = ("name",)

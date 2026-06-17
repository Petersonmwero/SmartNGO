from django.contrib import admin

from .models import NGO


@admin.register(NGO)
class NGOAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "registration_no", "contact", "created_at")
    search_fields = ("name", "registration_no")

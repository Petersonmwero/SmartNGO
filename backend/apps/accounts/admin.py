from django.contrib import admin

from .models import PasswordResetToken, User


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ("id", "full_name", "email", "role", "ngo", "is_active")
    list_filter = ("role", "is_active", "ngo")
    search_fields = ("full_name", "email")


@admin.register(PasswordResetToken)
class PasswordResetTokenAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "expires_at", "used", "created_at")
    list_filter = ("used",)

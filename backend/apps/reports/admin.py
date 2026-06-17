from django.contrib import admin

from .models import Report, ReportImage


class ReportImageInline(admin.TabularInline):
    model = ReportImage
    extra = 0


@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    list_display = ("id", "title", "project", "officer", "report_type", "status", "date_submitted")
    list_filter = ("status", "report_type")
    search_fields = ("title",)
    inlines = [ReportImageInline]


@admin.register(ReportImage)
class ReportImageAdmin(admin.ModelAdmin):
    list_display = ("id", "report", "caption", "uploaded_at")

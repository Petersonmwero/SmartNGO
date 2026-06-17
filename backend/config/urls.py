"""
Root URL configuration.

All API routes are versioned under /api/v1/. Resource routers and auth
endpoints are wired up in Phases 2 and 3; this file currently exposes the
admin site and the OpenAPI schema/docs scaffolding.
"""
from django.contrib import admin
from django.conf import settings
from django.conf.urls.static import static
from django.urls import include, path
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
)

api_v1 = [
    path("api/v1/auth/", include("apps.accounts.urls")),
    path("api/v1/", include("config.api_router")),
    path("api/v1/schema/", SpectacularAPIView.as_view(), name="schema"),
    path(
        "api/v1/docs/",
        SpectacularSwaggerView.as_view(url_name="schema"),
        name="swagger-ui",
    ),
]

urlpatterns = [
    path("admin/", admin.site.urls),
    *api_v1,
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

from rest_framework import mixins, viewsets
from rest_framework.permissions import IsAuthenticated

from .models import Notification
from .serializers import NotificationSerializer


class NotificationViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    """A user's own notifications: list, mark read (PATCH), delete.

    Filter unread for a badge count: ?status=unread.
    """

    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ["status"]
    # Notifications are system-created; expose PATCH but not PUT/POST.
    http_method_names = ["get", "patch", "delete", "head", "options"]
    queryset = Notification.objects.none()  # for schema model derivation

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Notification.objects.none()
        return Notification.objects.filter(user=self.request.user)

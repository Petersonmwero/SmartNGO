from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated

from core.responses import SuccessResponse

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
    Bulk-read via POST /notifications/mark-all-read/.
    """

    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]
    filterset_fields = ["status"]
    # "post" is included only for the mark-all-read action; the router does not
    # register a create route because CreateModelMixin is not mixed in.
    http_method_names = ["get", "patch", "post", "delete", "head", "options"]
    queryset = Notification.objects.none()  # for schema model derivation

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Notification.objects.none()
        return Notification.objects.filter(user=self.request.user).select_related("user")

    @action(detail=False, methods=["post"], url_path="mark-all-read")
    def mark_all_read(self, request):
        """Mark every unread notification for the current user as read."""
        updated = (
            self.get_queryset()
            .filter(status=Notification.Status.UNREAD)
            .update(status=Notification.Status.READ)
        )
        return SuccessResponse(
            data={"updated": updated},
            message=f"{updated} notification(s) marked as read.",
        )

from rest_framework import serializers

from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ["id", "title", "message", "status", "created_at"]
        # Only `status` is writable (to mark read/unread); the rest are
        # system-generated.
        read_only_fields = ["id", "title", "message", "created_at"]

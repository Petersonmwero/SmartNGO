"""Serializers for authentication and registration."""
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from apps.ngos.models import NGO

from .models import Role

User = get_user_model()

# Open self-registration is limited to non-privileged roles. Admin and manager
# accounts are provisioned by an administrator (Phase 2 users/ endpoint) so a
# stranger cannot self-elevate to a role with write access to projects.
SELF_REGISTRABLE_ROLES = {Role.OFFICER, Role.DONOR}


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True, min_length=8, style={"input_type": "password"}
    )
    ngo = serializers.PrimaryKeyRelatedField(queryset=NGO.objects.all())

    class Meta:
        model = User
        fields = ["id", "full_name", "email", "password", "role", "phone", "ngo"]
        read_only_fields = ["id"]

    def validate_password(self, value):
        validate_password(value)
        return value

    def validate_role(self, value):
        if value not in SELF_REGISTRABLE_ROLES:
            raise serializers.ValidationError(
                "Self-registration is only allowed for 'officer' or 'donor'. "
                "Admin and manager accounts are created by an administrator."
            )
        return value

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordResetConfirmSerializer(serializers.Serializer):
    token = serializers.CharField()
    new_password = serializers.CharField(
        write_only=True, min_length=8, style={"input_type": "password"}
    )

    def validate_new_password(self, value):
        validate_password(value)
        return value


class SmartTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Login serializer that embeds role/ngo claims and returns user info."""

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token["role"] = user.role
        token["ngo_id"] = user.ngo_id
        token["full_name"] = user.full_name
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        data["user"] = {
            "id": self.user.id,
            "full_name": self.user.full_name,
            "email": self.user.email,
            "role": self.user.role,
            "ngo_id": self.user.ngo_id,
        }
        return data

"""Serializers for authentication and registration."""
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from apps.ngos.models import NGO

from .models import Role

User = get_user_model()

# Admin accounts must be created by an existing admin via the /users/ endpoint
# or the Django admin panel. All other roles may self-register.
SELF_REGISTRABLE_ROLES = {Role.OFFICER, Role.DONOR, Role.MANAGER}


class _EmailNotVerifiedException(AuthenticationFailed):
    """Raised during login when the user's email has not been verified yet."""

    default_code = "EMAIL_NOT_VERIFIED"
    default_detail = (
        "Please verify your email before logging in. Check your inbox."
    )


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
                "Admin accounts cannot be created through self-registration. "
                "Please contact your organisation's administrator."
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


class UserProfileSerializer(serializers.ModelSerializer):
    """Read-only serializer for the /auth/me/ endpoint."""

    class Meta:
        model = User
        fields = ["id", "full_name", "email", "role", "phone", "ngo", "is_active", "created_at"]
        read_only_fields = ["id", "full_name", "email", "role", "phone", "ngo", "is_active", "created_at"]


class UserManagementSerializer(serializers.ModelSerializer):
    """Serializer for admin user management: list, create, toggle-active."""

    password = serializers.CharField(
        write_only=True,
        min_length=8,
        style={"input_type": "password"},
        required=False,
    )

    class Meta:
        model = User
        fields = ["id", "full_name", "email", "password", "role", "phone", "ngo", "is_active", "created_at"]
        read_only_fields = ["id", "created_at"]

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user

    def update(self, instance, validated_data):
        # Password changes go through the dedicated reset flow, not this serializer.
        validated_data.pop("password", None)
        return super().update(instance, validated_data)


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
        # Intercept before Django's authenticate() so we can surface a specific
        # error when the account exists but email verification is still pending.
        email = attrs.get(self.username_field, "")
        unverified = (
            User.objects.filter(email__iexact=email, is_active=False)
            .filter(email_verification_tokens__used=False)
            .exists()
        )
        if unverified:
            raise _EmailNotVerifiedException()

        data = super().validate(attrs)
        data["user"] = {
            "id": self.user.id,
            "full_name": self.user.full_name,
            "email": self.user.email,
            "role": self.user.role,
            "ngo_id": self.user.ngo_id,
        }
        return data

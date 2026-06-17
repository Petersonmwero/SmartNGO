"""Authentication endpoints: register, login, logout, token refresh, password reset."""
from django.contrib.auth import get_user_model
from django.core.mail import send_mail
from drf_spectacular.utils import OpenApiResponse, extend_schema, inline_serializer
from rest_framework import generics, serializers, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from .serializers import (
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    RegisterSerializer,
    SmartTokenObtainPairSerializer,
)
from .tokens import consume_reset_token, issue_reset_token

User = get_user_model()


class RegisterView(generics.CreateAPIView):
    """Create a new (officer/donor) account. Returns the created user."""

    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]


class LoginView(TokenObtainPairView):
    """Obtain an access + refresh token pair using email and password."""

    serializer_class = SmartTokenObtainPairSerializer


class LogoutView(APIView):
    """Blacklist the supplied refresh token so it can no longer be used."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        request=inline_serializer(
            "LogoutRequest", {"refresh": serializers.CharField()}
        ),
        responses={204: OpenApiResponse(description="Refresh token blacklisted.")},
    )
    def post(self, request):
        refresh = request.data.get("refresh")
        if not refresh:
            return Response(
                {"error": "A refresh token is required.", "code": "refresh_required"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            RefreshToken(refresh).blacklist()
        except TokenError:
            return Response(
                {"error": "Invalid or expired refresh token.", "code": "token_invalid"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)


class PasswordResetRequestView(APIView):
    """Email a single-use, 1-hour reset token to the account (if it exists).

    Always responds 200 regardless of whether the email matches an account, so
    the endpoint cannot be used to enumerate registered users.
    """

    permission_classes = [AllowAny]
    serializer_class = PasswordResetRequestSerializer

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"]

        user = User.objects.filter(email__iexact=email, is_active=True).first()
        if user is not None:
            raw_token = issue_reset_token(user)
            send_mail(
                subject="Smart NGO — Password Reset",
                message=(
                    "Use the token below to reset your password. "
                    "It is valid for one hour and can be used once.\n\n"
                    f"Reset token: {raw_token}\n"
                ),
                from_email=None,  # falls back to DEFAULT_FROM_EMAIL
                recipient_list=[user.email],
                fail_silently=True,
            )

        return Response(
            {"detail": "If that email is registered, a reset token has been sent."},
            status=status.HTTP_200_OK,
        )


class PasswordResetConfirmView(APIView):
    """Set a new password using a valid reset token, then consume the token."""

    permission_classes = [AllowAny]
    serializer_class = PasswordResetConfirmSerializer

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        record = consume_reset_token(serializer.validated_data["token"])
        if record is None:
            return Response(
                {"error": "Invalid or expired reset token.", "code": "token_invalid"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = record.user
        user.set_password(serializer.validated_data["new_password"])
        user.save(update_fields=["password"])

        record.used = True
        record.save(update_fields=["used"])

        return Response(
            {"detail": "Password has been reset successfully."},
            status=status.HTTP_200_OK,
        )

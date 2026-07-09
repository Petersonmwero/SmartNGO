"""Authentication endpoints: register, login, logout, token refresh, password reset,
email verification."""
from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.mail import send_mail
from drf_spectacular.utils import OpenApiResponse, extend_schema, inline_serializer
from rest_framework import generics, serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from apps.accounts.permissions import IsSystemAdmin
from core.responses import SuccessResponse

from .serializers import (
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    RegisterSerializer,
    SmartTokenObtainPairSerializer,
    UserManagementSerializer,
    UserProfileSerializer,
)
from .tokens import (
    consume_email_verification_token,
    consume_reset_token,
    issue_email_verification_token,
    issue_reset_token,
)

User = get_user_model()


def _send_verification_email(user, raw_token):
    """Send an email verification link to the newly registered user."""
    base_url = getattr(settings, "BACKEND_BASE_URL", "http://localhost:8000")
    verify_link = f"{base_url}/api/v1/auth/verify-email/?token={raw_token}"
    send_mail(
        subject="Smart NGO — Verify your email address",
        message=(
            f"Hi {user.full_name},\n\n"
            "Thank you for registering with Smart NGO M&E.\n\n"
            "Click the link below to verify your email address and activate your account:\n\n"
            f"{verify_link}\n\n"
            "This link expires in 24 hours. If you did not create this account, "
            "you can safely ignore this email."
        ),
        from_email=None,
        recipient_list=[user.email],
        fail_silently=True,
    )


class RegisterView(generics.CreateAPIView):
    """Create a new (officer/manager/donor) account.

    The account is created with is_active=False. A verification email is sent;
    the user must click the link before they can log in.
    Admin accounts must be created by an existing admin via POST /api/v1/users/.
    """

    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]

    def perform_create(self, serializer):
        user = serializer.save(is_active=False)
        raw_token = issue_email_verification_token(user)
        _send_verification_email(user, raw_token)

    def create(self, request, *args, **kwargs):
        # Normalize to lowercase before any uniqueness check so "User@NGO.org"
        # and "user@ngo.org" are treated as the same address.
        email = request.data.get("email", "").strip().lower()

        # If a previous registration attempt left an unverified record (e.g. the
        # verification link expired), delete it so the user can re-register.
        if email:
            User.objects.filter(
                email__iexact=email,
                is_active=False,
            ).filter(
                email_verification_tokens__used=False,
            ).delete()

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        return Response(
            {
                "status": "success",
                "message": (
                    "Account created. A verification email has been sent to "
                    f"{email or request.data.get('email', '')}. "
                    "Please check your inbox and click the link to activate your account."
                ),
            },
            status=status.HTTP_201_CREATED,
        )


class VerifyEmailView(APIView):
    """Validate a verification token and activate the user's account.

    GET /api/v1/auth/verify-email/?token=<raw_token>
    """

    permission_classes = [AllowAny]

    def get(self, request):
        raw_token = request.query_params.get("token", "").strip()
        if not raw_token:
            return Response(
                {"error": "Verification token is required.", "code": "token_required"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        record = consume_email_verification_token(raw_token)
        if record is None:
            return Response(
                {
                    "error": "This verification link is invalid or has expired. "
                    "Please request a new one.",
                    "code": "token_invalid",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        user = record.user
        user.is_active = True
        user.save(update_fields=["is_active"])
        record.used = True
        record.save(update_fields=["used"])
        return Response(
            {
                "status": "success",
                "message": "Email verified successfully. You can now log in.",
            },
            status=status.HTTP_200_OK,
        )


class ResendVerificationView(APIView):
    """Re-send the verification email for an unverified account.

    POST /api/v1/auth/resend-verification/  — body: {"email": "..."}
    Always responds 200 to prevent user enumeration.
    """

    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get("email", "").strip()
        if not email:
            return Response(
                {"error": "Email is required.", "code": "email_required"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        User = get_user_model()
        user = User.objects.filter(email__iexact=email, is_active=False).first()
        if user is not None:
            raw_token = issue_email_verification_token(user)
            _send_verification_email(user, raw_token)
        return Response(
            {
                "status": "success",
                "message": (
                    "If that email belongs to an unverified account, "
                    "a new verification link has been sent."
                ),
            },
            status=status.HTTP_200_OK,
        )


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


class MeView(generics.RetrieveAPIView):
    """Return the currently authenticated user's own profile."""

    serializer_class = UserProfileSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user


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


class UserManagementViewSet(viewsets.ModelViewSet):
    """Admin-only user management: list, create, activate/deactivate.

    Scoped to the admin's own NGO so a compromised admin account cannot
    reach users in other NGOs.
    """

    serializer_class = UserManagementSerializer
    permission_classes = [IsSystemAdmin]
    queryset = User.objects.none()  # overridden in get_queryset; needed for schema

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return User.objects.none()
        return (
            User.objects.filter(ngo=self.request.user.ngo)
            .select_related("ngo")
            .order_by("first_name", "last_name")
        )

    @action(detail=True, methods=["patch"], url_path="toggle-active")
    def toggle_active(self, request, pk=None):
        """Toggle a user's is_active flag (activate or deactivate)."""
        user = self.get_object()
        user.is_active = not user.is_active
        user.save(update_fields=["is_active"])
        label = "activated" if user.is_active else "deactivated"
        return SuccessResponse(
            data={"id": user.id, "is_active": user.is_active},
            message=f"User {label} successfully.",
        )

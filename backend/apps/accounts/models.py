"""
User model and password-reset tokens.

The User is a custom model keyed on email (no username), belonging to exactly
one NGO. `role` drives application-level RBAC; Django's is_staff/is_superuser
are kept only for admin-site access.
"""
from django.contrib.auth.models import (
    AbstractBaseUser,
    BaseUserManager,
    PermissionsMixin,
)
from django.db import models


class Role(models.TextChoices):
    ADMIN = "admin", "Administrator"
    MANAGER = "manager", "Project Manager"
    OFFICER = "officer", "Field Officer"
    DONOR = "donor", "Donor"


class UserManager(BaseUserManager):
    """Manager for the email-keyed custom User model."""

    use_in_migrations = True

    def _create_user(self, email, password, **extra_fields):
        if not email:
            raise ValueError("Users must have an email address.")
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra_fields):
        extra_fields.setdefault("role", Role.OFFICER)
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault("role", Role.ADMIN)
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")

        # users.ngo_id is NOT NULL, but createsuperuser cannot prompt for an
        # NGO. Fall back to a bootstrap "System" NGO so the first admin can be
        # created. (See accounts/migrations data migration that seeds it.)
        if "ngo" not in extra_fields and "ngo_id" not in extra_fields:
            from apps.ngos.models import NGO

            ngo, _ = NGO.objects.get_or_create(
                registration_no="SYSTEM-0001",
                defaults={"name": "System NGO"},
            )
            extra_fields["ngo"] = ngo

        return self._create_user(email, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    full_name = models.CharField(max_length=255)
    email = models.EmailField(unique=True)
    role = models.CharField(max_length=20, choices=Role.choices, default=Role.OFFICER)
    phone = models.CharField(max_length=30, blank=True)
    ngo = models.ForeignKey(
        "ngos.NGO",
        on_delete=models.PROTECT,
        related_name="users",
        db_column="ngo_id",
    )
    # Soft-delete flag (also doubles as Django's active flag). We never hard
    # delete users; deactivation flips this to False.
    is_active = models.BooleanField(default=True)
    # Admin-site access only — not the application "admin" role.
    is_staff = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["full_name"]

    class Meta:
        db_table = "users"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.full_name} <{self.email}>"

    @property
    def is_app_admin(self):
        return self.role == Role.ADMIN


class PasswordResetToken(models.Model):
    """Single-use, hashed, time-limited password-reset token."""

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="password_reset_tokens",
        db_column="user_id",
    )
    token = models.CharField(max_length=255, unique=True)  # stores a hash, never the raw token
    expires_at = models.DateTimeField()
    used = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "password_reset_tokens"
        ordering = ["-created_at"]

    def __str__(self):
        return f"reset-token user={self.user_id} used={self.used}"

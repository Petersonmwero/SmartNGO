import re
from datetime import date

from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.accounts.models import Role
from core.utils import compute_age

from .models import Beneficiary

# Fields a donor is allowed to see. Everything else — phone, national_id,
# guardian details, postal address, DOB, consent, and the audit trail — is
# stripped SERVER-SIDE for donors (Kenya Data Protection Act 2019).
_DONOR_VISIBLE_FIELDS = frozenset({
    "id", "name", "gender", "age",
    "country", "county", "constituency", "ward",
    "location", "sub_location", "village", "full_location",
    "project", "project_name", "approval_status",
})

# The age (in years, at registration) at and above which a beneficiary is
# treated as an adult for the ID/guardian rules.
ADULT_AGE = 18

# Kenyan mobile numbers: an optional +254 / 254 / 0 prefix, then a 7 or 1
# network digit, then eight subscriber digits (e.g. 0712345678).
_KENYAN_PHONE = re.compile(r"^(?:\+?254|0)(?:7|1)\d{8}$")

# Photo/size limits mirror the report-image validation.
MAX_PHOTO_SIZE = 5 * 1024 * 1024  # 5 MB
ALLOWED_PHOTO_TYPES = {"image/jpeg", "image/png", "image/webp"}


def _validate_kenyan_phone(value, label):
    """Reject a non-blank number that is not a valid Kenyan mobile number."""
    if value and not _KENYAN_PHONE.match(value.strip().replace(" ", "")):
        raise serializers.ValidationError(
            f"Enter a valid Kenyan {label} number (e.g. 0712345678)."
        )
    return value


class BeneficiarySerializer(serializers.ModelSerializer):
    # Age is derived from date_of_birth on read — never stored.
    age = serializers.SerializerMethodField()
    # Display name so clients need not resolve the project id themselves.
    project_name = serializers.CharField(
        source="project.project_name", read_only=True
    )
    # Joined "village, ward, constituency, county, country" display string.
    full_location = serializers.SerializerMethodField()

    class Meta:
        model = Beneficiary
        fields = [
            "id",
            "name",
            "gender",
            "date_of_birth",
            "age",
            "phone",
            "country",
            "county",
            "constituency",
            "ward",
            "location",
            "sub_location",
            "village",
            "full_location",
            "project",
            "project_name",
            # Identity / consent
            "photo",
            "national_id",
            "guardian_name",
            "guardian_phone",
            "postal_address",
            "consent_given",
            # Approval workflow (read-only; driven by the approve/reject actions)
            "approval_status",
            "approved_by",
            "approved_at",
            "rejection_reason",
            "registered_by",
            "is_active",
            "created_at",
        ]
        # is_active is managed via soft-delete; the workflow/audit fields are
        # set by the approve/reject actions and perform_create, never directly.
        read_only_fields = [
            "id",
            "is_active",
            "created_at",
            "approval_status",
            "approved_by",
            "approved_at",
            "rejection_reason",
            "registered_by",
        ]

    def to_representation(self, instance):
        """Strip PII for donors; everyone else sees the full record.

        Officers/managers/admins receive every field including the audit trail;
        donors receive only the non-identifying subset in ``_DONOR_VISIBLE_FIELDS``.
        """
        data = super().to_representation(instance)
        request = self.context.get("request")
        role = getattr(getattr(request, "user", None), "role", None)
        if role == Role.DONOR:
            return {k: v for k, v in data.items() if k in _DONOR_VISIBLE_FIELDS}
        return data

    @extend_schema_field(serializers.CharField())
    def get_full_location(self, obj):
        return obj.full_location

    @extend_schema_field(serializers.IntegerField(allow_null=True))
    def get_age(self, obj):
        dob = obj.date_of_birth
        if not dob:
            return None
        return compute_age(dob)

    def validate_date_of_birth(self, value):
        if value and value > date.today():
            raise serializers.ValidationError("Date of birth cannot be in the future.")
        return value

    def validate_phone(self, value):
        return _validate_kenyan_phone(value, "phone")

    def validate_guardian_phone(self, value):
        return _validate_kenyan_phone(value, "guardian phone")

    def validate_photo(self, value):
        if value is None:
            return value
        if value.size > MAX_PHOTO_SIZE:
            raise serializers.ValidationError("Photo must be 5MB or smaller.")
        content_type = getattr(value, "content_type", None)
        if content_type and content_type not in ALLOWED_PHOTO_TYPES:
            raise serializers.ValidationError(
                "Unsupported image type. Allowed: JPEG, PNG, WEBP."
            )
        return value

    def _registration_age(self, attrs):
        """Age at the registration date, applying the same freeze the model does.

        Uses the incoming date_of_birth (create) or the stored one (update),
        measured against the existing record's created_at when there is one so
        the age-conditional rules stay pinned to registration.
        """
        dob = attrs.get("date_of_birth")
        if dob is None and self.instance is not None:
            dob = self.instance.date_of_birth
        if not dob:
            return None
        reference = None
        if self.instance is not None and self.instance.created_at:
            reference = self.instance.created_at.date()
        return compute_age(dob, reference)

    def validate(self, attrs):
        """Enforce the age-conditional identity and consent rules.

        Requirements are frozen at registration age (see ``_registration_age``):
        consent is always required; adults (18+) must supply a national ID;
        minors must supply both guardian name and phone; and every beneficiary
        needs at least one reachable number (their own or a guardian's).
        """

        def current(field):
            if field in attrs:
                return attrs[field]
            return getattr(self.instance, field, None)

        if not current("consent_given"):
            raise serializers.ValidationError(
                {"consent_given": "Consent must be given to register a beneficiary."}
            )

        age = self._registration_age(attrs)
        phone = (current("phone") or "").strip()
        guardian_name = (current("guardian_name") or "").strip()
        guardian_phone = (current("guardian_phone") or "").strip()
        national_id = (current("national_id") or "").strip()

        if age is not None:
            if age >= ADULT_AGE:
                if not national_id:
                    raise serializers.ValidationError(
                        {"national_id": "National ID is required for adults (18+)."}
                    )
            else:
                missing = {}
                if not guardian_name:
                    missing["guardian_name"] = "Guardian name is required for minors."
                if not guardian_phone:
                    missing["guardian_phone"] = "Guardian phone is required for minors."
                if missing:
                    raise serializers.ValidationError(missing)

        if not phone and not guardian_phone:
            raise serializers.ValidationError(
                "At least one contact number (phone or guardian phone) is required."
            )

        return attrs

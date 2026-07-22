"""
Populate the database with rich, realistic demo data for development / demos.

Idempotent — safe to run multiple times (keyed on natural fields, so it won't
create duplicates). Run with:

    python manage.py seed_demo
"""
import io
from datetime import date, datetime, timedelta
from decimal import Decimal

from django.core.files.base import ContentFile
from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone
from PIL import Image, ImageDraw, ImageFont

from apps.accounts.models import Role, User
from apps.beneficiaries.models import Beneficiary
from apps.indicators.models import Indicator
from apps.ngos.models import NGO
from apps.notifications.models import Notification
from apps.projects.models import (
    Milestone,
    Project,
    ProjectAssignment,
    ProjectPhase,
)
from apps.reports.models import Report, ReportImage
from apps.reports.services import post_report

DEMO_PASSWORD = "DemoPass123!"

# Generated demo-photo dimensions (JPEG keeps seeded media small).
PHOTO_WIDTH = 800
PHOTO_HEIGHT = 600
PHOTO_JPEG_QUALITY = 85


def _demo_photo(caption, gradient):
    """Render a placeholder field photo: vertical two-colour gradient with the
    caption printed on it, returned as a JPEG ContentFile.

    Real evidence photos cannot ship with the repo, so demo reports carry
    clearly-labelled generated images instead of broken links.
    """
    top, bottom = gradient
    img = Image.new("RGB", (PHOTO_WIDTH, PHOTO_HEIGHT))
    draw = ImageDraw.Draw(img)
    for y in range(PHOTO_HEIGHT):
        t = y / PHOTO_HEIGHT
        draw.line(
            [(0, y), (PHOTO_WIDTH, y)],
            fill=tuple(round(top[c] + (bottom[c] - top[c]) * t) for c in range(3)),
        )
    # Dark strip at the bottom so the caption reads on any gradient.
    # Pillow's default font has no em-dash glyph, so draw with a hyphen.
    draw.rectangle([(0, PHOTO_HEIGHT - 90), (PHOTO_WIDTH, PHOTO_HEIGHT)],
                   fill=(28, 28, 30))
    draw.text((24, PHOTO_HEIGHT - 72), caption.replace("—", "-"),
              fill=(255, 255, 255), font=ImageFont.load_default(28))
    draw.text((24, 24), "DEMO PHOTO",
              fill=(255, 255, 255), font=ImageFont.load_default(18))
    buffer = io.BytesIO()
    img.save(buffer, format="JPEG", quality=PHOTO_JPEG_QUALITY)
    return ContentFile(buffer.getvalue())


class Command(BaseCommand):
    help = "Seed the database with demo NGOs, users, projects, and related data."

    @transaction.atomic
    def handle(self, *args, **options):
        today = timezone.now().date()

        # ── NGOs ─────────────────────────────────────────────────────────
        green = self._ngo("Green Earth Initiative", "NGO-GEI-001", "Kisumu, Kenya")
        health = self._ngo("HealthBridge Kenya", "NGO-HBK-002", "Nairobi, Kenya")
        edu = self._ngo("EduReach Africa", "NGO-ERA-003", "Eldoret, Kenya")

        # ── Users (one per role + second-NGO staff for scoping demos) ────
        self._user("admin@demo.ngo", "Ada", "Admin", Role.ADMIN, green,
                   is_staff=True, is_superuser=True)
        manager = self._user(
            "manager@demo.ngo", "Moses", "Kiprop", Role.MANAGER, green)
        officer1 = self._user(
            "officer1@demo.ngo", "Jane", "Achieng", Role.OFFICER, green)
        officer2 = self._user(
            "officer2@demo.ngo", "Samuel", "Koech", Role.OFFICER, green)
        self._user("donor@demo.ngo", "Dana", "Donor", Role.DONOR, green)
        manager2 = self._user(
            "manager2@demo.ngo", "Mary", "Wambui", Role.MANAGER, health)
        self._user("manager3@demo.ngo", "Elly", "Otieno", Role.MANAGER, edu)

        # ── Green Earth projects (timeline dates approximate the target
        #    "% elapsed" shown on cards: 72% / 18% / 34%) ─────────────────
        water = self._project(
            "Clean Water Initiative — Kisumu", green, "active", "2400000.00",
            today - timedelta(days=263), today + timedelta(days=102))
        bursary = self._project(
            "Girls Education Bursary — Baringo", green, "planning", "1100000.00",
            today - timedelta(days=36), today + timedelta(days=164))
        food = self._project(
            "Food Security Programme — Turkana", green, "on_hold", "5800000.00",
            today - timedelta(days=136), today + timedelta(days=264))
        clinic = self._project(
            "Community Clinic Outreach", health, "active", "2000000.00",
            today - timedelta(days=120), today + timedelta(days=240))

        # ── Assignments (signals create "added to project" notifications) ─
        for project in (water, bursary, food):
            self._assign(project, manager, "manager")
        self._assign(water, officer1, "officer")
        self._assign(bursary, officer1, "officer")
        self._assign(food, officer2, "officer")
        self._assign(clinic, manager2, "manager")

        # ── Milestones (weights drive the physical-progress dimension) ────
        # Clean Water: 3/12 weights delivered -> physical 25%.
        self._milestone(water, "Site surveys completed",
                        today - timedelta(days=200), "completed", weight=2)
        self._milestone(water, "Community mobilisation",
                        today - timedelta(days=150), "completed", weight=1)
        self._milestone(water, "Phase 1 Borehole Drilling",
                        today + timedelta(days=30), "pending", weight=4)
        self._milestone(water, "Pump installation",
                        today + timedelta(days=70), "pending", weight=3)
        self._milestone(water, "Hygiene training",
                        today + timedelta(days=95), "pending", weight=2)
        # Girls Education: 2/10 weights delivered -> physical 20% (healthy:
        # matches 20% financial and slightly leads ~18% time progress).
        self._milestone(bursary, "Needs assessment completed",
                        today - timedelta(days=10), "completed", weight=2)
        self._milestone(bursary, "Bursary application window opens",
                        today + timedelta(days=20), "pending", weight=3)
        self._milestone(bursary, "First disbursement",
                        today + timedelta(days=90), "pending", weight=5)
        # Food Security: 1/10 weights delivered -> physical 10% against 50%
        # financial spend (critical: spending far faster than delivering).
        self._milestone(food, "Baseline nutrition survey",
                        today - timedelta(days=100), "completed", weight=1)
        self._milestone(food, "Seed distribution — Phase 1",
                        today - timedelta(days=10), "overdue", weight=4)
        self._milestone(food, "Irrigation training",
                        today + timedelta(days=45), "pending", weight=3)
        self._milestone(food, "Harvest assessment",
                        today + timedelta(days=180), "pending", weight=2)

        # ── Project phases (spend drives the financial dimension) ─────────
        # Clean Water: KES 1,728,000 of 2.4M spent -> financial 72%.
        self._phase(water, "Planning", "planning", "400000", "400000",
                    today - timedelta(days=263), today - timedelta(days=210),
                    "completed")
        self._phase(water, "Site Survey", "planning", "200000", "200000",
                    today - timedelta(days=210), today - timedelta(days=160),
                    "completed")
        self._phase(water, "Drilling", "implementation", "1200000", "928000",
                    today - timedelta(days=160), today + timedelta(days=40),
                    "in_progress")
        self._phase(water, "Installation", "implementation", "400000", "200000",
                    today - timedelta(days=30), today + timedelta(days=75),
                    "in_progress")
        self._phase(water, "Training", "closeout", "200000", "0",
                    today + timedelta(days=75), today + timedelta(days=102),
                    "not_started")
        # Girls Education: KES 220,000 of 1.1M spent -> financial 20%.
        self._phase(bursary, "Planning", "planning", "200000", "200000",
                    today - timedelta(days=36), today - timedelta(days=5),
                    "completed")
        self._phase(bursary, "School Outreach", "implementation",
                    "150000", "20000",
                    today - timedelta(days=5), today + timedelta(days=40),
                    "in_progress")
        self._phase(bursary, "Bursary Disbursement", "implementation",
                    "650000", "0",
                    today + timedelta(days=40), today + timedelta(days=130),
                    "not_started")
        self._phase(bursary, "Monitoring & Evaluation", "monitoring",
                    "100000", "0",
                    today + timedelta(days=130), today + timedelta(days=164),
                    "not_started")
        # Food Security: KES 2,900,000 of 5.8M spent -> financial 50%.
        self._phase(food, "Planning", "planning", "500000", "500000",
                    today - timedelta(days=136), today - timedelta(days=100),
                    "completed")
        self._phase(food, "Input Procurement", "implementation",
                    "2500000", "2200000",
                    today - timedelta(days=100), today + timedelta(days=20),
                    "in_progress")
        self._phase(food, "Distribution", "implementation",
                    "1800000", "200000",
                    today - timedelta(days=20), today + timedelta(days=120),
                    "in_progress")
        self._phase(food, "Farmer Training", "implementation", "700000", "0",
                    today + timedelta(days=120), today + timedelta(days=210),
                    "not_started")
        self._phase(food, "Evaluation & Closeout", "closeout", "300000", "0",
                    today + timedelta(days=210), today + timedelta(days=264),
                    "not_started")

        # ── Indicators (KPIs) ────────────────────────────────────────────
        self._indicator(water, "Boreholes drilled", "50", "36", "wells")
        self._indicator(water, "Hygiene training sessions", "40", "29", "sessions")
        self._indicator(bursary, "Bursaries awarded", "120", "0", "girls")
        self._indicator(food, "Households reached", "800", "270", "households")

        # ── Beneficiaries (full admin hierarchy per person) ───────────────
        # Tuple: (name, gender, dob, project,
        #         county, constituency, ward, location, sub_location, village)
        for row in [
            ("Amani Wanjiku", "female", date(2018, 4, 12), water,
             "Kisumu", "Kisumu West", "Central Kisumu",
             "Milimani", "Upper Milimani", ""),
            ("Baraka Otieno", "male", date(2015, 9, 3), water,
             "Kisumu", "Kisumu West", "Central Kisumu",
             "Central Kisumu", "", ""),
            ("Zawadi Cherono", "female", date(1992, 1, 20), water,
             "Kisumu", "Kisumu East", "Nyalenda A",
             "Nyalenda A", "Nyalenda A1", "Nyalenda"),
            ("Neema Akinyi", "female", date(1996, 7, 8), water,
             "Kisumu", "Kisumu East", "Nyalenda A",
             "Nyalenda A", "Nyalenda A2", "Nyalenda"),
            ("Chebet Kimutai", "female", date(2010, 3, 15), bursary,
             "Baringo", "Baringo Central", "Kabarnet",
             "Kabarnet", "Kabarnet A", ""),
            ("Jepkorir Ruto", "female", date(2009, 11, 2), bursary,
             "Baringo", "Baringo South", "Marigat", "", "", ""),
            ("Chepkemoi Langat", "female", date(2011, 6, 25), bursary,
             "Baringo", "Baringo North", "Kabartonjo", "", "", ""),
            ("Juma Hassan", "male", date(2012, 11, 30), food,
             "Turkana", "Turkana Central", "Lodwar Township",
             "Lodwar", "Lodwar A", "Lodwar"),
            ("Ekai Lokol", "male", date(1988, 2, 14), food,
             "Turkana", "Turkana West", "Kakuma",
             "Kakuma", "Kakuma B", "Kakuma"),
            ("Akiru Napeyok", "female", date(1995, 8, 21), food,
             "Turkana", "Turkana South", "Lokichar",
             "Lokichar", "Lokichar A", "Lokichar"),
            ("Lokwawi Emuria", "male", date(2005, 5, 9), food,
             "Turkana", "Turkana Central", "Kanamkemer",
             "", "", "Lodwar"),
            ("Asekon Ewoi", "female", date(2001, 12, 3), food,
             "Turkana", "Turkana Central", "Kalokol",
             "Kalokol", "Kalokol A", ""),
        ]:
            self._beneficiary(*row)

        # ── Reports (draft / submitted / approved) ───────────────────────
        borehole = self._report(water, officer1, "Borehole 12 drilling progress",
                                "weekly", "approved")
        survey = self._report(water, officer1, "Community Survey — Nyalenda ward",
                              "monthly", "submitted")
        pump = self._report(water, officer1, "Pump maintenance notes",
                            "daily", "draft")
        # One fully structured, approved report so the demo shows donor
        # reporting end to end: its spend posts to the Drilling phase and its
        # reach feeds the project's impact card.
        self._structured_report(
            water,
            officer1,
            title="Borehole 12 handover",
            phase_name="Drilling",
            milestone_title="Phase 1 Borehole Drilling",
        )

        # ── Back-dated reports so the reporting-trend chart spans months ──
        # Without these, every seeded report lands in the current month and the
        # 6-month trend shows a single bar. Each tuple is
        # (months_ago, submitted_total, approved_count); the approved ones are
        # posted with no linked phase/milestone and zero spend, so they fill the
        # trend's approved bars without moving any EVM or impact figure.
        for months_ago, submitted_total, approved_count in [
            (5, 2, 1),
            (4, 3, 2),
            (3, 2, 1),
            (2, 4, 3),
            (1, 3, 2),
        ]:
            for i in range(submitted_total):
                self._historical_report(
                    water, officer1,
                    title=f"Monthly field report {months_ago}m-{i + 1}",
                    months_ago=months_ago,
                    approved=i < approved_count,
                )

        # ── Report photos (generated evidence images) ────────────────────
        self._report_photo(borehole, "Drilling rig on site — Borehole 12",
                           ((30, 74, 47), (123, 175, 122)))
        self._report_photo(borehole, "Casing installed at 40m depth",
                           ((58, 58, 60), (177, 156, 121)))
        self._report_photo(survey, "Household interviews — Nyalenda ward",
                           ((232, 160, 32), (255, 200, 74)))
        self._report_photo(survey, "Water collection point, Nyalenda",
                           ((21, 101, 192), (144, 202, 249)))
        self._report_photo(pump, "Worn impeller before replacement",
                           ((146, 64, 14), (232, 160, 32)))

        # ── Notifications for the manager (demo activity feed) ───────────
        for title, message in [
            ("New report submitted by Jane Achieng",
             "Community Survey — Nyalenda ward is awaiting your approval."),
            ("Milestone due in 3 days: Phase 1 Borehole Drilling",
             "Clean Water Initiative — Kisumu has an upcoming milestone."),
            ("Report approved: Community Survey",
             "Your report was approved and is included in donor summaries."),
            ("New officer assigned: Samuel Koech",
             "Samuel Koech joined Food Security Programme — Turkana."),
            ("Budget utilization at 86%",
             "Clean Water Initiative — Kisumu is approaching its budget cap."),
        ]:
            Notification.objects.get_or_create(
                user=manager, title=title, defaults={"message": message})

        self._summary()

    # ── helpers ──────────────────────────────────────────────────────────
    def _ngo(self, name, reg_no, address):
        ngo, _ = NGO.objects.get_or_create(
            registration_no=reg_no,
            defaults={"name": name, "address": address,
                      "contact": "+254700000000",
                      "description": f"{name} — demo NGO."},
        )
        return ngo

    def _user(self, email, first_name, last_name, role, ngo,
              is_staff=False, is_superuser=False):
        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                "first_name": first_name,
                "last_name": last_name,
                "role": role,
                "ngo": ngo,
                "is_staff": is_staff,
                "is_superuser": is_superuser,
            },
        )
        if created:
            user.set_password(DEMO_PASSWORD)
            user.is_active = True
            user.save()
        return user

    def _project(self, name, ngo, status, budget, start, end):
        project, _ = Project.objects.get_or_create(
            project_name=name, ngo=ngo,
            defaults={"status": status, "budget": budget,
                      "start_date": start, "end_date": end,
                      "description": f"{name} — demo project."},
        )
        return project

    def _assign(self, project, user, role):
        ProjectAssignment.objects.get_or_create(
            project=project, user=user, defaults={"role": role})

    def _beneficiary(self, name, gender, dob, project, county, constituency,
                     ward, location, sub_location, village):
        Beneficiary.objects.get_or_create(
            name=name, project=project,
            defaults={"gender": gender, "date_of_birth": dob,
                      "county": county, "constituency": constituency,
                      "ward": ward, "location": location,
                      "sub_location": sub_location, "village": village})

    def _indicator(self, project, name, target, current, unit):
        Indicator.objects.get_or_create(
            indicator_name=name, project=project,
            defaults={"target_value": target, "current_value": current,
                      "unit": unit})

    def _milestone(self, project, title, due, status, weight=1):
        Milestone.objects.get_or_create(
            title=title, project=project,
            defaults={"due_date": due, "status": status, "weight": weight})

    def _phase(self, project, name, phase_type, allocated, spent,
               start, end, status):
        ProjectPhase.objects.get_or_create(
            phase_name=name, project=project,
            defaults={"phase_type": phase_type,
                      "allocated_budget": allocated, "opening_spend": spent,
                      "start_date": start, "end_date": end,
                      "status": status,
                      "description": f"{name} phase — {project.project_name}."})

    def _report(self, project, officer, title, report_type, status):
        report, created = Report.objects.get_or_create(
            title=title, project=project, officer=officer,
            defaults={"report_type": report_type,
                      "description": f"{title} — demo report.",
                      "gps_latitude": "-0.1022000",
                      "gps_longitude": "34.7617000",
                      "status": "submitted" if status != "draft" else "draft",
                      "date_submitted": (timezone.now()
                                         if status != "draft" else None)},
        )
        # Transition into "approved" via save so the approval signal fires.
        if created and status == "approved":
            report.status = Report.Status.APPROVED
            report.save(update_fields=["status"])
        return report

    def _structured_report(self, project, officer, *, title, phase_name,
                           milestone_title):
        """Seed an approved report carrying the full structured payload.

        Posted through `post_report` rather than by setting fields directly,
        so the demo data goes through exactly the path the app uses.
        """
        report, created = Report.objects.get_or_create(
            title=title, project=project, officer=officer,
            defaults={
                "report_type": "monthly",
                "description": "Commissioning visit and handover to the "
                               "water committee.",
                "gps_latitude": "-0.1022000",
                "gps_longitude": "34.7617000",
                "status": Report.Status.SUBMITTED,
                "date_submitted": timezone.now(),
                "activity_type": Report.ActivityType.CONSTRUCTION,
                "linked_phase": project.phases.filter(
                    phase_name=phase_name).first(),
                "linked_milestone": project.milestones.filter(
                    title=milestone_title).first(),
                "amount_spent": Decimal("180000.00"),
                "expenditure_notes": "Pump, casing and apron works.",
                "beneficiaries_reached": 420,
                "beneficiaries_male": 190,
                "beneficiaries_female": 230,
                "beneficiaries_youth": 150,
                "impact_description": "Walking time to safe water cut from "
                                      "90 minutes to 15.",
                "challenges_faced": "Heavy rain delayed casing by a week.",
                "recommendations": "Fence the site before the next rains.",
                "next_steps": "Train the water committee on maintenance.",
            },
        )
        if created:
            post_report(report)
        return report

    def _months_back(self, months_ago):
        """A timezone-aware datetime at midday on the 15th, `months_ago` back.

        Anchored on the 15th so it always lands squarely inside the target
        month, avoiding the drift a fixed 30-day subtraction would cause.
        """
        today = timezone.localdate()
        total = today.year * 12 + (today.month - 1) - months_ago
        year, month = divmod(total, 12)
        return timezone.make_aware(datetime(year, month + 1, 15, 12, 0))

    def _historical_report(self, project, officer, title, months_ago, *,
                           approved):
        """Seed a plain report dated `months_ago` back, for the trend chart.

        Carries no phase/milestone link, reach or spend, so approving it (via
        `post_report`) only sets `posted_at` — the approved trend fills without
        any EVM or donor-impact figure shifting. Buckets by `date_submitted`,
        so the back-date is what places it in an earlier month even though the
        approval timestamp is now.
        """
        report, created = Report.objects.get_or_create(
            title=title, project=project, officer=officer,
            defaults={"report_type": "monthly",
                      "description": f"{title} — demo report.",
                      "gps_latitude": "-0.1022000",
                      "gps_longitude": "34.7617000",
                      "status": Report.Status.SUBMITTED,
                      "date_submitted": self._months_back(months_ago)},
        )
        if created and approved:
            post_report(report)
        return report

    def _report_photo(self, report, caption, gradient):
        """Attach a generated demo photo to a report (idempotent on caption)."""
        if ReportImage.objects.filter(report=report, caption=caption).exists():
            return
        image = ReportImage(report=report, caption=caption)
        image.image.save(
            f"demo_{report.pk}_{ReportImage.objects.filter(report=report).count()}.jpg",
            _demo_photo(caption, gradient),
            save=True,
        )

    def _summary(self):
        out = self.stdout
        out.write(self.style.SUCCESS("\nDemo data seeded successfully."))
        out.write(f"  NGOs: {NGO.objects.count()} | Users: {User.objects.count()} | "
                  f"Projects: {Project.objects.count()} | "
                  f"Beneficiaries: {Beneficiary.objects.count()} | "
                  f"Reports: {Report.objects.count()} | "
                  f"Notifications: {Notification.objects.count()}")
        out.write("\n  Demo logins (password for all: " +
                  self.style.WARNING(DEMO_PASSWORD) + "):")
        for email, role in [
            ("admin@demo.ngo", "admin"),
            ("manager@demo.ngo", "manager (Green Earth Initiative)"),
            ("officer1@demo.ngo", "officer (Green Earth Initiative)"),
            ("donor@demo.ngo", "donor (Green Earth Initiative)"),
            ("manager2@demo.ngo", "manager (HealthBridge Kenya)"),
        ]:
            out.write(f"    {email:22} {role}")

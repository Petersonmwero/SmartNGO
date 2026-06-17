"""
Populate the database with realistic demo data for development / demos.

Idempotent — safe to run multiple times (keyed on natural fields, so it won't
create duplicates). Run with:

    python manage.py seed_demo
"""
from datetime import date, timedelta

from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from apps.accounts.models import Role, User
from apps.beneficiaries.models import Beneficiary
from apps.indicators.models import Indicator
from apps.ngos.models import NGO
from apps.projects.models import Milestone, Project, ProjectAssignment
from apps.reports.models import Report

DEMO_PASSWORD = "DemoPass123!"


class Command(BaseCommand):
    help = "Seed the database with demo NGOs, users, projects, and related data."

    @transaction.atomic
    def handle(self, *args, **options):
        today = timezone.now().date()

        # ── NGOs ─────────────────────────────────────────────────────────
        ngo1 = self._ngo("Green Earth Initiative", "NGO-GEI-001", "Eldoret, Kenya")
        ngo2 = self._ngo("HealthBridge Africa", "NGO-HBA-002", "Kisumu, Kenya")

        # ── Users (one per role + extras to show NGO scoping) ────────────
        admin = self._user("admin@demo.ngo", "Ada Admin", Role.ADMIN, ngo1,
                            is_staff=True, is_superuser=True)
        manager = self._user("manager@demo.ngo", "Moses Manager", Role.MANAGER, ngo1)
        officer1 = self._user("officer1@demo.ngo", "Faith Officer", Role.OFFICER, ngo1)
        officer2 = self._user("officer2@demo.ngo", "Brian Officer", Role.OFFICER, ngo1)
        donor = self._user("donor@demo.ngo", "Dana Donor", Role.DONOR, ngo1)
        # A second NGO's staff — used to demonstrate that data is NGO-scoped.
        manager2 = self._user("manager2@demo.ngo", "Mary Manager", Role.MANAGER, ngo2)
        officer3 = self._user("officer3@demo.ngo", "Otis Officer", Role.OFFICER, ngo2)

        # ── Projects ─────────────────────────────────────────────────────
        wells = self._project(
            "Clean Water Wells", ngo1, "active", "1500000.00",
            today - timedelta(days=90), today + timedelta(days=275))
        maternal = self._project(
            "Maternal Health Outreach", ngo1, "active", "900000.00",
            today - timedelta(days=60), today + timedelta(days=300))
        feeding = self._project(
            "School Feeding Program", ngo1, "planning", "450000.00",
            today + timedelta(days=30), today + timedelta(days=395))
        clinic = self._project(
            "Community Clinic", ngo2, "active", "2000000.00",
            today - timedelta(days=120), today + timedelta(days=240))

        # ── Assignments (signals create "added to project" notifications) ─
        for project in (wells, maternal, feeding):
            self._assign(project, manager, "manager")
        self._assign(wells, officer1, "officer")
        self._assign(maternal, officer1, "officer")
        self._assign(feeding, officer2, "officer")
        self._assign(clinic, manager2, "manager")
        self._assign(clinic, officer3, "officer")

        # ── Beneficiaries ────────────────────────────────────────────────
        self._beneficiary("Amani Wanjiku", "female", date(2018, 4, 12), wells, "Turbo")
        self._beneficiary("Baraka Otieno", "male", date(2015, 9, 3), wells, "Turbo")
        self._beneficiary("Zawadi Cherono", "female", date(1992, 1, 20), maternal, "Kapsabet")
        self._beneficiary("Neema Akinyi", "female", date(1996, 7, 8), maternal, "Kapsabet")
        self._beneficiary("Juma Hassan", "male", date(2012, 11, 30), feeding, "Eldoret")

        # ── Indicators (KPIs) ────────────────────────────────────────────
        self._indicator(wells, "Boreholes drilled", "50", "18", "wells")
        self._indicator(wells, "People with water access", "10000", "4200", "people")
        self._indicator(maternal, "Mothers reached", "500", "215", "mothers")
        self._indicator(feeding, "Meals served", "200000", "0", "meals")

        # ── Milestones (pending / completed / overdue) ───────────────────
        self._milestone(wells, "Site survey completed", today - timedelta(days=70), "completed")
        self._milestone(wells, "First 10 wells drilled", today - timedelta(days=5), "overdue")
        self._milestone(wells, "Community handover", today + timedelta(days=120), "pending")
        self._milestone(maternal, "Baseline survey", today + timedelta(days=10), "pending")

        # ── Reports (draft / submitted / approved) ───────────────────────
        self._report(wells, officer1, "Week 1 drilling update", "weekly", "approved")
        self._report(wells, officer1, "Equipment delay note", "daily", "submitted")
        self._report(maternal, officer1, "Outreach day 1", "daily", "draft")

        self._summary(ngo1, ngo2)

    # ── helpers ──────────────────────────────────────────────────────────
    def _ngo(self, name, reg_no, address):
        ngo, _ = NGO.objects.get_or_create(
            registration_no=reg_no,
            defaults={"name": name, "address": address,
                      "contact": "+254700000000",
                      "description": f"{name} — demo NGO."},
        )
        return ngo

    def _user(self, email, full_name, role, ngo, is_staff=False, is_superuser=False):
        user, created = User.objects.get_or_create(
            email=email,
            defaults={"full_name": full_name, "role": role, "ngo": ngo,
                      "is_staff": is_staff, "is_superuser": is_superuser},
        )
        if created:
            user.set_password(DEMO_PASSWORD)
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

    def _beneficiary(self, name, gender, dob, project, location):
        Beneficiary.objects.get_or_create(
            name=name, project=project,
            defaults={"gender": gender, "date_of_birth": dob, "location": location})

    def _indicator(self, project, name, target, current, unit):
        Indicator.objects.get_or_create(
            indicator_name=name, project=project,
            defaults={"target_value": target, "current_value": current, "unit": unit})

    def _milestone(self, project, title, due, status):
        Milestone.objects.get_or_create(
            title=title, project=project,
            defaults={"due_date": due, "status": status})

    def _report(self, project, officer, title, report_type, status):
        report, created = Report.objects.get_or_create(
            title=title, project=project, officer=officer,
            defaults={"report_type": report_type,
                      "description": f"{title} — demo report.",
                      "gps_latitude": "0.5142700", "gps_longitude": "35.2697800",
                      "status": "submitted" if status != "draft" else "draft",
                      "date_submitted": (timezone.now() if status != "draft" else None)},
        )
        # Transition into "approved" via save so the approval signal fires.
        if created and status == "approved":
            report.status = Report.Status.APPROVED
            report.save(update_fields=["status"])

    def _summary(self, ngo1, ngo2):
        out = self.stdout
        out.write(self.style.SUCCESS("\nDemo data seeded successfully."))
        out.write(f"  NGOs: {NGO.objects.count()} | Users: {User.objects.count()} | "
                  f"Projects: {Project.objects.count()} | "
                  f"Beneficiaries: {Beneficiary.objects.count()} | "
                  f"Reports: {Report.objects.count()}")
        out.write("\n  Demo logins (password for all: " +
                  self.style.WARNING(DEMO_PASSWORD) + "):")
        for email, role in [
            ("admin@demo.ngo", "admin"),
            ("manager@demo.ngo", "manager (NGO: Green Earth)"),
            ("officer1@demo.ngo", "officer (NGO: Green Earth)"),
            ("donor@demo.ngo", "donor (NGO: Green Earth)"),
            ("manager2@demo.ngo", "manager (NGO: HealthBridge)"),
        ]:
            out.write(f"    {email:22} {role}")

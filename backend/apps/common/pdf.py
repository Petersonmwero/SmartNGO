"""PDF document builders (ReportLab) for donor summaries and monthly reports.

Each function returns the PDF as ``bytes`` so callers can wrap it in an
HttpResponse with ``content_type='application/pdf'``.
"""
import calendar
import io

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import (
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

_STYLES = getSampleStyleSheet()

_TABLE_STYLE = TableStyle(
    [
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#2E5A88")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F0F4F8")]),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
    ]
)


def _new_doc(buffer, title):
    return SimpleDocTemplate(
        buffer, pagesize=A4, title=title, topMargin=2 * cm, bottomMargin=2 * cm
    )


def _percent(target, current):
    if target and target > 0:
        return f"{round(float(current) / float(target) * 100, 1)}%"
    return "-"


def project_summary_pdf(project):
    """Donor-facing summary: project info, budget, indicators, milestones."""
    buffer = io.BytesIO()
    doc = _new_doc(buffer, f"Project Summary - {project.project_name}")
    elements = [
        Paragraph(f"Project Summary: {project.project_name}", _STYLES["Title"]),
        Paragraph(f"NGO: {project.ngo.name}", _STYLES["Normal"]),
        Spacer(1, 0.5 * cm),
    ]

    info = [
        ["Field", "Value"],
        ["Status", project.get_status_display()],
        ["Budget", f"{project.budget}"],
        ["Start date", str(project.start_date or "-")],
        ["End date", str(project.end_date or "-")],
    ]
    info_table = Table(info, colWidths=[5 * cm, 11 * cm])
    info_table.setStyle(_TABLE_STYLE)
    elements += [info_table, Spacer(1, 0.6 * cm)]

    # Indicators / KPIs
    elements.append(Paragraph("Indicators", _STYLES["Heading2"]))
    indicator_rows = [["Indicator", "Target", "Current", "Unit", "Progress"]]
    for ind in project.indicators.all():
        indicator_rows.append(
            [
                ind.indicator_name,
                f"{ind.target_value}",
                f"{ind.current_value}",
                ind.unit or "-",
                _percent(ind.target_value, ind.current_value),
            ]
        )
    if len(indicator_rows) == 1:
        indicator_rows.append(["No indicators", "", "", "", ""])
    ind_table = Table(indicator_rows, colWidths=[6 * cm, 2.5 * cm, 2.5 * cm, 2 * cm, 3 * cm])
    ind_table.setStyle(_TABLE_STYLE)
    elements += [ind_table, Spacer(1, 0.6 * cm)]

    # Milestones
    elements.append(Paragraph("Milestones", _STYLES["Heading2"]))
    ms_rows = [["Title", "Due date", "Status"]]
    for ms in project.milestones.all():
        ms_rows.append([ms.title, str(ms.due_date or "-"), ms.get_status_display()])
    if len(ms_rows) == 1:
        ms_rows.append(["No milestones", "", ""])
    ms_table = Table(ms_rows, colWidths=[9 * cm, 4 * cm, 3 * cm])
    ms_table.setStyle(_TABLE_STYLE)
    elements.append(ms_table)

    doc.build(elements)
    return buffer.getvalue()


def monthly_report_pdf(project, year, month):
    """Monthly report: all approved reports for the project in the given month."""
    from apps.reports.models import Report

    buffer = io.BytesIO()
    doc = _new_doc(buffer, f"Monthly Report - {project.project_name}")
    month_name = calendar.month_name[month]
    elements = [
        Paragraph(f"Monthly Report: {project.project_name}", _STYLES["Title"]),
        Paragraph(f"Period: {month_name} {year}", _STYLES["Normal"]),
        Paragraph(f"NGO: {project.ngo.name}", _STYLES["Normal"]),
        Spacer(1, 0.5 * cm),
    ]

    reports = (
        Report.objects.filter(
            project=project,
            status=Report.Status.APPROVED,
            date_submitted__year=year,
            date_submitted__month=month,
        )
        .select_related("officer")
        .order_by("date_submitted")
    )

    rows = [["Title", "Officer", "Type", "Submitted"]]
    for r in reports:
        rows.append(
            [
                r.title,
                r.officer.full_name,
                r.get_report_type_display(),
                r.date_submitted.strftime("%Y-%m-%d") if r.date_submitted else "-",
            ]
        )
    if len(rows) == 1:
        rows.append(["No approved reports for this period", "", "", ""])

    table = Table(rows, colWidths=[6 * cm, 4.5 * cm, 2.5 * cm, 3 * cm])
    table.setStyle(_TABLE_STYLE)
    elements += [
        Paragraph(f"Approved reports: {reports.count()}", _STYLES["Heading3"]),
        Spacer(1, 0.2 * cm),
        table,
    ]

    doc.build(elements)
    return buffer.getvalue()


def donor_impact_pdf(project, summary):
    """Donor impact report: what the money bought, per approved reports only.

    `summary` is the dict from
    `apps.reports.services.project_impact_summary`, so the PDF and the JSON
    endpoint can never disagree about the figures.
    """
    buffer = io.BytesIO()
    doc = _new_doc(buffer, f"Impact Report - {project.project_name}")
    reach = summary["reach"]

    elements = [
        Paragraph(f"Impact Report: {project.project_name}", _STYLES["Title"]),
        Paragraph(f"NGO: {project.ngo.name}", _STYLES["Normal"]),
        Paragraph(
            "Figures below come from field reports approved by a project "
            "manager. Draft and unapproved reports are excluded.",
            _STYLES["Italic"],
        ),
        Spacer(1, 0.5 * cm),
    ]

    headline = [
        ["Measure", "Value"],
        ["People reached", f"{reach['total']:,}"],
        ["Women / girls", f"{reach['female']:,}"],
        ["Men / boys", f"{reach['male']:,}"],
        ["Youth", f"{reach['youth']:,}"],
        ["Approved reports", str(summary["approved_reports"])],
        ["Budget", f"{project.budget:,.2f}"],
        ["Spent to date", f"{summary['total_spent']:,.2f}"],
        [
            "Cost per person reached",
            f"{summary['cost_per_beneficiary']:,.2f}"
            if summary["cost_per_beneficiary"] is not None
            else "-",
        ],
    ]
    headline_table = Table(headline, colWidths=[8 * cm, 8 * cm])
    headline_table.setStyle(_TABLE_STYLE)
    elements += [headline_table, Spacer(1, 0.6 * cm)]

    elements.append(Paragraph("Activity breakdown", _STYLES["Heading2"]))
    activity_rows = [["Activity", "Reports", "People reached", "Spend"]]
    for row in summary["by_activity"]:
        activity_rows.append(
            [
                row["label"],
                str(row["reports"]),
                f"{row['beneficiaries_reached']:,}",
                f"{row['amount_spent']:,.2f}",
            ]
        )
    if len(activity_rows) == 1:
        activity_rows.append(["No approved reports yet", "", "", ""])
    activity_table = Table(
        activity_rows, colWidths=[7 * cm, 2.5 * cm, 3.5 * cm, 3 * cm]
    )
    activity_table.setStyle(_TABLE_STYLE)
    elements += [activity_table, Spacer(1, 0.6 * cm)]

    elements.append(Paragraph("Spend by phase", _STYLES["Heading2"]))
    phase_rows = [["Phase", "Allocated", "Baseline", "From reports", "Spent"]]
    for phase in project.phases.all():
        phase_rows.append(
            [
                phase.phase_name,
                f"{phase.allocated_budget:,.2f}",
                f"{phase.opening_spend:,.2f}",
                f"{phase.reported_spend:,.2f}",
                f"{phase.spent_budget:,.2f}",
            ]
        )
    if len(phase_rows) == 1:
        phase_rows.append(["No phases recorded", "", "", "", ""])
    phase_table = Table(
        phase_rows, colWidths=[5 * cm, 3 * cm, 2.7 * cm, 2.8 * cm, 2.5 * cm]
    )
    phase_table.setStyle(_TABLE_STYLE)
    elements += [phase_table, Spacer(1, 0.6 * cm)]

    elements.append(Paragraph("In the field", _STYLES["Heading2"]))
    if not summary["narratives"]:
        elements.append(
            Paragraph("No narrative reports approved yet.", _STYLES["Normal"])
        )
    for entry in summary["narratives"]:
        elements.append(
            Paragraph(
                f"<b>{entry['title']}</b> — {entry['activity_label']}",
                _STYLES["Normal"],
            )
        )
        for label, key in (
            ("Impact", "impact_description"),
            ("Challenges", "challenges_faced"),
            ("Recommendations", "recommendations"),
            ("Next steps", "next_steps"),
        ):
            if entry[key]:
                elements.append(
                    Paragraph(f"<i>{label}:</i> {entry[key]}", _STYLES["Normal"])
                )
        elements.append(Spacer(1, 0.35 * cm))

    doc.build(elements)
    return buffer.getvalue()

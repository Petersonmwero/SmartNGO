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

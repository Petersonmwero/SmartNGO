"""Rename ProjectPhase.spent_budget to opening_spend and link milestones to
the report that completed them.

Hand-written: autodetection offered RemoveField + AddField, which would drop
the column and every phase's recorded spend with it. RenameField plus a
db_column of "spent_budget" keeps the existing column exactly where it is —
`sqlmigrate` for this migration touches no phase data.
"""
import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("reports", "0001_initial"),
        ("projects", "0002_milestone_weight_projectphase"),
    ]

    operations = [
        # State-only: the field is renamed in Django, but db_column pins it to
        # the same "spent_budget" column, so there is nothing for the database
        # to do. Left as real operations it emits a rename and an immediate
        # rename back — a no-op on SQLite, needless churn on MySQL.
        migrations.SeparateDatabaseAndState(
            state_operations=[
                migrations.RenameField(
                    model_name="projectphase",
                    old_name="spent_budget",
                    new_name="opening_spend",
                ),
                migrations.AlterField(
                    model_name="projectphase",
                    name="opening_spend",
                    field=models.DecimalField(
                        db_column="spent_budget",
                        decimal_places=2,
                        default=0,
                        help_text=(
                            "Expenditure recorded at baseline, before "
                            "report-based tracking. Actual spend = this plus "
                            "approved report spend."
                        ),
                        max_digits=15,
                    ),
                ),
            ],
            database_operations=[],
        ),
        migrations.AddField(
            model_name="milestone",
            name="completed_by_report",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="completed_milestones",
                to="reports.report",
            ),
        ),
    ]

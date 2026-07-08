"""Utility functions shared across multiple apps."""
from datetime import date


def compute_age(date_of_birth: date) -> int:
    """Return a person's current age in whole years from their date of birth."""
    today = date.today()
    return today.year - date_of_birth.year - (
        (today.month, today.day) < (date_of_birth.month, date_of_birth.day)
    )

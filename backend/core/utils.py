"""Utility functions shared across multiple apps."""
from datetime import date


def compute_age(date_of_birth: date, reference: date = None) -> int:
    """Return age in whole years from ``date_of_birth``.

    ``reference`` is the day to measure against; it defaults to today. Pass the
    registration date to freeze age-conditional rules at registration time so a
    beneficiary who later turns 18 does not retroactively change category.
    """
    on = reference or date.today()
    return on.year - date_of_birth.year - (
        (on.month, on.day) < (date_of_birth.month, date_of_birth.day)
    )

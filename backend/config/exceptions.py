"""
Custom DRF exception handler.

Normalises every error response to the project convention:

    {"error": "<human readable message>", "code": "<machine code>"}

with the correct HTTP status code preserved from the underlying exception.
"""
from rest_framework.views import exception_handler as drf_exception_handler


def custom_exception_handler(exc, context):
    response = drf_exception_handler(exc, context)
    if response is None:
        # Unhandled (non-DRF) exception — let Django produce the 500.
        return None

    data = response.data
    code = getattr(exc, "default_code", "error")
    message = "An error occurred."

    if isinstance(data, dict):
        if "detail" in data:
            detail = data["detail"]
            message = str(detail)
            code = getattr(detail, "code", code)
        else:
            # Field validation errors: surface the first one.
            first_key = next(iter(data))
            value = data[first_key]
            if isinstance(value, (list, tuple)) and value:
                value = value[0]
            message = f"{first_key}: {value}"
            code = getattr(value, "code", "invalid")
    elif isinstance(data, list) and data:
        message = str(data[0])
        code = getattr(data[0], "code", code)
    else:
        message = str(data)

    response.data = {"error": message, "code": code}
    return response

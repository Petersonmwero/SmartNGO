"""Standard HTTP response wrappers for consistent API envelopes.

All new endpoints use SuccessResponse so clients get:
  {"status": "success", "data": ..., "message": ""}

Error responses are handled separately by config/exceptions.py
which returns {"error": ..., "code": ...}.
"""
from rest_framework import status
from rest_framework.response import Response


class SuccessResponse(Response):
    """Wrap data in the {status, data, message} success envelope."""

    def __init__(self, data=None, message: str = "", http_status: int = status.HTTP_200_OK, **kwargs):
        payload = {
            "status": "success",
            "message": message,
            "data": data,
        }
        super().__init__(payload, status=http_status, **kwargs)

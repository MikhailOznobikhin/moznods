from rest_framework import status
from rest_framework.exceptions import APIException


class ValidationError(APIException):
    """Validation error with 400 status."""

    status_code = status.HTTP_400_BAD_REQUEST
    default_detail = "Invalid input."
    default_code = "validation_error"

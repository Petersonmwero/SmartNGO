"""Shared pagination classes."""
from rest_framework.pagination import PageNumberPagination


class StandardPagination(PageNumberPagination):
    """20 items per page; clients may request up to 100 via ?page_size=."""

    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100

"""Case-equivalent search over legacy Erfe, without rewriting stored content."""
from django.db.models import F, Value
from django.db.models.functions import Replace
from .transliteration import ALIASES


def erfe_search_expression(field, query=None):
    expression = F(field)
    if query is not None and not any(0x16EA0 <= ord(c) <= 0x16ED3 for c in query):
        return expression
    for alias, canonical in ALIASES.items():
        expression = Replace(expression, Value(alias), Value(canonical))
    return expression

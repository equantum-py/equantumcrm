"""Parses a published budget such as "USD 3.000–5.000" or "€250 - 750".

Returns None when no currency and amount can be read with confidence: the
engine never guesses a budget.
"""

import re
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation

CURRENCIES = [
    ("USD", r"usd|us\$|u\$s|dolares?|dólares?"),
    ("EUR", r"eur|euros?|€"),
    ("PYG", r"pyg|gs\.?|guaran[ií]es"),
    ("CLP", r"clp|pesos chilenos"),
    ("COP", r"cop|pesos colombianos"),
]
NUMBER = r"\d{1,3}(?:[.,\s]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?"
RANGE = re.compile(rf"({NUMBER})\s*(?:k|mil)?\s*(?:-|–|—|a|hasta)\s*({NUMBER})", re.IGNORECASE)
SINGLE = re.compile(rf"({NUMBER})", re.IGNORECASE)
MULTIPLIER = re.compile(r"\b(\d+(?:[.,]\d+)?)\s*(millones|millon|mill|mm)\b", re.IGNORECASE)


@dataclass(frozen=True)
class Budget:
    currency: str
    min: Decimal
    max: Decimal
    text: str

    def as_dict(self) -> dict:
        return {"currency": self.currency, "min": str(self.min), "max": str(self.max), "text": self.text}


def _number(raw: str) -> Decimal | None:
    value = raw.replace(" ", "")
    if re.fullmatch(r"\d{1,3}(?:[.,]\d{3})+", value):
        value = re.sub(r"[.,]", "", value)
    elif match := re.fullmatch(r"(\d{1,3}(?:[.,]\d{3})+)[.,](\d{1,2})", value):
        value = re.sub(r"[.,]", "", match.group(1)) + "." + match.group(2)
    else:
        value = value.replace(",", ".")
    try:
        return Decimal(value)
    except InvalidOperation:
        return None


def _currency(text: str) -> str | None:
    lowered = text.lower()
    for code, pattern in CURRENCIES:
        if re.search(rf"(?<![a-z]){pattern}(?![a-z])", lowered):
            return code
    return None  # "$" alone is ambiguous between USD, CLP and COP


def parse_budget(text: str | None) -> Budget | None:
    if not text:
        return None
    currency = _currency(text)
    if currency is None:
        return None

    if match := MULTIPLIER.search(text):
        amount = _number(match.group(1))
        if amount is None:
            return None
        amount *= 1_000_000
        return Budget(currency, amount, amount, text.strip())

    if match := RANGE.search(text):
        low, high = _number(match.group(1)), _number(match.group(2))
    elif match := SINGLE.search(text):
        low = high = _number(match.group(1))
    else:
        return None
    if low is None or high is None or low <= 0:
        return None
    if re.search(r"\d\s*k\b", text, re.IGNORECASE):
        low, high = low * 1000, high * 1000
    return Budget(currency, min(low, high), max(low, high), text.strip())

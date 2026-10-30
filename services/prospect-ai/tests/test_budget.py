from decimal import Decimal

import pytest

from app.budget import parse_budget


@pytest.mark.parametrize(
    ("text", "currency", "low", "high"),
    [
        ("USD 3.000–5.000", "USD", "3000", "5000"),
        ("$3,000 - 5,000 USD", "USD", "3000", "5000"),
        ("€250 - 750", "EUR", "250", "750"),
        ("EUR 750-1.500", "EUR", "750", "1500"),
        ("1500 euros", "EUR", "1500", "1500"),
        ("Gs. 5 millones", "PYG", "5000000", "5000000"),
        ("hasta 2.500.000 guaraníes", "PYG", "2500000", "2500000"),
        ("COP 1.200.000 a 2.000.000", "COP", "1200000", "2000000"),
        ("USD 99,50", "USD", "99.50", "99.50"),
        ("EUR 1.234,5", "EUR", "1234.5", "1234.5"),
    ],
)
def test_parses(text, currency, low, high):
    budget = parse_budget(text)
    assert budget is not None
    assert (budget.currency, budget.min, budget.max) == (currency, Decimal(low), Decimal(high))


@pytest.mark.parametrize("text", [None, "", "a convenir", "$500", "presupuesto abierto"])
def test_does_not_guess(text):
    assert parse_budget(text) is None

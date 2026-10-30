"""Synthetic texts only; no real people or posts."""

from datetime import UTC, datetime, timedelta

from app.analyzer import analyze
from app.models import AnalyzeRequest, RubricCriterion

NOW = datetime(2026, 10, 30, 12, tzinfo=UTC)


def run(text, **kwargs):
    return analyze(AnalyzeRequest(source=kwargs.pop("source", "facebook_group"), text=text, **kwargs), now=NOW)


def points(result):
    return {c.key: c.points for c in result.criteria}


def test_hire_request_in_paraguay():
    result = run(
        "Busco quien me haga una tienda online para mi negocio de ropa en Asunción, urgente. "
        "Tengo unos 50 productos y necesito pagos con tarjeta.",
        published_at=NOW - timedelta(hours=5),
        published_at_verified=True,
    )
    assert result.has_commercial_intent
    assert result.services[0].key == "ecommerce"
    assert result.country_guess.value == "PY" and result.country_guess.basis == "inferred"
    scored = points(result)
    assert scored["explicit_intent"] == 25
    assert scored["urgency"] == 15
    assert scored["recency"] == 15
    assert scored["target_market"] == 5
    assert "necesitás" in result.draft_message


def test_service_offer_is_not_intent():
    result = run("Ofrecemos diseño de páginas web y tiendas online. Mirá nuestro portafolio.")
    assert not result.has_commercial_intent
    assert points(result)["explicit_intent"] == 0
    assert result.draft_message is None
    assert result.suggested_next_action.startswith("Descartar")


def test_freelance_platform_post_counts_as_request():
    result = run(
        "MVP web de app educativa con Figma, login y comunidad. Bogotá.",
        source="freelance_other",
        published_budget_text="USD 3.000–5.000",
    )
    assert result.has_commercial_intent
    assert {"app_web", "ux_ui"} <= {s.key for s in result.services}
    assert result.budget == {"currency": "USD", "min": "3000", "max": "5000", "text": "USD 3.000–5.000"}
    assert points(result)["budget"] == 2  # declared but compatibility not evaluated without a rate
    assert points(result)["contact_possible"] == 5
    assert "Puede contarnos" in result.draft_message  # Colombia: usted


def test_missing_data_scores_zero_and_warns():
    result = run("Necesito una web")
    scored = points(result)
    assert scored["recency"] == 0 and scored["budget"] == 0 and scored["target_market"] == 0
    assert "Fecha de publicación no disponible" in result.warnings
    assert result.country_guess.value is None


def test_respects_rubric_maximums_and_unknown_keys():
    rubric = [
        RubricCriterion(key="explicit_intent", max_points=10),
        RubricCriterion(key="economic_value", max_points=20),
    ]
    result = run("Necesitamos una landing page", rubric=rubric)
    assert points(result) == {"explicit_intent": 10, "economic_value": 0}
    assert any("economic_value" in w for w in result.warnings)


def test_only_returns_catalog_services():
    result = run("Necesito SEO y una tienda Shopify", services=["seo"])
    assert [s.key for s in result.services] == ["seo"]


def test_country_hint_is_verified_and_spain_uses_tu():
    result = run("Necesito una tienda Shopify para mi marca", country_hint="es")
    assert result.country_guess.value == "ES" and result.country_guess.basis == "verified"
    assert "Puedes contarnos" in result.draft_message


def test_out_of_market_country():
    result = run("Necesito una web para mi negocio", country_hint="MX")
    assert points(result)["target_market"] == 0


def test_future_date_is_flagged():
    result = run("Necesito una web", published_at=NOW + timedelta(days=2))
    assert points(result)["recency"] == 0
    assert any("futuro" in w for w in result.warnings)


def test_english_detection():
    assert run("We are looking for a developer for our website").language == "en"

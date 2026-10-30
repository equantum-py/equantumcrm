"""Request and response schemas. Field names follow docs/04-integracion-prospect-ai.md."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

Basis = Literal["verified", "inferred"]
ContactKind = Literal["public_comment", "platform_message", "email", "phone", "website", "none"]


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class RubricCriterion(Strict):
    key: str = Field(min_length=1, max_length=60)
    max_points: int = Field(ge=0, le=100)


# Fallback when the caller does not send the rubric. Rails remains the
# authority: it rejects any points above its own maximums.
DEFAULT_RUBRIC = [
    RubricCriterion(key=key, max_points=points)
    for key, points in [
        ("explicit_intent", 25),
        ("service_fit", 20),
        ("urgency", 15),
        ("recency", 15),
        ("clarity", 10),
        ("budget", 5),
        ("target_market", 5),
        ("contact_possible", 5),
    ]
]
DEFAULT_TARGET_COUNTRIES = ["PY", "CL", "CO", "ES"]


class AnalyzeRequest(Strict):
    source: str = Field(min_length=1, max_length=60)
    text: str = Field(min_length=1, max_length=20000)
    original_url: str | None = Field(default=None, max_length=2000)
    country_hint: str | None = Field(default=None, min_length=2, max_length=2)
    published_at: datetime | None = None
    published_at_verified: bool = False
    published_budget_text: str | None = Field(default=None, max_length=200)
    contact_channel_kind: ContactKind | None = None
    rubric: list[RubricCriterion] | None = Field(default=None, max_length=30)
    services: list[str] | None = Field(default=None, max_length=60)
    target_countries: list[str] | None = Field(default=None, max_length=30)

    @field_validator("country_hint")
    @classmethod
    def upper_country(cls, value: str | None) -> str | None:
        return value.upper() if value else value


class CountryGuess(BaseModel):
    value: str | None
    basis: Basis
    reason: str


class ServiceMatch(BaseModel):
    key: str
    confidence: float


class CriterionProposal(BaseModel):
    key: str
    points: int
    basis: Basis
    justification: str


class AnalyzeResponse(BaseModel):
    engine_version: str
    fingerprint: str
    language: str
    country_guess: CountryGuess
    services: list[ServiceMatch]
    has_commercial_intent: bool
    budget: dict | None
    criteria: list[CriterionProposal]
    suggested_next_action: str
    draft_message: str | None
    warnings: list[str]


class ContactChannel(Strict):
    kind: ContactKind
    value: str | None = Field(default=None, max_length=200)


class Evidence(Strict):
    kind: Literal["post_excerpt", "page_snapshot", "note"] = "post_excerpt"
    captured_at: datetime
    excerpt: str | None = Field(default=None, max_length=2000)


class IngestRequest(Strict):
    source: str = Field(min_length=1, max_length=60)
    text_excerpt: str = Field(min_length=1, max_length=20000)
    title: str | None = Field(default=None, max_length=200)
    original_url: str | None = Field(default=None, max_length=2000)
    external_id: str | None = Field(default=None, max_length=120)
    published_at: datetime | None = None
    published_at_verified: bool = False
    country_hint: str | None = Field(default=None, min_length=2, max_length=2)
    author_display_name: str | None = Field(default=None, max_length=120)
    contact_channel: ContactChannel | None = None
    published_budget_text: str | None = Field(default=None, max_length=200)
    competition_count: int | None = Field(default=None, ge=0)
    deadline_at: datetime | None = None
    listing_closed: bool = False
    captured_by: str = Field(default="prospect-ai", max_length=80)
    evidence: list[Evidence] = Field(default_factory=list, max_length=5)
    rubric: list[RubricCriterion] | None = Field(default=None, max_length=30)
    services: list[str] | None = Field(default=None, max_length=60)
    target_countries: list[str] | None = Field(default=None, max_length=30)

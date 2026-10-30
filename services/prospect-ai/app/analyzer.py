"""Rule engine: proposes services, intent and per-criterion points.

It only proposes. Rails stores the result as pending review and a person
decides. When data is missing the points are 0 and the justification says
so; the engine never assumes a value it cannot read in the text.
"""

from datetime import UTC, datetime

from . import ENGINE_VERSION
from .budget import parse_budget
from .fingerprint import fingerprint, is_http_url
from .models import (
    DEFAULT_RUBRIC,
    DEFAULT_TARGET_COUNTRIES,
    AnalyzeRequest,
    AnalyzeResponse,
    CountryGuess,
    CriterionProposal,
    ServiceMatch,
)
from .rules import (
    COUNTRY_PATTERNS,
    ENGLISH_HINTS,
    HIRE_PATTERN,
    OFFER_PATTERN,
    PLATFORM_SOURCES,
    SCOPE_PATTERN,
    SERVICE_PATTERNS,
    SOON_PATTERN,
    SPANISH_HINTS,
    URGENT_PATTERN,
    all_matches,
    first_match,
    fold,
)

SERVICE_NAMES = {
    "shopify": "una tienda en Shopify",
    "ecommerce": "una tienda online",
    "migracion_ecommerce": "migrar una tienda",
    "web_corporativa": "un sitio web",
    "landing": "una landing page",
    "app_web": "una aplicación",
    "sistema_empresarial": "un sistema de gestión",
    "integraciones": "una integración",
    "seo": "posicionamiento web",
    "google_ads": "campañas en Google Ads",
    "meta_ads": "campañas en Meta",
    "consultoria_comercial": "estrategia comercial",
    "consultoria_ecommerce": "consultoría de ecommerce",
    "ux_ui": "diseño UX/UI",
    "cro": "mejorar la conversión",
    "analitica_ga4": "analítica web",
    "automatizacion": "automatización de procesos",
    "ia_negocios": "una solución con IA",
    "soporte": "mantenimiento web",
}

# Second-person forms by market: voseo in Paraguay, tú in Spain and Chile,
# usted in Colombia and when the country is unknown.
DRAFT_FORMS = {
    "PY": ("necesitás", "¿Podés contarnos", "tenés", "te proponemos"),
    "ES": ("necesitas", "¿Puedes contarnos", "tienes", "te proponemos"),
    "CL": ("necesitas", "¿Puedes contarnos", "tienes", "te proponemos"),
}
DEFAULT_FORMS = ("necesita", "¿Puede contarnos", "tiene", "le proponemos")


class Analysis:
    def __init__(self, request: AnalyzeRequest, now: datetime | None = None):
        self.request = request
        self.now = now or datetime.now(UTC)
        self.folded = fold(request.text)
        self.warnings: list[str] = []
        allowed = set(request.services) if request.services is not None else set(SERVICE_PATTERNS)
        self.services = self._services(allowed)
        self.hire = first_match(HIRE_PATTERN, self.folded)
        self.offer = first_match(OFFER_PATTERN, self.folded)
        self.on_platform = request.source in PLATFORM_SOURCES
        self.has_intent = bool((self.hire or self.on_platform) and not (self.offer and not self.hire))
        self.country = self._country()
        self.budget = parse_budget(request.published_budget_text) or parse_budget(request.text)
        self.targets = set(request.target_countries or DEFAULT_TARGET_COUNTRIES)

    def _services(self, allowed: set[str]) -> list[ServiceMatch]:
        found = []
        for key, pattern in SERVICE_PATTERNS.items():
            if key not in allowed:
                continue
            hits = all_matches(pattern, self.folded)
            if hits:
                found.append(ServiceMatch(key=key, confidence=round(min(0.95, 0.5 + 0.15 * len(hits)), 2)))
        return sorted(found, key=lambda s: -s.confidence)[:3]

    def _country(self) -> CountryGuess:
        if self.request.country_hint:
            return CountryGuess(value=self.request.country_hint, basis="verified", reason="indicado en la captura")
        for code, pattern in COUNTRY_PATTERNS.items():
            if hit := first_match(pattern, self.folded):
                return CountryGuess(value=code, basis="inferred", reason=f"menciona '{hit}'")
        return CountryGuess(value=None, basis="inferred", reason="el texto no indica el país")

    def language(self) -> str:
        spanish = len(all_matches(SPANISH_HINTS, self.folded))
        english = len(all_matches(ENGLISH_HINTS, self.folded))
        if spanish == english == 0:
            return "desconocido"
        return "es" if spanish >= english else "en"

    # Each rule returns (points as a fraction of the maximum, basis, justification).
    def rule_explicit_intent(self):
        if self.offer and not self.hire:
            return 0, "verified", f"Es una oferta de servicios ('{self.offer}'), no un pedido"
        if self.hire:
            return 1, "verified", f"Pide el servicio de forma explícita ('{self.hire}')"
        if self.on_platform:
            return 1, "verified", "Publicado como proyecto en una plataforma freelance"
        return 0, "inferred", "No hay una frase que pida contratar un servicio"

    def rule_service_fit(self):
        if not self.services:
            return 0, "inferred", "No coincide con servicios del catálogo"
        top = self.services[0]
        return top.confidence, "inferred", f"Coincide con {top.key} (confianza {top.confidence})"

    def rule_urgency(self):
        if hit := first_match(URGENT_PATTERN, self.folded):
            return 1, "verified", f"Indica urgencia ('{hit}')"
        if hit := first_match(SOON_PATTERN, self.folded):
            return 0.5, "verified", f"Indica un plazo cercano ('{hit}')"
        return 0, "inferred", "No menciona plazo"

    def rule_recency(self):
        published = self.request.published_at
        if published is None:
            self.warnings.append("Fecha de publicación no disponible")
            return 0, "inferred", "Fecha de publicación no disponible"
        if published.tzinfo is None:
            published = published.replace(tzinfo=UTC)
        days = (self.now - published).total_seconds() / 86400
        basis = "verified" if self.request.published_at_verified else "inferred"
        if days < 0:
            self.warnings.append("La fecha de publicación está en el futuro")
            return 0, "inferred", "Fecha de publicación inconsistente"
        fraction = 1 if days <= 2 else 2 / 3 if days <= 7 else 1 / 3 if days <= 30 else 0
        return fraction, basis, f"Publicado hace {int(days)} día(s)"

    def rule_clarity(self):
        words = len(self.folded.split())
        scope = set(all_matches(SCOPE_PATTERN, self.folded))
        if words >= 60 and len(scope) >= 2:
            return 1, "inferred", f"Describe alcance concreto ({', '.join(sorted(scope)[:4])})"
        if words >= 25:
            return 0.5, "inferred", "Describe la necesidad, pero sin alcance detallado"
        return 0, "inferred", "Texto demasiado breve para entender el alcance"

    def rule_budget(self):
        if self.budget is None:
            return 0, "verified", "No publica un presupuesto legible"
        low, high = self.budget.min, self.budget.max
        amount = f"{low}" if low == high else f"{low}–{high}"
        return (
            0.5,
            "verified",
            (
                f"Publica {self.budget.currency} {amount}; "
                "la compatibilidad requiere una tarifa aprobada y no se evalúa aquí"
            ),
        )

    def rule_target_market(self):
        if self.country.value is None:
            return 0, "inferred", "País no determinado"
        if self.country.value in self.targets:
            return 1, self.country.basis, f"{self.country.value} es mercado objetivo ({self.country.reason})"
        return 0, self.country.basis, f"{self.country.value} no es mercado objetivo"

    def rule_contact_possible(self):
        kind = self.request.contact_channel_kind
        if self.on_platform:
            return 1, "verified", "Se responde dentro de la plataforma"
        if kind and kind != "none":
            return 1, "verified", f"Canal de contacto legítimo: {kind}"
        if self.request.original_url and is_http_url(self.request.original_url):
            return 0.5, "inferred", "Se puede responder en la publicación original"
        return 0, "inferred", "No hay un canal de contacto identificado"

    def criteria(self) -> list[CriterionProposal]:
        proposals = []
        for criterion in self.request.rubric or DEFAULT_RUBRIC:
            rule = getattr(self, f"rule_{criterion.key}", None)
            if rule is None:
                self.warnings.append(f"El motor no tiene regla para el criterio {criterion.key}; se propone 0")
                fraction, basis, reason = 0, "inferred", "Criterio sin regla en el motor"
            else:
                fraction, basis, reason = rule()
            points = max(0, min(criterion.max_points, round(criterion.max_points * fraction)))
            proposals.append(CriterionProposal(key=criterion.key, points=points, basis=basis, justification=reason))
        return proposals

    def next_action(self) -> str:
        if not self.has_intent:
            return "Descartar: no hay intención de contratación"
        if not self.services:
            return "Revisar a mano: no coincide con el catálogo de servicios"
        if self.on_platform:
            return "Revisar el proyecto en la plataforma y preparar propuesta para aprobación de Dirección"
        return "Verificar la publicación y responder por el canal público"

    def draft(self) -> str | None:
        if not self.has_intent or not self.services:
            return None
        subject = SERVICE_NAMES.get(self.services[0].key, "un proyecto digital")
        need, ask, have, offer = DRAFT_FORMS.get(self.country.value, DEFAULT_FORMS)
        return (
            f"Hola, vi la publicación sobre {subject}. En eQuantum trabajamos este tipo de proyectos "
            f"y queremos entender bien lo que {need}. {ask} el alcance y el plazo que {have} en mente? "
            f"Con eso {offer} un plan concreto."
        )

    def result(self) -> AnalyzeResponse:
        criteria = self.criteria()
        if not self.request.original_url:
            self.warnings.append("Sin enlace original: la huella usa el texto")
        elif not is_http_url(self.request.original_url):
            self.warnings.append("El enlace no es una URL http(s) válida: la huella usa el texto")
        return AnalyzeResponse(
            engine_version=ENGINE_VERSION,
            fingerprint=fingerprint(self.request.source, self.request.original_url, self.request.text),
            language=self.language(),
            country_guess=self.country,
            services=self.services,
            has_commercial_intent=self.has_intent,
            budget=self.budget.as_dict() if self.budget else None,
            criteria=criteria,
            suggested_next_action=self.next_action(),
            draft_message=self.draft(),
            warnings=self.warnings,
        )


def analyze(request: AnalyzeRequest, now: datetime | None = None) -> AnalyzeResponse:
    return Analysis(request, now).result()

"""Rule-based detection for Spanish (PY, CL, CO, ES) commercial requests.

Patterns run over accent-free lowercase text, so "página" and "pagina"
match the same rule. Every match keeps the phrase found, which becomes the
evidence quoted in the justification.
"""

import re
import unicodedata


def fold(text: str | None) -> str:
    decomposed = unicodedata.normalize("NFKD", (text or "").lower())
    return "".join(c for c in decomposed if not unicodedata.combining(c))


def _compile(words: list[str]) -> re.Pattern:
    return re.compile(r"\b(" + "|".join(words) + r")\b")


SERVICE_PATTERNS: dict[str, re.Pattern] = {
    key: _compile(words)
    for key, words in {
        "shopify": [r"shopify( plus)?"],
        "ecommerce": [
            r"tienda (online|virtual|en linea|web)",
            r"e-?commerce",
            r"woocommerce",
            r"carrito de compras?",
            r"vender (online|en linea|por internet)",
            r"catalogo (online|web)",
            r"pasarela de pagos?",
        ],
        "migracion_ecommerce": [r"migr(ar|acion) (la |mi |de )?(tienda|shopify|woocommerce|prestashop|magento)"],
        "web_corporativa": [
            r"pagina web",
            r"sitio web",
            r"web (corporativa|institucional)",
            r"wordpress",
            r"desarrollo web",
        ],
        "landing": [r"landing( page)?", r"pagina de aterrizaje"],
        "app_web": [
            r"app",
            r"aplicacion( web| movil)?",
            r"mvp",
            r"plataforma (web|online|educativa)",
            r"sistema web",
            r"frontend",
            r"backend",
        ],
        "sistema_empresarial": [
            r"erp",
            r"crm",
            r"sistema de (gestion|inventario|facturacion|ventas)",
            r"inventario",
            r"facturacion",
            r"software a medida",
            r"sistema a medida",
        ],
        "integraciones": [r"integra(r|cion)( de)? (api|apis|pagos|sistemas)", r"api", r"webhooks?"],
        "seo": [r"seo", r"posicionamiento (web|en google|organico)"],
        "google_ads": [r"google ads", r"adwords", r"sem", r"campanas? en google"],
        "meta_ads": [
            r"meta ads",
            r"facebook ads",
            r"instagram ads",
            r"publicidad en (facebook|instagram|redes)",
            r"pauta (digital|en redes)",
        ],
        "consultoria_comercial": [
            r"consultor(ia|a)? comercial",
            r"estrategia (comercial|de ventas)",
            r"plan comercial",
        ],
        "consultoria_ecommerce": [r"consultor(ia|a)? (de |en )?e-?commerce", r"asesor(ia)? (de |en )?tienda online"],
        "ux_ui": [r"ux", r"ui", r"figma", r"diseno de (interfaz|interfaces|experiencia)", r"prototipo", r"wireframes?"],
        "cro": [r"cro", r"tasa de conversion", r"optimizar (la )?conversion(es)?"],
        "analitica_ga4": [r"ga4", r"google analytics", r"analitica", r"tag manager", r"pixel( de meta| de facebook)?"],
        "automatizacion": [r"n8n", r"zapier", r"make\.com", r"automatiza(r|cion)"],
        "ia_negocios": [r"inteligencia artificial", r"ia", r"chatbots?", r"gpt", r"openai", r"agente de ia"],
        "soporte": [r"mantenimiento", r"soporte tecnico", r"actualizar (mi |la )?(web|pagina|tienda)"],
    }.items()
}

HIRE_PATTERN = _compile(
    [
        r"busco",
        r"buscamos",
        r"se busca",
        r"necesito",
        r"necesitamos",
        r"requiero",
        r"requerimos",
        r"quien (me |nos )?(haga|pueda hacer|desarrolle|arme)",
        r"alguien que",
        r"cotiza(r|cion)",
        r"presupuesto para",
        r"contratar",
        r"recomienden",
        r"me recomiendan",
        r"estoy buscando",
        r"estamos buscando",
        r"quiero (una|un|crear|hacer|lanzar)",
        r"queremos (una|un|crear|hacer|lanzar)",
    ]
)
OFFER_PATTERN = _compile(
    [
        r"ofrezco",
        r"ofrecemos",
        r"brindo",
        r"brindamos",
        r"mis servicios",
        r"nuestros servicios",
        r"realizo",
        r"realizamos",
        r"hago paginas",
        r"hacemos paginas",
        r"contactame",
        r"escribime para",
        r"portafolio",
        r"promo(cion)?",
    ]
)
URGENT_PATTERN = _compile(
    [
        r"urgente",
        r"urgencia",
        r"para (hoy|manana|ya)",
        r"inmediat[oa]",
        r"lo antes posible",
        r"cuanto antes",
        r"esta semana",
        r"asap",
    ]
)
SOON_PATTERN = _compile([r"pronto", r"proxim[oa] (semana|mes)", r"este mes", r"en (\d+|dos|tres) semanas"])
SCOPE_PATTERN = _compile(
    [
        r"funcionalidad(es)?",
        r"modulos?",
        r"entregables?",
        r"requisitos",
        r"alcance",
        r"pantallas?",
        r"integracion",
        r"pagos?",
        r"envios?",
        r"productos?",
        r"usuarios?",
        r"login",
        r"panel",
        r"secciones?",
        r"catalogo",
    ]
)

COUNTRY_PATTERNS: dict[str, re.Pattern] = {
    "PY": _compile(
        [
            r"paraguay",
            r"asuncion",
            r"ciudad del este",
            r"encarnacion",
            r"san lorenzo",
            r"luque",
            r"fernando de la mora",
            r"guaranies",
            r"gs\.",
        ]
    ),
    "CL": _compile(
        [
            r"chile",
            r"santiago de chile",
            r"valparaiso",
            r"vina del mar",
            r"concepcion",
            r"antofagasta",
            r"pesos chilenos",
            r"clp",
        ]
    ),
    "CO": _compile(
        [
            r"colombia",
            r"bogota",
            r"medellin",
            r"cali",
            r"barranquilla",
            r"cartagena",
            r"bucaramanga",
            r"pesos colombianos",
            r"cop",
        ]
    ),
    "ES": _compile(
        [
            r"espana",
            r"madrid",
            r"barcelona",
            r"valencia",
            r"sevilla",
            r"malaga",
            r"zaragoza",
            r"bilbao",
            r"euros?",
            r"eur",
        ]
    ),
}

PLATFORM_SOURCES = {"freelance_other", "workana", "upwork", "malt"}

SPANISH_HINTS = _compile([r"el", r"la", r"de", r"que", r"para", r"una", r"con", r"por", r"mi", r"los"])
ENGLISH_HINTS = _compile([r"the", r"and", r"for", r"with", r"need", r"looking", r"website", r"our", r"we"])


def first_match(pattern: re.Pattern, folded: str) -> str | None:
    match = pattern.search(folded)
    return match.group(0) if match else None


def all_matches(pattern: re.Pattern, folded: str) -> list[str]:
    return [m.group(0) for m in pattern.finditer(folded)]

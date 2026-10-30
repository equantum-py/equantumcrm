"""URL canonicalization and lead fingerprint.

Must match apps/crm/app/services/url_canonicalizer.rb and
Lead.fingerprint_for exactly; contracts/fingerprint-vectors.json is the
shared test suite for both sides.
"""

import hashlib
import re
import unicodedata
from urllib.parse import parse_qsl, quote_plus, urlsplit

TRACKING_PARAMS = re.compile(
    r"\A(utm_.*|fbclid|gclid|mibextid|rdid|share_url|ref|refid|__cft__.*|__tn__.*|_rdr|sfnsn|igshid|trk|trackingId)\Z"
)
HOST_PREFIXES = re.compile(r"\A(www|m|mbasic|web|touch)\.")
# Ruby's URI.parse (RFC 3986) rejects anything outside this set.
RFC3986_CHARS = re.compile(r"\A[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+\Z")


def _split(value: str | None):
    text = (value or "").strip()
    if not text or not RFC3986_CHARS.match(text):
        return None
    try:
        parts = urlsplit(text)
    except ValueError:
        return None
    if parts.scheme.lower() not in ("http", "https") or not parts.hostname:
        return None
    return parts


def is_http_url(value: str | None) -> bool:
    return _split(value) is not None


def _encode_component(value: str) -> str:
    # Same output as Ruby's URI.encode_www_form_component.
    return quote_plus(value, safe="*").replace("~", "%7E")


def canonical_url(value: str | None) -> str | None:
    parts = _split(value)
    if parts is None:
        return None
    host = HOST_PREFIXES.sub("", parts.hostname.lower(), count=1)
    path = re.sub(r"/+\Z", "", parts.path)
    params = sorted(
        (key, val) for key, val in parse_qsl(parts.query, keep_blank_values=True) if not TRACKING_PARAMS.match(key)
    )
    query = "?" + "&".join(f"{_encode_component(k)}={_encode_component(v)}" for k, v in params) if params else ""
    return f"{host}{path}{query}"


def normalize_text(text: str | None) -> str:
    """Lowercase and keep only letters and digits, like the Rails fingerprint."""
    chars = (c if unicodedata.category(c)[0] in ("L", "N") else " " for c in (text or "").lower())
    return " ".join("".join(chars).split())


def fingerprint(source_key: str, url: str | None, text: str | None) -> str:
    basis = canonical_url(url) or f"{source_key}|{normalize_text(text)}"
    return "sha256:" + hashlib.sha256(basis.encode("utf-8")).hexdigest()

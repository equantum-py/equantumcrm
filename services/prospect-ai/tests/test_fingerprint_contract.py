import json
from pathlib import Path

import pytest

from app.fingerprint import canonical_url, fingerprint, is_http_url

VECTORS = json.loads((Path(__file__).resolve().parents[3] / "contracts" / "fingerprint-vectors.json").read_text())


@pytest.mark.parametrize("case", VECTORS["cases"], ids=lambda c: c["name"])
def test_matches_rails(case):
    assert fingerprint(case["source"], case["url"], case["text"]) == case["expected"]


def test_rejects_non_http():
    assert not is_http_url("javascript:alert(1)")
    assert not is_http_url("https://")
    assert not is_http_url("https://example.com/con espacio")


def test_keeps_non_tracking_params_sorted():
    assert canonical_url("https://www.example.com/a/?z=1&a=x+y&utm_medium=q") == "example.com/a?a=x+y&z=1"

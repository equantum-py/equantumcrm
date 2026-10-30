import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import app, get_settings

TOKEN = "token-de-prueba-prospect-ai"


@pytest.fixture
def settings():
    return Settings(token=TOKEN, crm_api_url="http://crm.test", crm_api_token="token-crm-prueba", crm_backoff=0)


@pytest.fixture
def client(settings):
    app.dependency_overrides[get_settings] = lambda: settings
    yield TestClient(app, raise_server_exceptions=False)
    app.dependency_overrides.clear()


@pytest.fixture
def auth():
    return {"Authorization": f"Bearer {TOKEN}"}

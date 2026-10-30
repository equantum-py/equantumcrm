"""Settings from environment variables. Secrets never have defaults."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    token: str | None
    crm_api_url: str | None
    crm_api_token: str | None
    crm_timeout: float = 10.0
    crm_attempts: int = 3
    crm_backoff: float = 0.5

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            token=os.environ.get("PROSPECT_AI_TOKEN") or None,
            crm_api_url=os.environ.get("CRM_API_URL") or None,
            crm_api_token=os.environ.get("CRM_API_TOKEN") or None,
            crm_timeout=float(os.environ.get("CRM_TIMEOUT", "10")),
            crm_attempts=int(os.environ.get("CRM_ATTEMPTS", "3")),
            crm_backoff=float(os.environ.get("CRM_BACKOFF", "0.5")),
        )

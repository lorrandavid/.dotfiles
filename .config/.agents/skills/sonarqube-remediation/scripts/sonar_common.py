#!/usr/bin/env python3

from __future__ import annotations

import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Callable, Final, NoReturn


DEFAULT_TIMEOUT_SECONDS: Final[int] = 30


class SonarError(Exception):
    pass


@dataclass(frozen=True)
class SonarConfig:
    base_url: str
    token: str


def die(message: str) -> NoReturn:
    raise SonarError(message)


def read_config() -> SonarConfig:
    base_url = os.environ.get("SONARQUBE_URL", "").strip()
    token = os.environ.get("SONARQUBE_TOKEN", "").strip()
    if not base_url:
        die("Missing SONARQUBE_URL environment variable")
    if not token:
        die("Missing SONARQUBE_TOKEN environment variable")
    return SonarConfig(base_url=base_url.rstrip("/"), token=token)


def auth_headers(config: SonarConfig) -> dict[str, str]:
    encoded_token = base64.b64encode(f"{config.token}:".encode("utf-8")).decode("ascii")
    return {"Authorization": f"Basic {encoded_token}"}


def parse_csv(value: str | None) -> list[str]:
    if value is None:
        return []
    return [item.strip() for item in value.split(",") if item.strip()]


def build_query(params: list[tuple[str, str | None]]) -> str:
    filtered: list[tuple[str, str]] = []
    for key, value in params:
        if value is not None and value != "":
            filtered.append((key, value))
    return urllib.parse.urlencode(filtered)


def api_get(config: SonarConfig, path: str, params: list[tuple[str, str | None]]) -> tuple[dict[str, object], dict[str, str]]:
    query = build_query(params)
    url = f"{config.base_url}{path}"
    if query:
        url = f"{url}?{query}"

    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            **auth_headers(config),
        },
        method="GET",
    )

    try:
        with urllib.request.urlopen(request, timeout=DEFAULT_TIMEOUT_SECONDS) as response:
            charset = response.headers.get_content_charset("utf-8")
            body = response.read().decode(charset)
            payload = json.loads(body)
            if not isinstance(payload, dict):
                die(f"Unexpected JSON payload from {path}")
            headers = {key.lower(): value for key, value in response.headers.items()}
            return payload, headers
    except urllib.error.HTTPError as error:
        charset = error.headers.get_content_charset("utf-8")
        body = error.read().decode(charset)
        detail = body.strip() or error.reason
        die(f"SonarQube API request failed for {path}: HTTP {error.code}: {detail}")
    except urllib.error.URLError as error:
        die(f"Unable to reach SonarQube at {config.base_url}: {error.reason}")
    except json.JSONDecodeError as error:
        die(f"Invalid JSON response from SonarQube for {path}: {error}")


def expect_dict(value: object, context: str) -> dict[str, object]:
    if isinstance(value, dict):
        return value
    die(f"Expected object for {context}")


def expect_list(value: object, context: str) -> list[object]:
    if isinstance(value, list):
        return value
    die(f"Expected array for {context}")


def optional_str(value: object) -> str | None:
    if isinstance(value, str):
        return value
    return None


def required_str(value: object, context: str) -> str:
    parsed = optional_str(value)
    if parsed is None:
        die(f"Expected string for {context}")
    return parsed


def iso_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def json_dump(payload: dict[str, object]) -> None:
    sys.stdout.write(json.dumps(payload, indent=2, sort_keys=True))
    sys.stdout.write("\n")


def main_guard(main_fn: Callable[[], None]) -> None:
    try:
        main_fn()
    except SonarError as error:
        sys.stderr.write(f"Error: {error}\n")
        raise SystemExit(1) from error

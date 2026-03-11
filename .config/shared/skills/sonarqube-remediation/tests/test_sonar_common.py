import importlib.util
import os
import sys
import unittest
from types import ModuleType
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parents[1] / "scripts"


def load_module(module_name: str, file_name: str) -> ModuleType:
    spec = importlib.util.spec_from_file_location(module_name, SCRIPT_DIR / file_name)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load module {module_name}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


sonar_common = load_module("sonar_common", "sonar_common.py")
auth_headers = sonar_common.auth_headers
read_config = sonar_common.read_config


class SonarCommonTests(unittest.TestCase):
    def setUp(self) -> None:
        self.original_env = os.environ.copy()

    def tearDown(self) -> None:
        os.environ.clear()
        os.environ.update(self.original_env)

    def test_read_config_uses_expected_env_vars(self) -> None:
        os.environ["SONARQUBE_URL"] = "https://sonarqube.example.com"
        os.environ["SONARQUBE_TOKEN"] = "secret"

        config = read_config()

        self.assertEqual(config.base_url, "https://sonarqube.example.com")
        self.assertEqual(config.token, "secret")

    def test_auth_headers_use_token_basic_auth(self) -> None:
        os.environ["SONARQUBE_URL"] = "https://sonarqube.example.com"
        os.environ["SONARQUBE_TOKEN"] = "secret"

        config = read_config()

        self.assertEqual(auth_headers(config), {"Authorization": "Basic c2VjcmV0Og=="})


if __name__ == "__main__":
    unittest.main()

import argparse
import importlib.util
import sys
import unittest
from types import ModuleType
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parents[1] / "scripts"
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))


def load_module(module_name: str, file_name: str) -> ModuleType:
    spec = importlib.util.spec_from_file_location(module_name, SCRIPT_DIR / file_name)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load module {module_name}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


load_module("sonar_common", "sonar_common.py")
sonar_fetch_issues = load_module("sonar_fetch_issues", "sonar_fetch_issues.py")
issue_search_params = sonar_fetch_issues.issue_search_params


class IssueSearchParamsTests(unittest.TestCase):
    def test_issue_search_scopes_by_component_keys(self) -> None:
        args = argparse.Namespace(
            project_key="my-project",
            branch=None,
            pull_request=None,
            types="BUG",
            severities=None,
            statuses="OPEN",
            resolved="false",
            assignees=None,
            created_after=None,
            languages=None,
        )

        params = dict(issue_search_params(args, 1, 100))

        self.assertEqual(params["componentKeys"], "my-project")
        self.assertNotIn("projects", params)
        self.assertEqual(params["types"], "BUG")
        self.assertEqual(params["statuses"], "OPEN")
        self.assertEqual(params["ps"], "100")


if __name__ == "__main__":
    unittest.main()

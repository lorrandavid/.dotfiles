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
sonar_fetch_duplications = load_module("sonar_fetch_duplications", "sonar_fetch_duplications.py")
calculate_removal_target = sonar_fetch_duplications.calculate_removal_target
clamp_buffer_percent = sonar_fetch_duplications.clamp_buffer_percent
clamp_page_size = sonar_fetch_duplications.clamp_page_size
component_tree_params = sonar_fetch_duplications.component_tree_params
resolve_duplication_files = sonar_fetch_duplications.resolve_duplication_files
summarize_duplication_block = sonar_fetch_duplications.summarize_duplication_block


class ClampTests(unittest.TestCase):
    def test_clamp_buffer_percent_within_range(self) -> None:
        self.assertEqual(clamp_buffer_percent(20), 20)

    def test_clamp_buffer_percent_below_zero(self) -> None:
        self.assertEqual(clamp_buffer_percent(-5), 0)

    def test_clamp_buffer_percent_above_hundred(self) -> None:
        self.assertEqual(clamp_buffer_percent(150), 100)

    def test_clamp_page_size_within_range(self) -> None:
        self.assertEqual(clamp_page_size(50), 50)

    def test_clamp_page_size_below_one(self) -> None:
        self.assertEqual(clamp_page_size(0), 1)

    def test_clamp_page_size_above_five_hundred(self) -> None:
        self.assertEqual(clamp_page_size(999), 500)


class CalculateRemovalTargetTests(unittest.TestCase):
    def test_basic_removal_with_buffer(self) -> None:
        result = calculate_removal_target(
            total_duplicated_lines=500,
            target_density=3.0,
            total_loc=10000,
            buffer_percent=20,
        )
        # Target dup lines = floor(3.0 / 100 * 10000) = 300
        # Raw to remove = 500 - 300 = 200
        # With 20% buffer = ceil(200 * 1.2) = 240
        self.assertEqual(result["total_duplicated_lines"], 500)
        self.assertEqual(result["total_loc"], 10000)
        self.assertEqual(result["target_duplicated_lines"], 300)
        self.assertEqual(result["raw_lines_to_remove"], 200)
        self.assertEqual(result["buffer_percent"], 20)
        self.assertEqual(result["effective_lines_to_remove"], 240)

    def test_zero_total_loc(self) -> None:
        result = calculate_removal_target(
            total_duplicated_lines=0,
            target_density=0.0,
            total_loc=0,
            buffer_percent=20,
        )
        self.assertEqual(result["effective_lines_to_remove"], 0)
        self.assertEqual(result["current_density_percent"], 0)

    def test_no_buffer(self) -> None:
        result = calculate_removal_target(
            total_duplicated_lines=100,
            target_density=0.0,
            total_loc=1000,
            buffer_percent=0,
        )
        # Target dup lines = 0, raw = 100, buffer 0% => 100
        self.assertEqual(result["effective_lines_to_remove"], 100)

    def test_effective_capped_at_total(self) -> None:
        result = calculate_removal_target(
            total_duplicated_lines=50,
            target_density=0.0,
            total_loc=100,
            buffer_percent=100,
        )
        # Raw = 50, with 100% buffer = 100, but capped at 50
        self.assertEqual(result["effective_lines_to_remove"], 50)

    def test_already_below_target(self) -> None:
        result = calculate_removal_target(
            total_duplicated_lines=10,
            target_density=5.0,
            total_loc=1000,
            buffer_percent=20,
        )
        # Target dup lines = 50, current = 10, raw = 0
        self.assertEqual(result["raw_lines_to_remove"], 0)
        self.assertEqual(result["effective_lines_to_remove"], 0)

    def test_density_calculation(self) -> None:
        result = calculate_removal_target(
            total_duplicated_lines=250,
            target_density=2.0,
            total_loc=5000,
            buffer_percent=10,
        )
        self.assertEqual(result["current_density_percent"], 5.0)


class ComponentTreeParamsTests(unittest.TestCase):
    def test_sorts_by_duplicated_lines_descending(self) -> None:
        params = dict(component_tree_params("my-project", None, None, 1, 50))

        self.assertEqual(params["component"], "my-project")
        self.assertEqual(params["s"], "metric")
        self.assertEqual(params["metricSort"], "duplicated_lines")
        self.assertEqual(params["asc"], "false")
        self.assertEqual(params["qualifiers"], "FIL")
        self.assertEqual(params["ps"], "50")

    def test_includes_branch_when_set(self) -> None:
        params = dict(component_tree_params("my-project", "develop", None, 1, 50))
        self.assertEqual(params["branch"], "develop")

    def test_includes_pull_request_when_set(self) -> None:
        params = dict(component_tree_params("my-project", None, "42", 1, 50))
        self.assertEqual(params["pullRequest"], "42")


class ResolveDuplicationFilesTests(unittest.TestCase):
    def test_resolves_ref_map(self) -> None:
        raw_files: dict[str, object] = {
            "1": {"key": "proj:src/a.ts", "name": "a.ts", "projectName": "Proj"},
            "2": {"key": "proj:src/b.ts", "name": "b.ts", "projectName": "Proj"},
        }
        result = resolve_duplication_files(raw_files)

        self.assertEqual(result["1"]["key"], "proj:src/a.ts")
        self.assertEqual(result["1"]["name"], "a.ts")
        self.assertEqual(result["2"]["key"], "proj:src/b.ts")


class SummarizeDuplicationBlockTests(unittest.TestCase):
    def test_maps_ref_to_component(self) -> None:
        ref_map = {
            "1": {"key": "proj:src/a.ts", "name": "a.ts", "project_name": "Proj"},
        }
        raw_block = {"_ref": "1", "from": 10, "size": 30}

        result = summarize_duplication_block(raw_block, ref_map)

        self.assertEqual(result["component_key"], "proj:src/a.ts")
        self.assertEqual(result["component_name"], "a.ts")
        self.assertEqual(result["from_line"], 10)
        self.assertEqual(result["size"], 30)

    def test_missing_ref_returns_none_keys(self) -> None:
        ref_map: dict[str, dict[str, object]] = {}
        raw_block = {"_ref": "99", "from": 1, "size": 5}

        result = summarize_duplication_block(raw_block, ref_map)

        self.assertIsNone(result["component_key"])
        self.assertIsNone(result["component_name"])


if __name__ == "__main__":
    unittest.main()

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).parents[1] / "scripts" / "compare_ado_tags.py"
SPEC = importlib.util.spec_from_file_location("compare_ado_tags", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class Repository:
    def __init__(self, path: Path):
        self.path = path
        self.run("init", "--quiet")
        self.run("config", "user.email", "test@example.com")
        self.run("config", "user.name", "Test")

    def run(self, *arguments: str) -> str:
        return subprocess.check_output(
            ["git", "-C", str(self.path), *arguments], text=True
        ).strip()

    def write_commit(self, content: str, message: str) -> str:
        (self.path / "file.txt").write_text(content, encoding="utf-8")
        self.run("add", "file.txt")
        self.run("commit", "--quiet", "-m", message)
        return self.run("rev-parse", "HEAD")


class OutputDecodingTests(unittest.TestCase):
    def test_decodes_utf8_output(self):
        encoded = "Recálculo".encode("utf-8")

        self.assertEqual("Recálculo", MODULE.decode_command_output(encoded))

    def test_falls_back_to_windows_1252_without_replacement_characters(self):
        self.assertEqual("Recálculo", MODULE.decode_command_output(b"Rec\xe1lculo"))

    def test_command_capture_preserves_windows_1252_output(self):
        command = [
            sys.executable,
            "-c",
            "import os; os.write(1, b'Rec\\xe1lculo')",
        ]

        self.assertEqual("Recálculo", MODULE.run(command).stdout)


class PatchEquivalenceTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.repo = Repository(Path(self.temp_dir.name))

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_cherry_picked_patch_is_not_effectively_new(self):
        root = self.repo.write_commit("root\n", "root")
        self.repo.run("checkout", "--quiet", "-b", "develop")
        original = self.repo.write_commit("root\nchange\n", "change")

        self.repo.run("checkout", "--quiet", "-b", "release", root)
        (self.repo.path / "release.txt").write_text("release\n", encoding="utf-8")
        self.repo.run("add", "release.txt")
        self.repo.run("commit", "--quiet", "-m", "release setup")
        self.repo.run("cherry-pick", "--quiet", original)
        picked = self.repo.run("rev-parse", "HEAD")
        self.repo.run("tag", "base")

        self.repo.run("merge", "--quiet", "--no-ff", "develop", "-m", "merge develop")
        merge = self.repo.run("rev-parse", "HEAD")
        self.repo.run("tag", "target")

        target_only = MODULE.rev_list(self.repo.path, merge, picked)
        target_index = MODULE.patch_id_index(self.repo.path, merge)
        base_index = MODULE.patch_id_index(self.repo.path, picked)
        evidence = MODULE.classify_commits(
            self.repo.path, target_only, target_index, base_index
        )

        self.assertEqual("equivalent", evidence[original]["patchStatus"])
        self.assertIn(picked, evidence[original]["equivalentCommitIds"])
        self.assertEqual("notApplicable", evidence[merge]["patchStatus"])

        merge_classification = MODULE.classify_pull_request_change(
            self.repo.path, merge, target_index, base_index
        )
        self.assertEqual("alreadyPresent", merge_classification["status"])
        self.assertEqual(1, merge_classification["equivalentPatchCount"])
        self.assertEqual(0, merge_classification["newPatchCount"])

    def test_duplicate_patch_is_removed_from_effective_release_counts(self):
        root = self.repo.write_commit("root\n", "root")
        self.repo.run("checkout", "--quiet", "-b", "develop")
        original = self.repo.write_commit("root\nchange\n", "change")

        self.repo.run("checkout", "--quiet", "-b", "release", root)
        (self.repo.path / "release.txt").write_text("release\n", encoding="utf-8")
        self.repo.run("add", "release.txt")
        self.repo.run("commit", "--quiet", "-m", "release setup")
        self.repo.run("cherry-pick", "--quiet", original)
        base = self.repo.run("rev-parse", "HEAD")
        self.repo.run("merge", "--quiet", "--no-ff", "develop", "-m", "merge develop")
        merge = self.repo.run("rev-parse", "HEAD")

        commits = MODULE.rev_list(self.repo.path, merge, base)
        target_index = MODULE.patch_id_index(self.repo.path, merge)
        base_index = MODULE.patch_id_index(self.repo.path, base)
        evidence = MODULE.classify_commits(
            self.repo.path, commits, target_index, base_index
        )
        shallow_pr = {"pullRequestId": 42}
        hydrated_pr = {
            "id": 42,
            "title": "Merge develop",
            "status": "completed",
            "lastMergeCommit": merge,
            "directWorkItemIds": [],
            "workItemPaths": [],
        }

        with (
            mock.patch.object(
                MODULE, "query_pull_requests", return_value=({"42": shallow_pr}, {merge})
            ),
            mock.patch.object(MODULE, "hydrate_pull_request", return_value=hydrated_pr),
            mock.patch.object(MODULE, "linked_work_item_ids", return_value=[]),
        ):
            side = MODULE.collect_side(
                commits,
                self.repo.path,
                {},
                {},
                evidence,
                target_index,
                base_index,
            )

        self.assertEqual(2, side["commitCount"])
        self.assertEqual(0, side["effectiveCommitCount"])
        self.assertEqual(1, side["equivalentCommitCount"])
        self.assertEqual(1, side["pullRequestCount"])
        self.assertEqual(0, side["effectivePullRequestCount"])
        self.assertEqual(1, side["alreadyPresentPullRequestCount"])
        self.assertEqual([], side["effectiveUnmatchedCommits"])

    def test_mixed_merge_remains_effective_and_is_marked_partial(self):
        root = self.repo.write_commit("root\n", "root")
        self.repo.run("checkout", "--quiet", "-b", "develop")
        original = self.repo.write_commit("root\nchange\n", "change")
        (self.repo.path / "new.txt").write_text("new\n", encoding="utf-8")
        self.repo.run("add", "new.txt")
        self.repo.run("commit", "--quiet", "-m", "new")
        new_commit = self.repo.run("rev-parse", "HEAD")

        self.repo.run("checkout", "--quiet", "-b", "release", root)
        (self.repo.path / "release.txt").write_text("release\n", encoding="utf-8")
        self.repo.run("add", "release.txt")
        self.repo.run("commit", "--quiet", "-m", "release setup")
        self.repo.run("cherry-pick", "--quiet", original)
        base = self.repo.run("rev-parse", "HEAD")
        self.repo.run("merge", "--quiet", "--no-ff", "develop", "-m", "merge develop")
        merge = self.repo.run("rev-parse", "HEAD")

        target_index = MODULE.patch_id_index(self.repo.path, merge)
        base_index = MODULE.patch_id_index(self.repo.path, base)
        classification = MODULE.classify_pull_request_change(
            self.repo.path, merge, target_index, base_index
        )

        self.assertEqual("partiallyAlreadyPresent", classification["status"])
        self.assertEqual(1, classification["equivalentPatchCount"])
        self.assertEqual(1, classification["newPatchCount"])
        self.assertIn(new_commit, classification["payloadCommitIds"])


if __name__ == "__main__":
    unittest.main()

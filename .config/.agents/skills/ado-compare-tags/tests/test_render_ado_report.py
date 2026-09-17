import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).parents[1] / "scripts" / "render_ado_report.py"
SPEC = importlib.util.spec_from_file_location("render_ado_report", SCRIPT)
RENDERER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RENDERER)


def side(*, effective: bool, equivalent: bool = False):
    commit = {
        "commitId": "abc123",
        "subject": "Recálculo <script>alert(1)</script>",
        "parentCount": 1,
        "patchStatus": "equivalent" if equivalent else "new",
        "patchId": "patch-1",
        "equivalentCommitIds": ["def456"] if equivalent else [],
    }
    classification = "alreadyPresent" if equivalent else "new"
    pr = {
        "id": 10,
        "title": "Atualiza cálculo",
        "description": "Descrição da alteração",
        "status": "completed",
        "url": "https://dev.azure.com/org/project/_git/repo/pullrequest/10",
        "lastMergeCommit": "abc123",
        "directWorkItemIds": [100],
        "workItemPaths": [[100, 200]],
        "changeClassification": {
            "status": classification,
            "reason": "allPayloadPatchesEquivalent" if equivalent else "newPayloadPatches",
            "payloadCommitIds": ["abc123"],
            "newPatchCount": 0 if equivalent else 1,
            "equivalentPatchCount": 1 if equivalent else 0,
            "unavailablePatchCount": 0,
            "equivalentCommits": [],
        },
    }
    work_items = [
        {
            "id": 100,
            "type": "User Story",
            "category": "story",
            "title": "Recálculo da parcela",
            "state": "Done",
            "description": "Permite recalcular.",
            "acceptanceCriteria": "O valor deve ser atualizado.",
            "url": "https://dev.azure.com/org/project/_workitems/edit/100",
            "parentId": 200,
            "directPullRequestIds": [10],
            "viaPullRequestIds": [10],
            "effectivePullRequestIds": [10] if effective else [],
            "alreadyPresentPullRequestIds": [] if effective else [10],
            "changeClassifications": [classification],
        },
        {
            "id": 200,
            "type": "Feature",
            "category": "feature",
            "title": "Parcelas",
            "state": "Done",
            "description": None,
            "acceptanceCriteria": None,
            "url": "https://dev.azure.com/org/project/_workitems/edit/200",
            "parentId": None,
            "directPullRequestIds": [],
            "viaPullRequestIds": [10],
            "effectivePullRequestIds": [10] if effective else [],
            "alreadyPresentPullRequestIds": [] if effective else [10],
            "changeClassifications": [classification],
        },
    ]
    return {
        "commitCount": 1,
        "effectiveCommitCount": 1 if effective else 0,
        "equivalentCommitCount": 1 if equivalent else 0,
        "pullRequestCount": 1,
        "effectivePullRequestCount": 1 if effective else 0,
        "alreadyPresentPullRequestCount": 1 if equivalent else 0,
        "workItemCount": 2,
        "effectiveWorkItemCount": 2 if effective else 0,
        "alreadyPresentWorkItemCount": 2 if equivalent else 0,
        "commits": [commit],
        "pullRequests": [pr],
        "workItems": work_items,
        "unmatchedCommits": [commit],
        "effectiveUnmatchedCommits": [commit] if effective else [],
        "patchEquivalence": {
            "equivalentCommits": [commit] if equivalent else [],
            "method": "git patch-id --stable",
        },
        "warnings": [],
        "complete": True,
    }


def evidence():
    return {
        "operation": "tag-comparison",
        "classification": "read-only",
        "repository": {
            "organization": "org",
            "organizationUrl": "https://dev.azure.com/org",
            "project": "project",
            "name": "repo",
            "webUrl": "https://dev.azure.com/org/project/_git/repo",
        },
        "comparison": {
            "baseTag": "v1.0.0",
            "baseCommit": "base123",
            "targetTag": "v1.1.0",
            "targetCommit": "target456",
            "relationship": "baseAncestorOfTarget",
        },
        "sides": {
            "targetOnly": side(effective=True),
            "baseOnly": side(effective=False, equivalent=True),
        },
        "completeness": {
            "complete": True,
            "warnings": [],
            "method": "Git reachability and patch equivalence",
        },
    }


class RenderReportTests(unittest.TestCase):
    def test_pt_br_report_uses_versioned_template_and_preserves_unicode(self):
        html = RENDERER.render_report(
            evidence(), "pt-BR", generated_at="2026-09-17T12:00:00Z"
        )

        self.assertIn('<meta charset="utf-8">', html)
        self.assertIn('data-template-version="1"', html)
        self.assertIn("Comparação de tags", html)
        self.assertIn("Somente no destino", html)
        self.assertIn("Já presente por patch equivalente", html)
        self.assertIn("Precisamos de mais informações", html)
        self.assertIn("Este relatório não verificou este item", html)
        self.assertIn("Recálculo da parcela", html)
        self.assertNotIn("Rec�lculo", html)
        self.assertNotIn("{{", html)

    def test_dynamic_content_is_html_escaped(self):
        html = RENDERER.render_report(
            evidence(), "en", generated_at="2026-09-17T12:00:00Z"
        )

        self.assertIn("Recálculo &lt;script&gt;alert(1)&lt;/script&gt;", html)
        self.assertNotIn("<script>alert(1)</script>", html)

    def test_same_input_produces_same_document(self):
        first = RENDERER.render_report(
            evidence(), "en", generated_at="2026-09-17T12:00:00Z"
        )
        second = RENDERER.render_report(
            evidence(), "en", generated_at="2026-09-17T12:00:00Z"
        )

        self.assertEqual(first, second)

    def test_writes_strict_utf8(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "report.html"
            RENDERER.write_report(
                evidence(), "pt-BR", output, generated_at="2026-09-17T12:00:00Z"
            )

            contents = output.read_bytes().decode("utf-8", errors="strict")
            self.assertIn("Recálculo", contents)


if __name__ == "__main__":
    unittest.main()

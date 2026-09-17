#!/usr/bin/env python3
"""Render deterministic HTML from compare_ado_tags.py JSON evidence."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import html
import json
from pathlib import Path
import tempfile
from typing import Any
from urllib.parse import urlparse


TEMPLATE_VERSION = "1"
TEMPLATE_PATH = Path(__file__).parents[1] / "assets" / "report-template.html"
LANGUAGES = ("en", "pt-BR")

TEXT = {
    "en": {
        "documentTitle": "Tag comparison: {base} → {target}",
        "eyebrow": "What changed between these Azure DevOps tags",
        "title": "Tag comparison",
        "repository": "Repository",
        "generated": "Generated",
        "humanDecision": "You make the final decision",
        "insufficient": "We need more information",
        "insufficientReason": "Some new changes could not be traced completely. Review the gaps before deploying.",
        "divergence": "Review both histories",
        "divergenceReason": "These tags come from different lines of history. Review both sides before deploying.",
        "same": "No tag difference",
        "sameReason": "Both tags resolve to the same Git commit.",
        "review": "Review the changes",
        "reviewReason": "We found the changes between the tags. You still need to check the deployment items below.",
        "relationship": "Git relationship",
        "base": "Base",
        "target": "Target",
        "baseAncestorOfTarget": "Base is an ancestor of target",
        "targetAncestorOfBase": "Target is an ancestor of base",
        "diverged": "Independent histories",
        "sameCommit": "Same commit",
        "summary": "What changed",
        "targetOnly": "In target only",
        "baseOnly": "In base only",
        "commits": "Commits",
        "pullRequests": "Pull requests",
        "workItems": "Work items",
        "effective": "effective",
        "historical": "historical",
        "description": "Description",
        "acceptanceCriteria": "Acceptance criteria",
        "details": "Show details",
        "state": "State",
        "prs": "PRs",
        "unparented": "Unparented work items",
        "none": "None",
        "alreadyPresent": "Already present by equivalent patch",
        "equivalentTo": "Equivalent to",
        "partiallyPresent": "Partially already present",
        "traceability": "Traceability gaps",
        "noGaps": "None found in the collected evidence.",
        "warning": "Collection warning",
        "unmatched": "Effective commit without a matched PR",
        "prWithoutWorkItem": "Effective or indeterminate PR without a linked work item",
        "missingDetail": "Requirement detail unavailable",
        "customItem": "Custom or unparented effective work item",
        "checklist": "Deployment checklist",
        "notEvaluated": "This report did not check this item",
        "checks": [
            "Tests and the branch pipeline passed",
            "Security and dependency alerts were reviewed",
            "Database and configuration changes are compatible",
            "Monitoring and health checks are ready",
            "The rollback plan was tested",
            "The required people approved the deployment",
        ],
        "method": "How this report was made",
        "methodText": "Git history shows which commits belong to each tag. Patch matching finds repeated changes with different commit IDs. Azure DevOps links merge commits to pull requests and work items.",
        "limitation": "Matching patches does not guarantee the same runtime behavior. This report cannot decide by itself whether the deployment is safe.",
        "template": "ADO Tag Comparison Report · Template v{version}",
    },
    "pt-BR": {
        "documentTitle": "Comparação de tags: {base} → {target}",
        "eyebrow": "O que mudou entre estas tags do Azure DevOps",
        "title": "Comparação de tags",
        "repository": "Repositório",
        "generated": "Gerado em",
        "humanDecision": "Você toma a decisão final",
        "insufficient": "Precisamos de mais informações",
        "insufficientReason": "Não conseguimos rastrear completamente algumas mudanças novas. Revise as lacunas antes de implantar.",
        "divergence": "Revise os dois históricos",
        "divergenceReason": "As tags vêm de linhas de histórico diferentes. Revise os dois lados antes de implantar.",
        "same": "Sem diferença entre tags",
        "sameReason": "As duas tags apontam para o mesmo commit Git.",
        "review": "Revise as mudanças",
        "reviewReason": "Encontramos as mudanças entre as tags. Você ainda precisa conferir os itens de implantação abaixo.",
        "relationship": "Relação no Git",
        "base": "Base",
        "target": "Destino",
        "baseAncestorOfTarget": "A base é ancestral do destino",
        "targetAncestorOfBase": "O destino é ancestral da base",
        "diverged": "Históricos independentes",
        "sameCommit": "Mesmo commit",
        "summary": "O que mudou",
        "targetOnly": "Somente no destino",
        "baseOnly": "Somente na base",
        "commits": "Commits",
        "pullRequests": "Pull requests",
        "workItems": "Itens de trabalho",
        "effective": "efetivos",
        "historical": "históricos",
        "description": "Descrição",
        "acceptanceCriteria": "Critérios de aceite",
        "details": "Mostrar detalhes",
        "state": "Estado",
        "prs": "PRs",
        "unparented": "Itens sem Feature associada",
        "none": "Nenhum",
        "alreadyPresent": "Já presente por patch equivalente",
        "equivalentTo": "Equivalente a",
        "partiallyPresent": "Parcialmente já presente",
        "traceability": "Lacunas de rastreabilidade",
        "noGaps": "Nenhuma encontrada nas evidências coletadas.",
        "warning": "Aviso de coleta",
        "unmatched": "Commit efetivo sem PR correspondente",
        "prWithoutWorkItem": "PR efetiva ou indeterminada sem item de trabalho vinculado",
        "missingDetail": "Detalhes do requisito indisponíveis",
        "customItem": "Item efetivo customizado ou sem Feature associada",
        "checklist": "Checklist de implantação",
        "notEvaluated": "Este relatório não verificou este item",
        "checks": [
            "Os testes e o pipeline da branch passaram",
            "Os alertas de segurança e dependências foram revisados",
            "As mudanças de banco de dados e configuração são compatíveis",
            "O monitoramento e as verificações de saúde estão prontos",
            "O plano de rollback foi testado",
            "As pessoas necessárias aprovaram a implantação",
        ],
        "method": "Como este relatório foi feito",
        "methodText": "O histórico do Git mostra quais commits pertencem a cada tag. A comparação de patches encontra mudanças repetidas com IDs diferentes. O Azure DevOps liga os commits de merge às pull requests e aos itens de trabalho.",
        "limitation": "Patches iguais não garantem o mesmo comportamento em execução. Este relatório não decide sozinho se a implantação é segura.",
        "template": "Relatório de comparação de tags ADO · Template v{version}",
    },
}


def escape(value: Any) -> str:
    return html.escape(str(value if value is not None else ""), quote=True)


def text(language: str, key: str) -> Any:
    return TEXT[language][key]


def safe_url(value: Any) -> str | None:
    url = str(value or "")
    parsed = urlparse(url)
    return url if parsed.scheme in {"http", "https"} and parsed.netloc else None


def link(label: Any, url: Any, css_class: str = "") -> str:
    href = safe_url(url)
    escaped_label = escape(label)
    if not href:
        return escaped_label
    class_attribute = f' class="{escape(css_class)}"' if css_class else ""
    return f'<a{class_attribute} href="{escape(href)}" target="_blank" rel="noreferrer">{escaped_label}</a>'


def short_hash(commit_id: Any) -> str:
    return str(commit_id or "")[:10]


def decision(evidence: dict[str, Any], language: str) -> tuple[str, str, str]:
    sides = evidence.get("sides", {})
    all_sides = [sides.get("targetOnly", {}), sides.get("baseOnly", {})]
    has_gap = not evidence.get("completeness", {}).get("complete", False)
    for side in all_sides:
        has_gap = has_gap or not side.get("complete", False)
        has_gap = has_gap or bool(side.get("warnings"))
        has_gap = has_gap or bool(side.get("effectiveUnmatchedCommits"))
        has_gap = has_gap or any(
            pr.get("changeClassification", {}).get("status") != "alreadyPresent"
            and not pr.get("directWorkItemIds")
            for pr in side.get("pullRequests", [])
        )
    if has_gap:
        return "danger", text(language, "insufficient"), text(language, "insufficientReason")

    relationship = evidence.get("comparison", {}).get("relationship")
    if relationship in {"diverged", "targetAncestorOfBase"}:
        return "warn", text(language, "divergence"), text(language, "divergenceReason")
    if relationship == "sameCommit":
        return "good", text(language, "same"), text(language, "sameReason")
    return "neutral", text(language, "review"), text(language, "reviewReason")


def render_header(evidence: dict[str, Any], language: str, generated_at: str) -> str:
    repository = evidence.get("repository", {})
    comparison = evidence.get("comparison", {})
    repository_label = f'{repository.get("project", "")} / {repository.get("name", "")}'.strip(" / ")
    return f"""
<header class="hero">
  <p class="eyebrow">{escape(text(language, "eyebrow"))}</p>
  <h1>{escape(text(language, "title"))}: {escape(comparison.get("baseTag"))} → {escape(comparison.get("targetTag"))}</h1>
  <p class="subtitle">{escape(repository_label)}</p>
  <div class="meta">
    <span><strong>{escape(text(language, "repository"))}:</strong> {link(repository_label, repository.get("webUrl"))}</span>
    <span><strong>{escape(text(language, "generated"))}:</strong> {escape(generated_at)}</span>
  </div>
</header>"""


def render_decision(evidence: dict[str, Any], language: str) -> str:
    css_class, title, reason = decision(evidence, language)
    return f"""
<section class="panel banner {css_class}">
  <div class="banner-label">{escape(title)}</div>
  <p>{escape(reason)}</p>
  <p class="muted">{escape(text(language, "humanDecision"))}</p>
</section>"""


def render_relationship(evidence: dict[str, Any], language: str) -> str:
    comparison = evidence.get("comparison", {})
    relationship = comparison.get("relationship", "diverged")
    label = text(language, relationship) if relationship in TEXT[language] else relationship
    return f"""
<section class="panel">
  <h2>{escape(text(language, "relationship"))}</h2>
  <div class="relationship">
    <div class="tag-node"><strong>{escape(text(language, "base"))}: {escape(comparison.get("baseTag"))}</strong><code>{escape(short_hash(comparison.get("baseCommit")))}</code></div>
    <div class="relation-arrow">{escape(label)}</div>
    <div class="tag-node"><strong>{escape(text(language, "target"))}: {escape(comparison.get("targetTag"))}</strong><code>{escape(short_hash(comparison.get("targetCommit")))}</code></div>
  </div>
</section>"""


def metric(side: dict[str, Any], language: str, noun_key: str, effective_key: str, historical_key: str) -> str:
    effective = side.get(effective_key, 0)
    historical = side.get(historical_key, 0)
    return f"""
<div class="metric">
  <strong>{escape(effective)}</strong>
  <span>{escape(text(language, noun_key))}</span>
  <small>{escape(historical)} {escape(text(language, "historical"))}</small>
</div>"""


def render_summary(evidence: dict[str, Any], language: str) -> str:
    sides = evidence.get("sides", {})
    cards = []
    for side_key, title_key in (("targetOnly", "targetOnly"), ("baseOnly", "baseOnly")):
        side = sides.get(side_key, {})
        metrics = "".join(
            (
                metric(side, language, "commits", "effectiveCommitCount", "commitCount"),
                metric(side, language, "pullRequests", "effectivePullRequestCount", "pullRequestCount"),
                metric(side, language, "workItems", "effectiveWorkItemCount", "workItemCount"),
            )
        )
        cards.append(f'<article class="side-card"><header><h3>{escape(text(language, title_key))}</h3></header><div class="metrics">{metrics}</div></article>')
    return f'<section class="panel"><h2>{escape(text(language, "summary"))}</h2><div class="summary-grid">{"".join(cards)}</div></section>'


def classification_badges(item: dict[str, Any], language: str) -> str:
    classifications = set(item.get("changeClassifications", []))
    badges = []
    if "partiallyAlreadyPresent" in classifications:
        badges.append(f'<span class="badge warn">{escape(text(language, "partiallyPresent"))}</span>')
    state = item.get("state")
    if state:
        badges.append(f'<span class="badge">{escape(state)}</span>')
    return "".join(badges)


def render_item(item: dict[str, Any], prs: dict[int, dict[str, Any]], language: str) -> str:
    pr_ids = item.get("effectivePullRequestIds", []) or item.get("viaPullRequestIds", [])
    pr_links = ", ".join(
        link(f"PR #{pr_id}", prs.get(pr_id, {}).get("url")) for pr_id in pr_ids
    )
    detail_parts = []
    if item.get("description"):
        detail_parts.append(f'<div class="detail-box"><strong>{escape(text(language, "description"))}</strong><br>{escape(item["description"])}</div>')
    if item.get("acceptanceCriteria"):
        detail_parts.append(f'<div class="detail-box"><strong>{escape(text(language, "acceptanceCriteria"))}</strong><br>{escape(item["acceptanceCriteria"])}</div>')
    details = ""
    if detail_parts:
        details = f'<details><summary>{escape(text(language, "details"))}</summary><div class="detail-grid">{"".join(detail_parts)}</div></details>'
    return f"""
<div class="item">
  <div class="item-line">
    <span class="badge brand">{escape(item.get("type", "Unknown"))}</span>
    <span class="item-title">{link(f'#{item.get("id")} {item.get("title", "")}', item.get("url"))}</span>
    {classification_badges(item, language)}
  </div>
  <div class="pr-links">{escape(text(language, "prs"))}: {pr_links or escape(text(language, "none"))}</div>
  {details}
</div>"""


def effective_hierarchy(side: dict[str, Any]) -> tuple[list[tuple[dict[str, Any], list[dict[str, Any]]]], list[dict[str, Any]]]:
    items = {int(item["id"]): item for item in side.get("workItems", [])}
    effective_ids = {item_id for item_id, item in items.items() if item.get("effectivePullRequestIds")}
    descendants: dict[int, set[int]] = {}
    included: set[int] = set()
    effective_pr_ids = {
        int(pr["id"])
        for pr in side.get("pullRequests", [])
        if pr.get("changeClassification", {}).get("status") != "alreadyPresent"
    }
    for pr in side.get("pullRequests", []):
        if int(pr.get("id", -1)) not in effective_pr_ids:
            continue
        for path in pr.get("workItemPaths", []):
            feature_id = next(
                (int(item_id) for item_id in path if items.get(int(item_id), {}).get("category") == "feature"),
                None,
            )
            if feature_id is None:
                continue
            path_ids = {int(item_id) for item_id in path if int(item_id) in effective_ids}
            descendants.setdefault(feature_id, set()).update(path_ids - {feature_id})
            included.update(path_ids)

    rank = {"story": 0, "task": 1, "other": 2, "feature": 3}
    groups = []
    for feature_id in sorted(descendants):
        feature = items[feature_id]
        children = sorted(
            (items[item_id] for item_id in descendants[feature_id]),
            key=lambda item: (rank.get(item.get("category"), 9), int(item["id"])),
        )
        groups.append((feature, children))
    unparented = sorted(
        (items[item_id] for item_id in effective_ids - included),
        key=lambda item: (rank.get(item.get("category"), 9), int(item["id"])),
    )
    return groups, unparented


def render_effective_side(side: dict[str, Any], language: str, title_key: str) -> str:
    prs = {int(pr["id"]): pr for pr in side.get("pullRequests", [])}
    groups, unparented = effective_hierarchy(side)
    blocks = []
    for feature, children in groups:
        child_html = "".join(render_item(item, prs, language) for item in children)
        blocks.append(f"""
<article class="feature">
  <header><div class="item-line"><span class="badge brand">Feature</span><h3>{link(f'#{feature.get("id")} {feature.get("title", "")}', feature.get("url"))}</h3>{classification_badges(feature, language)}</div></header>
  <div class="feature-body">{child_html or render_item(feature, prs, language)}</div>
</article>""")
    if unparented:
        blocks.append(f'<h3>{escape(text(language, "unparented"))}</h3>')
        blocks.extend(render_item(item, prs, language) for item in unparented)
    content = "".join(blocks) or f'<div class="empty">{escape(text(language, "none"))}</div>'
    return f'<section class="panel"><h2>{escape(text(language, title_key))}</h2>{content}</section>'


def render_equivalent(evidence: dict[str, Any], language: str) -> str:
    rows = []
    for side_key, side_label in (("targetOnly", "targetOnly"), ("baseOnly", "baseOnly")):
        side = evidence.get("sides", {}).get(side_key, {})
        for commit in side.get("patchEquivalence", {}).get("equivalentCommits", []):
            equivalents = ", ".join(short_hash(value) for value in commit.get("equivalentCommitIds", []))
            rows.append(f'<div class="commit-row"><span class="badge good">{escape(text(language, side_label))}</span> <code class="hash">{escape(short_hash(commit.get("commitId")))}</code> {escape(commit.get("subject"))}<div class="muted">{escape(text(language, "equivalentTo"))}: <code>{escape(equivalents)}</code></div></div>')
        for pr in side.get("pullRequests", []):
            if pr.get("changeClassification", {}).get("status") == "alreadyPresent":
                pr_label = f"PR #{pr.get('id')} {pr.get('title', '')}"
                rows.append(f'<div class="pr-row"><span class="badge good">{escape(text(language, side_label))}</span> {link(pr_label, pr.get("url"))}</div>')
    content = "".join(rows) or f'<div class="empty">{escape(text(language, "none"))}</div>'
    return f'<section class="panel"><h2>{escape(text(language, "alreadyPresent"))}</h2>{content}</section>'


def traceability_gaps(evidence: dict[str, Any], language: str) -> list[str]:
    gaps = []
    for warning in evidence.get("completeness", {}).get("warnings", []):
        gaps.append(f'{escape(text(language, "warning"))}: {escape(warning)}')
    for side in evidence.get("sides", {}).values():
        for warning in side.get("warnings", []):
            rendered = f'{escape(text(language, "warning"))}: {escape(warning)}'
            if rendered not in gaps:
                gaps.append(rendered)
        for commit in side.get("effectiveUnmatchedCommits", []):
            gaps.append(f'{escape(text(language, "unmatched"))}: <code>{escape(short_hash(commit.get("commitId")))}</code> {escape(commit.get("subject"))}')
        for pr in side.get("pullRequests", []):
            if pr.get("changeClassification", {}).get("status") != "alreadyPresent" and not pr.get("directWorkItemIds"):
                pr_label = f"PR #{pr.get('id')} {pr.get('title', '')}"
                gaps.append(f'{escape(text(language, "prWithoutWorkItem"))}: {link(pr_label, pr.get("url"))}')
        for item in side.get("workItems", []):
            if not item.get("effectivePullRequestIds"):
                continue
            item_label = f"#{item.get('id')} {item.get('title', '')}"
            if item.get("category") == "story" and not item.get("description") and not item.get("acceptanceCriteria"):
                gaps.append(f'{escape(text(language, "missingDetail"))}: {link(item_label, item.get("url"))}')
            if item.get("category") == "other" or (item.get("category") != "feature" and not item.get("parentId")):
                gaps.append(f'{escape(text(language, "customItem"))}: {link(item_label, item.get("url"))}')
    return gaps


def render_gaps(evidence: dict[str, Any], language: str) -> str:
    gaps = traceability_gaps(evidence, language)
    content = f'<ul class="list">{"".join(f"<li>{gap}</li>" for gap in gaps)}</ul>' if gaps else f'<div class="empty">{escape(text(language, "noGaps"))}</div>'
    return f'<section class="panel"><h2>{escape(text(language, "traceability"))}</h2>{content}</section>'


def render_checklist(language: str) -> str:
    checks = "".join(f'<div class="check"><div><strong>{escape(check)}</strong><br><span class="muted">{escape(text(language, "notEvaluated"))}</span></div></div>' for check in text(language, "checks"))
    return f'<section class="panel"><h2>{escape(text(language, "checklist"))}</h2><div class="checklist">{checks}</div></section>'


def render_method(language: str) -> str:
    return f'<section class="panel"><h2>{escape(text(language, "method"))}</h2><p>{escape(text(language, "methodText"))}</p><p class="muted">{escape(text(language, "limitation"))}</p></section>'


def render_report(
    evidence: dict[str, Any], language: str, generated_at: str | None = None
) -> str:
    if language not in LANGUAGES:
        raise ValueError(f"Unsupported language: {language}")
    generated_at = generated_at or datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    comparison = evidence.get("comparison", {})
    document_title = text(language, "documentTitle").format(
        base=comparison.get("baseTag", ""), target=comparison.get("targetTag", "")
    )
    sides = evidence.get("sides", {})
    body = "".join(
        (
            render_header(evidence, language, generated_at),
            render_decision(evidence, language),
            render_relationship(evidence, language),
            render_summary(evidence, language),
            render_effective_side(sides.get("targetOnly", {}), language, "targetOnly"),
            render_effective_side(sides.get("baseOnly", {}), language, "baseOnly"),
            render_equivalent(evidence, language),
            render_gaps(evidence, language),
            render_checklist(language),
            render_method(language),
        )
    )
    footer = text(language, "template").format(version=TEMPLATE_VERSION)
    template = TEMPLATE_PATH.read_text(encoding="utf-8", errors="strict")
    return (
        template.replace("{{LANG}}", escape(language))
        .replace("{{DOCUMENT_TITLE}}", escape(document_title))
        .replace("{{REPORT_BODY}}", body)
        .replace("{{FOOTER}}", escape(footer))
    )


def write_report(
    evidence: dict[str, Any],
    language: str,
    output: Path,
    generated_at: str | None = None,
) -> Path:
    rendered = render_report(evidence, language, generated_at)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(rendered, encoding="utf-8", errors="strict")
    return output.resolve()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render a deterministic HTML report from tag-comparison JSON.")
    parser.add_argument("evidence_json", type=Path, help="JSON output from compare_ado_tags.py")
    parser.add_argument("--language", choices=LANGUAGES, default="en", help="Report language")
    parser.add_argument("--output", type=Path, help="HTML destination; defaults to the OS temporary directory")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    with args.evidence_json.open(encoding="utf-8", errors="strict") as handle:
        evidence = json.load(handle)
    output = args.output
    if output is None:
        with tempfile.NamedTemporaryFile(prefix="ado-tag-comparison-", suffix=".html", delete=False) as handle:
            output = Path(handle.name)
    path = write_report(evidence, args.language, output)
    print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

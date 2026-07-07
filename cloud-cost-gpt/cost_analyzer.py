#!/usr/bin/env python3
"""Generate an AWS cost optimisation report with optional Infracost context."""

from __future__ import annotations

import json
import os
from collections import defaultdict
from datetime import date, timedelta
from pathlib import Path
from typing import Any

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from openai import OpenAI


def fetch_aws_costs() -> list[dict[str, Any]]:
    end = date.today()
    start = end - timedelta(days=30)
    client = boto3.client("ce", region_name=os.environ["AWS_REGION"])
    response = client.get_cost_and_usage(
        TimePeriod={"Start": start.isoformat(), "End": end.isoformat()},
        Granularity="MONTHLY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
    )
    groups = response["ResultsByTime"][0].get("Groups", [])
    rows: list[dict[str, Any]] = []
    for group in groups:
        amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
        rows.append(
            {
                "service": group["Keys"][0],
                "amount": amount,
                "unit": group["Metrics"]["UnblendedCost"]["Unit"],
            }
        )
    return sorted(rows, key=lambda item: item["amount"], reverse=True)


def load_infracost_summary(path: str | None) -> dict[str, Any] | None:
    if not path:
        return None
    file_path = Path(path)
    if not file_path.exists():
        return {"error": f"Infracost file not found: {path}"}

    payload = json.loads(file_path.read_text())
    projects = payload.get("projects", [])
    total_monthly_cost = 0.0
    resource_deltas: list[dict[str, Any]] = []

    for project in projects:
        breakdown = project.get("breakdown", {})
        total_monthly_cost += float(breakdown.get("totalMonthlyCost", 0.0))
        for resource in breakdown.get("resources", []):
            diff = resource.get("monthlyCost", "0")
            previous = resource.get("previousMonthlyCost")
            resource_deltas.append(
                {
                    "name": resource.get("name", "unknown"),
                    "monthly_cost": float(diff or 0.0),
                    "previous_monthly_cost": float(previous or 0.0),
                    "diff": float(resource.get("diff", 0.0) or 0.0),
                }
            )

    resource_deltas.sort(key=lambda item: abs(item["diff"]), reverse=True)
    return {
        "project_count": len(projects),
        "total_monthly_cost": total_monthly_cost,
        "largest_deltas": resource_deltas[:5],
    }


def heuristic_recommendations(cost_rows: list[dict[str, Any]], infracost: dict[str, Any] | None) -> list[str]:
    recommendations: list[str] = []
    top_rows = cost_rows[:3]
    for row in top_rows:
        service = row["service"]
        if "EC2" in service or "Elastic Compute" in service:
            recommendations.append("Review EC2 rightsizing, instance scheduling, and Savings Plans coverage for the highest compute spend.")
        elif "EKS" in service or "Kubernetes" in service:
            recommendations.append("Inspect EKS node group utilisation, HPA/KEDA thresholds, and idle workloads in non-production namespaces.")
        elif "CloudWatch" in service:
            recommendations.append("Reduce high-cardinality metrics, shorten log retention where allowed, and remove unused dashboards or alarms.")
        elif "NAT Gateway" in service:
            recommendations.append("Check cross-AZ egress, consolidate private egress paths, and evaluate interface endpoints for heavy AWS API traffic.")

    if infracost and infracost.get("largest_deltas"):
        recommendations.append("Review the highest Infracost deltas before merge and challenge any change that raises baseline monthly spend without an SLO or capacity justification.")

    if not recommendations:
        recommendations.append("No dominant cost driver was detected; review tagged spend by environment and remove unused development resources.")
    return recommendations


def render_prompt(cost_rows: list[dict[str, Any]], infracost: dict[str, Any] | None) -> str:
    lines = ["AWS 30-day spend by service:"]
    lines.extend([f"- {row['service']}: {row['amount']:.2f} {row['unit']}" for row in cost_rows[:10]])
    if infracost:
        lines.append("")
        lines.append("Infracost pull request context:")
        if "error" in infracost:
            lines.append(f"- {infracost['error']}")
        else:
            lines.append(f"- Projects analysed: {infracost['project_count']}")
            lines.append(f"- Estimated baseline monthly cost: {infracost['total_monthly_cost']:.2f} USD")
            for delta in infracost["largest_deltas"]:
                lines.append(
                    f"- {delta['name']}: current {delta['monthly_cost']:.2f} USD, previous {delta['previous_monthly_cost']:.2f} USD, diff {delta['diff']:.2f} USD"
                )
    return "\n".join(lines)


def summarise_with_openai(prompt: str) -> str | None:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return None
    client = OpenAI(api_key=api_key)
    response = client.responses.create(
        model="gpt-4.1-mini",
        input=[
            {
                "role": "system",
                "content": "You are a FinOps engineer. Produce a concise markdown report with summary, risks, and actionable recommendations.",
            },
            {"role": "user", "content": prompt},
        ],
    )
    return response.output_text


def render_markdown(cost_rows: list[dict[str, Any]], infracost: dict[str, Any] | None) -> str:
    prompt = render_prompt(cost_rows, infracost)
    ai_summary = summarise_with_openai(prompt)
    recommendations = heuristic_recommendations(cost_rows, infracost)

    by_bucket: dict[str, float] = defaultdict(float)
    for row in cost_rows:
        by_bucket[row["service"]] += row["amount"]

    lines = [
        "# AWS Cost Optimisation Report",
        "",
        "## Spend Summary",
        "",
    ]
    for service, amount in list(sorted(by_bucket.items(), key=lambda item: item[1], reverse=True))[:10]:
        lines.append(f"- {service}: {amount:.2f} USD")

    lines.extend(["", "## Recommendations", ""])
    lines.extend([f"- {item}" for item in recommendations])

    if infracost:
        lines.extend(["", "## Infracost Context", ""])
        if "error" in infracost:
            lines.append(f"- {infracost['error']}")
        else:
            lines.append(f"- Projects analysed: {infracost['project_count']}")
            lines.append(f"- Estimated baseline monthly cost: {infracost['total_monthly_cost']:.2f} USD")
            for delta in infracost["largest_deltas"]:
                lines.append(f"- {delta['name']}: diff {delta['diff']:.2f} USD/month")

    if ai_summary:
        lines.extend(["", "## AI Summary", "", ai_summary.strip()])

    return "\n".join(lines) + "\n"


def main() -> int:
    try:
        cost_rows = fetch_aws_costs()
    except (BotoCoreError, ClientError, KeyError) as exc:
        Path("cost_report.md").write_text(
            "# AWS Cost Optimisation Report\n\n- Failed to query AWS Cost Explorer.\n- Error: "
            + str(exc)
            + "\n"
        )
        return 1

    infracost = load_infracost_summary(os.getenv("INFRACOST_JSON_PATH"))
    report = render_markdown(cost_rows, infracost)
    Path("cost_report.md").write_text(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

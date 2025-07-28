#!/usr/bin/env python3
"""
Azure Cost Optimizer with GPT

This script fetches Azure cost data, identifies high-cost and underutilized
resources, and uses OpenAI GPT to generate cost-saving recommendations.
"""

import os
import logging
from datetime import datetime, timedelta
import openai
from azure.identity import DefaultAzureCredential
from azure.mgmt.costmanagement import CostManagementClient
from azure.mgmt.monitor import MonitorManagementClient

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class AzureCostAnalyzer:
    def __init__(self):
        # Authenticate using default credentials (e.g., environment variables)
        self.credential = DefaultAzureCredential()
        self.subscription_id = os.getenv('AZURE_SUBSCRIPTION_ID')
        if not self.subscription_id:
            raise ValueError("AZURE_SUBSCRIPTION_ID environment variable not set.")

        self.cost_mgmt_client = CostManagementClient(self.credential)
        self.monitor_client = MonitorManagementClient(self.credential, self.subscription_id)
        self.openai_client = openai.OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

    def get_cost_data(self, scope: str) -> dict:
        """Fetches cost data for the last 30 days."""
        logger.info(f"Fetching cost data for scope: {scope}")
        try:
            end_date = datetime.utcnow()
            start_date = end_date - timedelta(days=30)

            query_result = self.cost_mgmt_client.query.usage(
                scope=scope,
                parameters={
                    "type": "ActualCost",
                    "timeframe": "Custom",
                    "time_period": {
                        "from": start_date.isoformat(),
                        "to": end_date.isoformat()
                    },
                    "dataset": {
                        "granularity": "None",
                        "aggregation": {
                            "totalCost": {
                                "name": "Cost",
                                "function": "Sum"
                            }
                        },
                        "grouping": [
                            {"type": "Dimension", "name": "ResourceType"},
                            {"type": "Dimension", "name": "ResourceGroupName"}
                        ]
                    }
                }
            )
            return query_result.rows
        except Exception as e:
            logger.error(f"Error fetching cost data: {e}")
            return []

    def analyze_costs_with_gpt(self, cost_data: list) -> str:
        """Uses OpenAI GPT to analyze cost data and generate recommendations."""
        logger.info("Analyzing cost data with OpenAI GPT...")
        if not cost_data:
            return "No cost data available to analyze."

        prompt_data = "\n".join([f"ResourceType: {row[1]}, RG: {row[2]}, Cost: {row[0]:.2f} USD" for row in cost_data])
        system_prompt = (
            "You are an expert Azure cost optimization assistant. Analyze the following Azure cost data, "
            "which shows cost per resource type and resource group for the last 30 days. "
            "Provide a summary of the highest cost services and concrete, actionable recommendations to reduce costs. "
            "Focus on common areas like right-sizing VMs, deleting idle resources, using reservations, or switching to more cost-effective services. "
            "Format the output as a markdown report."
        )

        try:
            response = self.openai_client.chat.completions.create(
                model="gpt-4-turbo",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": prompt_data}
                ]
            )
            return response.choices[0].message.content
        except Exception as e:
            logger.error(f"Error with OpenAI request: {e}")
            return "Failed to generate cost analysis report."

    def run(self):
        """Main execution logic."""
        scope = f"/subscriptions/{self.subscription_id}"
        cost_data = self.get_cost_data(scope)
        report = self.analyze_costs_with_gpt(cost_data)

        logger.info("\n--- Azure Cost Optimization Report ---\n")
        print(report)

        # Save report to a file for GitHub Actions artifact
        with open("cost_report.md", "w") as f:
            f.write(report)
        logger.info("\nReport saved to cost_report.md")

if __name__ == "__main__":
    analyzer = AzureCostAnalyzer()
    analyzer.run()

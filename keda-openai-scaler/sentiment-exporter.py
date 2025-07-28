#!/usr/bin/env python3
"""
KEDA OpenAI Sentiment Analysis Exporter
Analyzes application logs for sentiment and exports metrics for autoscaling
"""

import os
import time
import logging
from typing import Dict, List
from prometheus_client import start_http_server, Gauge
import openai
from kubernetes import client, config
import json

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics
sentiment_score = Gauge('app_sentiment_score', 'Application sentiment score from log analysis', ['namespace', 'app'])
log_volume = Gauge('app_log_volume', 'Number of logs processed', ['namespace', 'app'])

class SentimentExporter:
    def __init__(self):
        self.openai_client = openai.OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
        
        # Initialize Kubernetes client
        try:
            config.load_incluster_config()
        except:
            config.load_kube_config()
        
        self.k8s_client = client.CoreV1Api()
        
    def analyze_sentiment(self, logs: List[str]) -> float:
        """Analyze sentiment of logs using OpenAI GPT"""
        try:
            # Combine logs for analysis
            log_text = "\n".join(logs[-50:])  # Analyze last 50 log entries
            
            response = self.openai_client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {
                        "role": "system",
                        "content": "Analyze the sentiment of these application logs. Return a score from 0-10 where 0 is very negative (errors, failures) and 10 is very positive (success, good performance). Return only the numeric score."
                    },
                    {
                        "role": "user",
                        "content": log_text
                    }
                ],
                max_tokens=10,
                temperature=0.1
            )
            
            score = float(response.choices[0].message.content.strip())
            return max(0, min(10, score))  # Ensure score is between 0-10
            
        except Exception as e:
            logger.error(f"Error analyzing sentiment: {e}")
            return 5.0  # Default neutral score
    
    def get_pod_logs(self, namespace: str, app_label: str) -> List[str]:
        """Retrieve logs from pods with specific app label"""
        try:
            pods = self.k8s_client.list_namespaced_pod(
                namespace=namespace,
                label_selector=f"app={app_label}"
            )
            
            all_logs = []
            for pod in pods.items:
                try:
                    logs = self.k8s_client.read_namespaced_pod_log(
                        name=pod.metadata.name,
                        namespace=namespace,
                        tail_lines=100
                    )
                    all_logs.extend(logs.split('\n'))
                except Exception as e:
                    logger.warning(f"Could not get logs for pod {pod.metadata.name}: {e}")
            
            return [log for log in all_logs if log.strip()]
            
        except Exception as e:
            logger.error(f"Error getting pod logs: {e}")
            return []
    
    def collect_metrics(self):
        """Collect and export sentiment metrics"""
        # Applications to monitor
        apps = [
            {"namespace": "dev", "app": "shared-app"},
            {"namespace": "stage", "app": "shared-app"},
            {"namespace": "prod", "app": "shared-app"}
        ]
        
        for app_config in apps:
            namespace = app_config["namespace"]
            app = app_config["app"]
            
            logger.info(f"Collecting metrics for {namespace}/{app}")
            
            # Get logs
            logs = self.get_pod_logs(namespace, app)
            log_volume.labels(namespace=namespace, app=app).set(len(logs))
            
            if logs:
                # Analyze sentiment
                score = self.analyze_sentiment(logs)
                sentiment_score.labels(namespace=namespace, app=app).set(score)
                logger.info(f"Sentiment score for {namespace}/{app}: {score}")
            else:
                logger.warning(f"No logs found for {namespace}/{app}")
    
    def run(self):
        """Main execution loop"""
        logger.info("Starting sentiment exporter")
        
        # Start Prometheus metrics server
        start_http_server(8080)
        logger.info("Metrics server started on port 8080")
        
        while True:
            try:
                self.collect_metrics()
                time.sleep(60)  # Collect metrics every minute
            except Exception as e:
                logger.error(f"Error in main loop: {e}")
                time.sleep(30)

if __name__ == "__main__":
    exporter = SentimentExporter()
    exporter.run()

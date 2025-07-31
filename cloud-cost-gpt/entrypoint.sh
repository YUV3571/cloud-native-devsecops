#!/bin/sh
cd /app
export AZURE_SUBSCRIPTION_ID="$INPUT_AZURE-SUBSCRIPTION-ID"
export OPENAI_API_KEY="$INPUT_OPENAI-API-KEY"
python cost_analyzer.py
#!/bin/sh
cd /app
export AZURE_SUBSCRIPTION_ID="$INPUT_AZURE_SUBSCRIPTION_ID"
export OPENAI_API_KEY="$INPUT_OPENAI_API_KEY"
python cost_analyzer.py

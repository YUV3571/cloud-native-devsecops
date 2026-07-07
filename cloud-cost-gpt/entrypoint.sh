#!/bin/sh
set -eu

cd /app
export AWS_REGION="$INPUT_AWS-REGION"
export OPENAI_API_KEY="${INPUT_OPENAI-API-KEY:-}"
export INFRACOST_JSON_PATH="${INPUT_INFRACOST-JSON:-}"
python cost_analyzer.py

# syntax=docker/dockerfile:1
FROM python:3.11-slim

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Set workdir
WORKDIR /app

# Copy code
COPY cost_analyzer.py ./
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Install dependencies
RUN pip install --no-cache-dir azure-identity azure-mgmt-costmanagement azure-mgmt-monitor openai

# Entrypoint
ENTRYPOINT ["/entrypoint.sh"]

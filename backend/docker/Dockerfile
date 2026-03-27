# Start with a Python 3.11 slim image
FROM python:3.11.15-slim

# Upgrade pip to a newer version
RUN pip install --upgrade pip

# Use --no-cache-dir to avoid storing pip's download cache.
RUN pip install --no-cache-dir requests fastapi pydantic uvicorn dotenv
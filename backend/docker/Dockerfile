# Start with a Python 3.11 slim image
FROM python:3.11.15-slim

# Upgrade pip to a newer version
RUN pip install --upgrade pip

# Install python libraries
# Use --no-cache-dir to avoid storing pip's download cache.
RUN pip install --no-cache-dir requests fastapi pydantic uvicorn dotenv
RUN pip install --no-cache-dir transformers torch

# Set the working directory inside our container
WORKDIR /app

# Copy application source code into container
COPY src /app/src

# Import our Port (default 6060)
ARG PORT=6060
ENV PORT=$PORT

# Document that app listens on given port
EXPOSE $PORT

# Start FastAPI app with Uvicorn
CMD uvicorn src.app:app --host 0.0.0.0 --port $PORT
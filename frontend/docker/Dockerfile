# Start with a Python 3.11 slim image
FROM python:3.11.15-slim

# Upgrade pip to a newer version
RUN pip install --upgrade pip

# Install python libraries
# Use --no-cache-dir to avoid storing pip's download cache.
RUN pip install --no-cache-dir requests dotenv gradio
RUN pip install --no-cache-dir prometheus_client

# Install prometheus-node-exporter for container-level system metrics
RUN apt-get update && apt-get install -y prometheus-node-exporter && rm -rf /var/lib/apt/lists/*

# Set the working directory inside our container
WORKDIR /app

# Copy application source code into container
COPY src /app/src

# Import our Port (default 6161)
ARG PORT=6161
ENV PORT=$PORT

# Document that app listens on our port
# App port + metrics port (8001) + node exporter (9100)
EXPOSE $PORT 8001 9100

# Tell Gradio to listen on all network interfaces inside the container.
ENV GRADIO_SERVER_NAME=0.0.0.0

# Tell Gradio to use port 6767 inside the container.
ENV GRADIO_SERVER_PORT=$PORT

# Start node exporter in background, then start the app
CMD prometheus-node-exporter --web.listen-address=":9100" & \
    python src/app.py

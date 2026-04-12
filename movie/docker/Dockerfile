# Start with a Python 3.11 slim image
FROM python:3.11.15-slim

# Upgrade pip to a newer version
RUN pip install --upgrade pip

# Install python libraries
# Use --no-cache-dir to avoid storing pip's download cache.
RUN pip install --no-cache-dir requests fastapi pydantic uvicorn dotenv gradio
RUN pip install --no-cache-dir transformers torch huggingface_hub==1.6.0

# Install curl for healthcheck
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Set the working directory inside our container
WORKDIR /app

# Copy application source code into container
COPY src /app/src

# Tell Gradio to listen on all network interfaces inside the container.
ENV GRADIO_SERVER_NAME=0.0.0.0

# Tell Gradio to use port 6161 inside the container.
ENV GRADIO_SERVER_PORT=6161

# Document that app listens on given ports
EXPOSE 6060 6161

# Start FastAPI frontend app with Uvicorn
CMD ["bash","src/startup.sh"]
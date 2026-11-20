FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends procps iptables \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY auction_node.py .
# the container just stays alive; nodes are started with `docker exec`
CMD ["sleep", "infinity"]

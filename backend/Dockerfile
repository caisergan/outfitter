FROM python:3.11-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 && \
    rm -rf /var/lib/apt/lists/* && \
    useradd -m -u 1000 appuser

COPY --from=builder /install /usr/local
COPY . .

# Pre-download the CLIP model weights into the image so containers start fast
# and do not need network access at runtime to embed catalog items.
# XDG_CACHE_HOME steers torch / huggingface / open_clip caches into a path the
# runtime user (appuser) actually reads, instead of /root/.cache where they
# would land by default during this RUN.
ENV XDG_CACHE_HOME=/home/appuser/.cache
RUN mkdir -p "$XDG_CACHE_HOME" && \
    python -c "import open_clip; open_clip.create_model_and_transforms('ViT-B-32', pretrained='openai')" && \
    chown -R appuser:appuser /home/appuser

RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import httpx; httpx.get('http://localhost:8000/health').raise_for_status()"

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

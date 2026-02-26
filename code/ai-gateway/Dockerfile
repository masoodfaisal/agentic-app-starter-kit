# --- Stage 1: Builder ---
FROM quay.io/fedora/fedora:42 AS builder

# Fedora 42 ships Python 3.13 by default, install build deps
RUN dnf install -y python3 python3-pip python3-devel gcc && \
    dnf clean all

WORKDIR /build

# Install packages to a clean target directory (avoids path issues in runtime)
RUN python3 -m pip install --no-cache-dir --target=/install backoff litellm[proxy] uvicorn[standard] prisma

# --- Stage 2: Final Runtime ---
FROM quay.io/fedora/fedora-minimal:42

# microdnf is the package manager for fedora-minimal
RUN microdnf install -y python3 shadow-utils && \
    microdnf clean all

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /packages
COPY . .

# Create non-root user and ensure ownership
RUN useradd -m -r -s /bin/false appuser && \
    chown -R appuser:appuser /app && \
    chown -R appuser:appuser /packages

ENV PYTHONPATH="/packages" \
    PATH="/packages/bin:$PATH" \
    HOME=/tmp \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UVICORN_LOOP=asyncio

USER appuser

EXPOSE 4000

CMD ["litellm", "--config", "config.yaml", "--port", "4000", "--host", "0.0.0.0"]
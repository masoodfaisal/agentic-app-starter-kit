# --- Stage 1: Builder ---
FROM quay.io/fedora/fedora:42 AS builder

# Fedora 42 ships Python 3.13 by default, install build deps
RUN dnf install -y python3 python3-pip python3-devel gcc && \
    dnf clean all

WORKDIR /build
COPY requirements.txt .

# Install packages to a clean target directory (avoids path issues in runtime)
RUN python3 -m pip install --no-cache-dir --target=/install -r requirements.txt

# Download model all-MiniLM-L6-v2 from hugging face
RUN PYTHONPATH=/install python3 -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"


# --- Stage 2: Final Runtime ---
FROM quay.io/fedora/fedora-minimal:42

# microdnf is the package manager for fedora-minimal
RUN microdnf install -y python3 shadow-utils && \
    microdnf clean all

WORKDIR /app

# Copy downloaded model from builder
COPY --from=builder /root/.cache/huggingface /tmp/.cache/huggingface

# Copy installed packages from builder
COPY --from=builder /install /packages
COPY main.py tool.py .

# Create non-root user
RUN useradd -m -r -s /bin/false appuser && \
    chown -R appuser:appuser /app && \
    chown -R appuser:appuser /packages && \
    chown -R appuser:appuser /tmp/.cache

ENV PYTHONPATH="/packages" \
    HOME=/tmp \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

USER appuser

EXPOSE 8000

CMD ["python3", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]



# # --- Stage 1: Builder ---
# FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS builder
# # FROM quay.io/fedora/fedora:43 AS builder
# # TODO: go to 

# # Install build dependencies for Python and C-extensions (needed by uvicorn[standard])
# RUN dnf install -y python3.12 python3.12-pip python3.12-devel gcc && \
#     dnf clean all

# WORKDIR /build
# COPY requirements.txt .

# # Ensure .local directory exists and install packages there
# RUN mkdir -p /root/.local && \
#     python3.12 -m pip install --no-cache-dir --user -r requirements.txt


# # Download model all-MiniLM-L6-v2 from hugging face
# RUN python3.12 -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"

# # --- Stage 2: Final Runtime ---
# FROM public.ecr.aws/amazonlinux/amazonlinux:2023-minimal
# # FROM quay.io/fedora/fedora-minimal:43
# # Install only the runtime python and shadow-utils (for useradd)
# # microdnf is the package manager for the minimal image
# RUN microdnf install -y python3.12 shadow-utils && \
#     microdnf clean all && \
#     rm -rf /var/cache/yum

# WORKDIR /app

# # COPY downloaded model all-MiniLM-L6-v2 from builder image and copy it in the default location
# COPY --from=builder /root/.cache/huggingface /tmp/.cache/huggingface

# # Copy only the installed python packages from the builder
# COPY --from=builder /root/.local /home/appuser/.local
# COPY main.py tool.py .

# # Create non-root user
# RUN useradd -m -r -s /bin/false appuser && \
#     chown -R appuser:appuser /app && \
#     chown -R appuser:appuser /home/appuser/.local && \
#     chown -R appuser:appuser /tmp/.cache

# # Ensure the local pip bin and packages are in PATH/PYTHONPATH
# ENV PATH="/home/appuser/.local/bin:${PATH}" \
#     PYTHONPATH="/home/appuser/.local/lib/python3.12/site-packages" \
#     HOME=/tmp \
#     PYTHONDONTWRITEBYTECODE=1 \
#     PYTHONUNBUFFERED=1

# USER appuser

# EXPOSE 8000

# # HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
# #     CMD curl -f http://localhost:8000/health || exit 1

# CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]




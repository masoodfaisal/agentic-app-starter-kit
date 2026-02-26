# Simple Dockerfile to run Milvus standalone using the official image as a base
# This Dockerfile is intentionally minimal — it pulls the Milvus server image
# and exposes the default Milvus ports for gRPC and HTTP. For production,
# prefer the official docker-compose or Helm charts from Milvus project.

FROM milvusdb/milvus:v2.5.14

# Copy optional config if provided in the build context
# Uncomment and provide a milvus.yaml to customize configuration
# COPY milvus.yaml /etc/milvus/milvus.yaml

# Expose default Milvus ports
EXPOSE 19530 19121 9091

# Default entrypoint from the upstream image will start Milvus
CMD ["milvus", "run", "standalone"]

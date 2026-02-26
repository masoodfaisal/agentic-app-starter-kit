# Milvus Dockerfile

This folder contains a minimal Dockerfile to run Milvus standalone using the official Milvus image.

Build the image:

```bash
docker build -t local-milvus:2.3.0 .
```

Run locally (single container, ports forwarded):

```bash
docker run --rm -p 19530:19530 -p 9091:9091 local-milvus:2.3.0
```

Notes:
- For production use or multi-node setups, use Milvus official docker-compose or Helm charts.
- You can provide a custom `milvus.yaml` by uncommenting the `COPY` line in the Dockerfile and placing your config in this directory.

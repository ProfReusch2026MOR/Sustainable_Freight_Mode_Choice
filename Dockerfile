# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: Build frontend npm packages
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-slim AS frontend-builder

WORKDIR /app/web
COPY web/package.json ./
RUN npm install --omit=dev

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: Final runtime image
# ─────────────────────────────────────────────────────────────────────────────
FROM python:3.11-slim

# Metadata
LABEL org.opencontainers.image.title="OptiFreight Web Dashboard"
LABEL org.opencontainers.image.description="Interactive multimodal freight routing optimization dashboard"
LABEL org.opencontainers.image.source="https://github.com/ProfReusch2026MOR/Sustainable_Freight_Mode_Choice"

# Install Python dependencies first (layer-cached)
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy the freight routing library and heuristics
COPY freight_routing/ ./freight_routing/
COPY heuristics/ ./heuristics/

# Copy datasets (baked into the image for zero-config startup)
COPY dataset/ ./dataset/

# Copy web frontend
COPY web/ ./web/

# Copy pre-built node_modules from the frontend builder stage
COPY --from=frontend-builder /app/web/node_modules ./web/node_modules/

EXPOSE 8000

# Run the server from the project root so all relative imports resolve correctly
CMD ["python", "web/web_server.py", "8000"]

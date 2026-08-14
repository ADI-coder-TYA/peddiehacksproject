# Stage 1: Builder
FROM node:22-bookworm-slim AS builder

# Install build dependencies required by node-gyp and @tensorflow/tfjs-node
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy package files and install all dependencies (including devDependencies)
COPY package.json package-lock.json ./
RUN npm install

# Copy source code and build the project
COPY . .
RUN npm run build

# Stage 2: Production Runtime
FROM node:22-bookworm-slim AS production

# Install runtime dependencies required by TensorFlow C++ shared objects, poppler-utils, and tesseract
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libgomp1 \
    poppler-utils \
    tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Set environment variables
ENV NODE_ENV=production

# Copy compiled node_modules and dist folder from the builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/models ./models

# Set permissions for the non-root node user
RUN chown -R node:node /app/models

# Expose the API and Socket.io port
EXPOSE 3000

# Switch to the non-root user for security
USER node

# Start the compiled Node.js backend
CMD ["node", "dist/index.js"]

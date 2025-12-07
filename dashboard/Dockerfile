# Multi-stage build for React app
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig*.json ./
COPY vite.config.ts ./

# Install dependencies
RUN npm ci

# Copy source files
COPY src ./src
COPY index.html ./
COPY supabase.config.ts ./

# Build the app
RUN npm run build

# Production stage
FROM node:18-alpine

WORKDIR /app

# Copy package.json and install express
COPY package.json ./
RUN npm install express

# Copy built files and server
COPY --from=builder /app/dist ./dist
COPY server.js ./

# Expose port
EXPOSE 3000

ENV PORT=3000
ENV NODE_ENV=production

# Start server
CMD ["node", "server.js"]

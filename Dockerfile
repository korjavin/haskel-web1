# Multi-stage build for Haskell TicTacToe server
# Stage 1: Build the application
FROM haskell:9.6.3 AS builder

WORKDIR /app

# Copy package configuration files
COPY stack.yaml package.yaml ./

# Install dependencies (this layer will be cached)
RUN stack setup && stack build --only-dependencies

# Copy source code
COPY src/ ./src/

# Build the application
RUN stack build --copy-bins --local-bin-path /app/bin

# Stage 2: Create minimal runtime image
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    libgmp10 \
    netbase && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the compiled binary from builder
COPY --from=builder /app/bin/tictactoe-server /app/tictactoe-server

# Copy static files
COPY public/ /app/public/

# Expose port
EXPOSE 8080

# Run the server
CMD ["/app/tictactoe-server"]

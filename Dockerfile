# Multi-stage build for Haskell TicTacToe server
# Stage 1: Build the application
FROM fpco/stack-build:lts-22.28 AS builder

WORKDIR /app

# Copy package configuration
COPY stack.yaml package.yaml ./

# Create a dummy Main.hs to build dependencies
RUN mkdir -p src && \
    echo "module Main where" > src/Main.hs && \
    echo "main :: IO ()" >> src/Main.hs && \
    echo "main = putStrLn \"dummy\"" >> src/Main.hs

# Build dependencies only (this layer will be cached)
RUN stack build --only-dependencies

# Now copy the real source code
COPY src/ ./src/

# Build the actual application and clean up to save space
RUN stack build --copy-bins --local-bin-path /app/bin && \
    rm -rf .stack-work && \
    rm -rf /root/.stack/snapshots && \
    rm -rf /root/.stack/programs

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

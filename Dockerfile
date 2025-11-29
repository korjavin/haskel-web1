# Multi-stage build for Haskell TicTacToe server
# Stage 1: Build the application
FROM fpco/stack-build:lts-22.28 AS builder

WORKDIR /app

# Copy all project files
COPY stack.yaml package.yaml ./
COPY src/ ./src/

# Build the application with minimal parallelism to conserve resources
# Use --verbose to see detailed output if build fails
RUN stack build --copy-bins --local-bin-path /app/bin -j1 --no-terminal --verbose && \
    rm -rf .stack-work

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

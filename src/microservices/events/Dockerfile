FROM golang:1.23-alpine AS builder

WORKDIR /app

# Copy go mod file
COPY go.mod ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o events-service .

# Final image
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder
COPY --from=builder /app/events-service .

# Expose the application port
EXPOSE 8082

# Command to run the executable
CMD ["./events-service"]

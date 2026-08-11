# ---------- build stage ----------
FROM golang:1.25-alpine AS builder

WORKDIR /src

# Слой с зависимостями кешируется отдельно от исходников
COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG COMMIT=unknown
ARG VERSION=dev

RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w -X main.lastCommit=${COMMIT} -X main.version=${VERSION}" \
    -o /out/app .

# ---------- runtime stage ----------
FROM alpine:3.20

RUN adduser -D -u 10001 appuser
COPY --from=builder /out/app /app

USER appuser
EXPOSE 8080

ENTRYPOINT ["/app"]

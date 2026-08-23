# syntax=docker/dockerfile:1.7
#
# Re-introduced locally for the self-hosted deployments under .local/
# (upstream openlibrecommunity/olcrtc removed Docker support).
# Exact deployed source revision is stamped into the image label at build
# time (org.opencontainers.image.revision) - see .local/*/update.sh.
#
# Runtime entrypoint contract since the YAML-config refactor:
#   olcrtc <config.yaml>   (see .local/*/config.*.yaml)

ARG GO_VERSION=1.26
ARG ALPINE_VERSION=3.22

FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS build

WORKDIR /src

RUN apk add --no-cache ca-certificates git

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

COPY . .

ARG TARGETOS=linux
ARG TARGETARCH=amd64

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags="-s -w" -o /out/olcrtc ./cmd/olcrtc

FROM alpine:${ALPINE_VERSION} AS runtime

# Source revision baked into image metadata. .local/*/update.sh exports
# REVISION=$(git rev-parse HEAD); plain manual builds fall back to "dev".
ARG REVISION=dev
LABEL org.opencontainers.image.title="olcrtc (self-hosted build)" \
      org.opencontainers.image.revision=${REVISION} \
      org.opencontainers.image.source=https://github.com/openlibrecommunity/olcrtc

RUN apk add --no-cache ca-certificates tzdata && \
    addgroup -S olcrtc && \
    mkdir -p /var/lib/olcrtc && \
    adduser -S -D -h /var/lib/olcrtc -s /sbin/nologin -G olcrtc olcrtc && \
    chown -R olcrtc:olcrtc /var/lib/olcrtc

COPY --from=build /out/olcrtc /usr/local/bin/olcrtc

RUN chmod 0755 /usr/local/bin/olcrtc

USER olcrtc:olcrtc
WORKDIR /var/lib/olcrtc

VOLUME ["/var/lib/olcrtc"]

ENTRYPOINT ["/usr/local/bin/olcrtc"]
CMD ["--help"]

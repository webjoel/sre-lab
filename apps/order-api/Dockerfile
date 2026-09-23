# syntax=docker/dockerfile:1
# Fixado por digest: o build é reproduzível mesmo se a tag 1.27 for reescrita.
FROM golang:1.27@sha256:3680233e3204827fbdc66088528ae6d4b3d034f51d03a99d454f6de034888244 AS build
WORKDIR /src
# Dependências primeiro: esta camada só é refeita quando go.mod/go.sum mudam.
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download
COPY *.go ./
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/order-api .

# Imagem final: binário estático, sem shell, sem gerenciador de pacotes, usuário não-root.
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/order-api /order-api
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/order-api"]

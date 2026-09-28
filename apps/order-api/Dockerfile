# syntax=docker/dockerfile:1
# Versão exata (não 1.27): o build não muda sozinho quando sai um patch do Go.
FROM golang:1.27.1 AS build
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

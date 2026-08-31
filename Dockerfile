# syntax=docker/dockerfile:1

FROM node:22-alpine AS web-build
WORKDIR /web
# Vite bakes these into the JS bundle at build time, so they must be present
# here — web/.env is gitignored and never reaches this build context.
ARG VITE_KEYCLOAK_URL=https://auth.swaren.se
ARG VITE_KEYCLOAK_REALM=segel-cluster
ARG VITE_KEYCLOAK_CLIENT_ID=fiskekartan
ENV VITE_KEYCLOAK_URL=$VITE_KEYCLOAK_URL \
    VITE_KEYCLOAK_REALM=$VITE_KEYCLOAK_REALM \
    VITE_KEYCLOAK_CLIENT_ID=$VITE_KEYCLOAK_CLIENT_ID
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
RUN npm run build

FROM golang:1.25.5-alpine AS go-build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
COPY --from=web-build /web/dist ./web/dist
RUN CGO_ENABLED=0 go build -o /out/fiskekartan .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates && adduser -D -u 1000 app
COPY --from=go-build /out/fiskekartan /usr/local/bin/fiskekartan
USER app
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/fiskekartan"]

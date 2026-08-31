# syntax=docker/dockerfile:1

FROM node:22-alpine AS web-build
WORKDIR /web
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

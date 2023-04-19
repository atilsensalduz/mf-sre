FROM golang:1.18-bullseye as builder

RUN go install golang.org/dl/go1.18@latest \
    && go1.18 download

WORKDIR /build

COPY go.mod .
COPY go.sum .
COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GOAMD64=v3 go build -o ./app -tags timetzdata -trimpath .

FROM gcr.io/distroless/base-debian11

COPY --from=builder /build/app /app

ENTRYPOINT ["/app"]

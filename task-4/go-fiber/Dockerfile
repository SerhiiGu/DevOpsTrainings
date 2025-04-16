FROM golang:1.21-alpine

WORKDIR /app
COPY . .

RUN go mod init app && \
    go get ./... && \
    go build -o app

CMD ["./app"]

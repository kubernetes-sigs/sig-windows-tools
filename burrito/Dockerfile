FROM golang:1.16-alpine as builder

COPY . /burrito
WORKDIR /burrito
RUN go build

FROM alpine:latest as run
WORKDIR /root/
COPY --from=builder /burrito/burrito burrito
RUN chmod +x burrito

CMD ["./burrito", "serve", "-b"]
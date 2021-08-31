ARG BUILDER_IMAGE=golang:1.16-alpine
ARG RUN_IMAGE=alpine:latest

FROM ${BUILDER_IMAGE} as builder

COPY . /burrito
WORKDIR /burrito
RUN go build

FROM ${RUN_IMAGE} as run
WORKDIR /root/
COPY --from=builder /burrito/burrito burrito
RUN chmod +x burrito

CMD ["./burrito", "serve", "-b"]
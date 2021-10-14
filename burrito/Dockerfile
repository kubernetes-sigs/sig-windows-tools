ARG BUILDER_IMAGE=golang:1.16-alpine
ARG RUN_IMAGE=alpine:latest

FROM ${BUILDER_IMAGE} as builder

COPY . /burrito
WORKDIR /burrito
RUN go build

# Just create an empty one if it is not specified
RUN touch .versions

FROM ${RUN_IMAGE} as run

WORKDIR /root/
COPY --from=builder /burrito/burrito burrito
RUN chmod +x burrito

# Relative path in /burrito
ARG CONFIG_FILE=examples/burrito.yaml
COPY --from=builder /burrito/${CONFIG_FILE} .
RUN mv $(basename "${CONFIG_FILE}") .burrito.${CONFIG_FILE##*.} \
  && ls -la \
  && ./burrito build

# Relative path in /burrito
ARG VERSIONS_FILE=.versions
COPY --from=builder /burrito/${VERSIONS_FILE} .
RUN mv $(basename "${VERSIONS_FILE}") .versions

CMD ["./burrito", "serve"]

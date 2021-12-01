ARG BUILDER_IMAGE=golang:1.16
ARG RUN_IMAGE=ubuntu:latest

FROM ${BUILDER_IMAGE} as builder

COPY . /burrito
WORKDIR /burrito
RUN CGO_ENABLED=0 go build

# Just create an empty one if it is not specified
RUN touch .versions

FROM ${RUN_IMAGE} as run

WORKDIR /root/
COPY --from=builder /burrito/burrito burrito
RUN chmod 755 /root/burrito

# Relative path in /burrito
ARG CONFIG_FILE=examples/burrito.yaml
COPY --from=builder /burrito/${CONFIG_FILE} .
RUN mv $(basename "${CONFIG_FILE}") .burrito.${CONFIG_FILE##*.} && ls -la /root

RUN cp /root/burrito /bin/
RUN /bin/burrito build

# Relative path in /burrito
ARG VERSIONS_FILE=.versions
COPY --from=builder /burrito/${VERSIONS_FILE} .

# Might fail if file is the same
RUN mv $(basename "${VERSIONS_FILE}") .versions || echo "no mv"

CMD ["./burrito", "serve"]

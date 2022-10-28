FROM registry.access.redhat.com/ubi8-minimal:8.6 AS builder
 
RUN microdnf install -y tar gzip make which git

# install go 1.19.1
RUN curl -O -J https://dl.google.com/go/go1.19.1.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go1.19.1.linux-amd64.tar.gz
RUN ln -s /usr/local/go/bin/go /usr/local/bin/go

WORKDIR /workspace

COPY . ./

RUN go mod vendor 
RUN make binary

FROM registry.access.redhat.com/ubi8-minimal:8.6

COPY --from=builder /workspace/cos-fleet-manager /usr/local/bin/

EXPOSE 8000

ENTRYPOINT [ "/usr/local/bin/cos-fleet-manager" ]

LABEL name="cos-fleet-manager" \
      vendor="Red Hat" \
      version="0.0.1" \
      summary="CosFleetManager" \
      description="Connector Service Fleet Manager"
      
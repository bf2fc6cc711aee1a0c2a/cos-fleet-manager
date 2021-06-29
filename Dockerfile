FROM registry.access.redhat.com/ubi8/ubi-minimal:8.4

COPY \
    cos-fleet-manager \
    /usr/local/bin/

EXPOSE 8000

ENTRYPOINT ["/usr/local/bin/cos-fleet-manager", "serve"]

LABEL name="cos-fleet-manager" \
      vendor="Red Hat" \
      version="0.0.1" \
      summary="CosFleetManager" \
      description="Connector Service Fleet Manager"

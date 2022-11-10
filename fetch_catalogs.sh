#!/usr/bin/env bash
#
# Pull debezium and camel catalogs

DEBEZIUM_CATALOG=https://raw.githubusercontent.com/bf2fc6cc711aee1a0c2a/cos-fleet-catalog-debezium/main/templates/cos-fleet-catalog-debezium.yaml
CAMEL_CATALOGS=https://raw.githubusercontent.com/bf2fc6cc711aee1a0c2a/cos-manifests/main/connectors/cos-fleet-catalog-camel.yaml

clear

for f in $DEBEZIUM_CATALOG $CAMEL_CATALOGS; do
  echo Downloading $f
  curl -sS -o "templates/`basename ${f}`" ${f}
done
# Openshift Deployment Templates

The openshift deployment consists of 4 templates that, together, make an all-in-one deployment.

When deploying to production, the only template necessary is the service template.

## Service template

`templates/service-template.yml`

This is the main service template that deploys two objects, the `cos-fleet-manager` deployment and the related service.

## Route template

`templates/route-template.yml`

This template just deploys a route with the select `app:cos-fleet-manager` to map to the service deployed by the service template.

TLS is used by default for the route. No port is specified, all ports are allowed.

## Database template

`templates/db-template.yml`

This template deploys a simple postgresl-9.4 database deployment with a TLS-enabled service.

## Secrets template

`templates/secrets-template.yml`

This template deploys the `cos-fleet-manager` secret with all of the necessary secret key/value pairs.

## Connector Catalog templates

`templates/cos-fleet-catalog-*.yaml`

These template files are populated by the `fetch_catalogs.sh` script. These templates deploy config maps that contain json config for connector catalogs.

These connector config maps are referenced via the command line option `--connector-catalog` in `service-template.yml`.

## Connector Metadata templates

`templates/connector-metadata-*-configmap.yaml`

These template files deploy config maps that contain metadata configuration yaml files. The metadata in these templates is manually edited and maintained.
The metadata must be kept in sync with the connector catalog to make sure every connector id has associated metadata and any deleted/renamed connector ids are also updated in the metadata config.

These metadata config maps are referenced via the command line option `--connector-metadata` in `service-template.yml`.

## Envoy Config template

`templates/envoy-config-template.yml`

This template deploys the `cos-fleet-manager-envoy-config` ConfigMap that contains the Envoy
configuration for the `envoy-sidecar` container of the `cos-fleet-manager` Deployment.
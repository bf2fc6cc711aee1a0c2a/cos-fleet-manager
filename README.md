Connector Service Fleet Manager
---
![build status badge](https://github.com/bf2fc6cc711aee1a0c2a/cos-fleet-manager/actions/workflows/ci.yaml/badge.svg)

A service for provisioning and managing fleets of connector instances.

## Prerequisites
* [Golang 1.16+](https://golang.org/dl/)
* [Docker](https://docs.docker.com/get-docker/) - to create database
* [ocm cli](https://github.com/openshift-online/ocm-cli/releases) - ocm command line tool
* [Node.js v12.20+](https://nodejs.org/en/download/) and [npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm)

## Quick setup for integrations tests

> All of the steps bellow should be done in [kas-fleet-manager](https://github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager) project. This project is for build purposes only. 

1. If you haven't already, open an internal MR asking for the necessary access, similar to [this one](https://gitlab.cee.redhat.com/service/app-interface/-/merge_requests/30178/diffs).
2. [Generate a personal token](https://github.com/settings/tokens) for your own GitHub user with the `repo` access and save it somewhere safe.
3. Setup Keycloak Cert
    ```
    echo "" | openssl s_client -servername identity.api.stage.openshift.com -connect identity.api.stage.openshift.com:443 -prexit 2>/dev/null | sed -n -e '/BEGIN\ CERTIFICATE/,/END\ CERTIFICATE/ p' > secrets/keycloak-service.crt
    ```
4. Setup MAS SSO Client ID and Secret
    ```
    make keycloak/setup MAS_SSO_CLIENT_ID=<mas_sso_client_id> MAS_SSO_CLIENT_SECRET=<mas_sso_client_secret>
    ```
   > Values for the above variables can be found in [Vault](https://vault.devshift.net/ui/vault/secrets/managed-services-ci/show/MK-Control-Plane-CI/integration-tests). Log in using the Github token created earlier.
5. Touch 3 files just to mock them
   ```
   touch secrets/ocm-service.clientId
   touch secrets/ocm-service.clientSecret
   touch secrets/ocm-service.token
   ```
6. Set up database
    ```
    OCM_ENV=integration make db/setup
    ```
7. Run integration tests
    ```
    OCM_ENV=integration make test/integration/connector
    ```
8. Tear down test database (Optional)
    ```
    OCM_ENV=integration make db/teardown
    ```
   
## Data Plane OSD cluster setup
cos-fleet-manager can be started without a dataplane OSD cluster, however, no connectors will be placed or provisioned. To setup a data plane OSD cluster, please follow the [todo](#todo) guide.

## Populating Configuration
1. Retrieve your ocm-offline-token from https://qaprodauth.cloud.redhat.com/openshift/token and save it to `secrets/ocm-service.token` 
2. Setup AWS configuration
```
make aws/setup
```
3. Setup MAS SSO configuration
    - keycloak cert
    ```
    echo "" | openssl s_client -servername identity.api.stage.openshift.com -connect identity.api.stage.openshift.com:443 -prexit 2>/dev/null | sed -n -e '/BEGIN\ CERTIFICATE/,/END\ CERTIFICATE/ p' > secrets/keycloak-service.crt
    ```
    - mas sso client id & client secret
    ```
    make keycloak/setup MAS_SSO_CLIENT_ID=<mas_sso_client_id> MAS_SSO_CLIENT_SECRET=<mas_sso_client_secret> OSD_IDP_MAS_SSO_CLIENT_ID=<osd_idp_mas_sso_client_id> OSD_IDP_MAS_SSO_CLIENT_SECRET=<osd_idp_mas_sso_client_secret>
    ```
    > Values can be found in [Vault](https://vault.devshift.net/ui/vault/secrets/managed-services-ci/show/managed-service-api/integration-tests).
4. Setup the image pull secret
    - Image pull secret for RHOAS can be found in [Vault](https://vault.devshift.net/ui/vault/secrets/managed-services/show/quay-org-accounts/rhoas/robots/rhoas-pull), copy the content for the `config.json` key and paste it to `secrets/image-pull.dockerconfigjson` file.

## Running the Service locally
Please make sure you have followed all of the prerequisites above first.

1. Setup git to use your GitHub Personal Access token so that the go compiler 
   can download go modules that in private GitHub repositories.

    ```
   git config --global url."https://${username}:${access_token}@github.com".insteadOf "https://github.com"
    ```

   
2. Compile the binary
   ```
   make binary
   ```
   
3. Clean up and Creating the database
    - If you have db already created execute
    ```
    make db/teardown
    ```
    - Create database tables
    ```
    make db/setup && sleep 1 && make db/migrate
    ```
    - Optional - Verify tables and records are created
    ```
    make db/login
    ```
    ```
    # List all the tables
    cos-fleet-manager=# \dt
                             List of relations
     Schema |             Name              | Type  |       Owner       
    --------+-------------------------------+-------+-------------------
     public | connector_clusters            | table | cos-fleet-manager
     public | connector_deployment_statuses | table | cos-fleet-manager
     public | connector_deployments         | table | cos-fleet-manager
     public | connector_migrations          | table | cos-fleet-manager
     public | connector_shard_metadata      | table | cos-fleet-manager
     public | connector_statuses            | table | cos-fleet-manager
     public | connectors                    | table | cos-fleet-manager
     public | leader_leases                 | table | cos-fleet-manager
    (8 rows)
    ```

3. Start the service
    ```
    ./cos-fleet-manager serve
    ```
    >**NOTE**: The service has numerous feature flags which can be used to enable/disable certain features of the service. Please see the [feature flag](./docs/feature-flags.md) documentation for more information.

4. Verify the local service is working
    ```
    curl http://localhost:8000/api/connector_mgmt/v1/openapi
    ```

## Running the Service on an OpenShift cluster
### Build and Push the Image to the OpenShift Image Registry
Login to the OpenShift internal image registry

>**NOTE**: Ensure that the user used has the correct permissions to push to the OpenShift image registry. For more information, see the [accessing the registry](https://docs.openshift.com/container-platform/4.5/registry/accessing-the-registry.html#prerequisites) guide.
```
# Login to the OpenShift cluster
oc login <api-url> -u <username> -p <password>

# Login to the OpenShift image registry
make docker/login/internal
```

Build and push the image
```
# Create a namespace where the image will be pushed to.
make deploy/project

# Build and push the image to the OpenShift image registry.
GOARCH=amd64 GOOS=linux CGO_ENABLED=0 make image/build/push/internal
```

**Optional parameters**:
- `NAMESPACE`: The namespace where the image will be pushed to. Defaults to 'managed-services-$USER.'
- `IMAGE_TAG`: Tag for the image. Defaults to a timestamp captured when the command is run (i.e. 1603447837).

### Deploy the Service using Templates
This will deploy a postgres database and the cos-fleet-manager to a namespace in an OpenShift cluster.

```
# Deploy the service
make deploy OCM_SERVICE_TOKEN=<offline-token> IMAGE_TAG=<image-tag>
```
**Optional parameters**:
- `NAMESPACE`: The namespace where the service will be deployed to. Defaults to managed-services-$USER.
- `IMAGE_REGISTRY`: Registry used by the image. Defaults to the OpenShift internal registry.
- `IMAGE_REPOSITORY`: Image repository. Defaults to '\<namespace\>/cos-fleet-manager'.
- `IMAGE_TAG`: Tag for the image. Defaults to a timestamp captured when the command is run (i.e. 1603447837).
- `OCM_SERVICE_CLIENT_ID`: Client id used to interact with other UHC services.
- `OCM_SERVICE_CLIENT_SECRET`: Client secret used to interact with other UHC services.
- `OCM_SERVICE_TOKEN`: Offline token used to interact with other UHC services. If client id and secret is not defined, this parameter must be specified. See [user account setup](#user-account-setup) section on how to get this offline token.
- `AWS_ACCESS_KEY`: AWS access key. This is only required if you wish to create CCS clusters using the service.
- `AWS_ACCOUNT_ID`: AWS account ID. This is only required if you wish to create CCS clusters using the service.
- `AWS_SECRET_ACCESS_KEY`: AWS secret access key. This is only required if you wish to create CCS clusters using the service.
- `ENABLE_OCM_MOCK`: Enables mock ocm client. Defaults to false.
- `OCM_MOCK_MODE`: The type of mock to use when ocm mock is enabled. Defaults to 'emulate-server'.
- `JWKS_URL`: JWK Token Certificate URL. Defaults to https://api.openshift.com/.well-known/jwks.json.
- `ROUTE53_ACCESS_KEY`: AWS route 53 access key for creating CNAME records
- `ROUTE53_SECRET_ACCESS_KEY`: AWS route 53 secret access key for creating CNAME records
- `KAFKA_TLS_CERT`: Kafka TLS external certificate.
- `KAFKA_TLS_KEY`: Kafka TLS external certificate private key.
- `OBSERVATORIUM_SERVICE_TOKEN`: Token for observatorium service.
- `MAS_SSO_BASE_URL`: MAS SSO base url.
- `MAS_SSO_REALM`: MAS SSO realm url.
- `ALLOW_ANY_REGISTERED_USERS`: Enable to allow any registered users against redhat.com to access the service.
- `STRIMZI_OPERATOR_ADDON_ID`: The id of the Strimzi operator addon.

The service can be accessed by via the host of the route created by the service deployment.
```
oc get route cos-fleet-manager
```

### Removing the Service Deployment from the OpenShift
```
# Removes all resources created on service deployment
make undeploy
```

**Optional parameters**:
- `NAMESPACE`: The namespace where the service deployment will be removed from. Defaults to managed-services-$USER.

## Additional CLI commands

In addition to the REST API exposed via `make run`, there are additional commands to interact directly
with the service (i.e. cluster creation/scaling, Kafka creation, Errors list, etc.) without having to use a REST API client.

To use these commands, run `make binary` to create the `./cos-fleet-manager` CLI.

Run `./cos-fleet-manager -h` for information on the additional commands.
## Environments

The service can be run in a number of different environments. Environments are essentially bespoke
sets of configuration that the service uses to make it function differently. Environments can be
set using the `OCM_ENV` environment variable. Below are the list of known environments and their
details.

- `development` - The `staging` OCM environment is used. Sentry is disabled. Debugging utilities
   are enabled. This should be used in local development.
- `testing` - The OCM API is mocked/stubbed out, meaning network calls to OCM will fail. The auth
   service is mocked. This should be used for unit testing.
- `integration` - Identical to `testing` but using an emulated OCM API server to respond to OCM API
   calls, instead of a basic mock. This can be used for integration testing to mock OCM behaviour.
- `production` - Debugging utilities are disabled, Sentry is enabled. environment can be ignored in
   most development and is only used when the service is deployed.

## Contributing
See the [contributing guide](CONTRIBUTING.md) for general guidelines.


## Running the Tests
### Running unit tests
```
make test
```

### Running integration tests

Integration tests can be executed against a real or "emulated" OCM environment. Executing against
an emulated environment can be useful to get fast feedback as OpenShift clusters will not actually
be provisioned, reducing testing time greatly.

Both scenarios require a database and OCM token to be setup before running integration tests, run:

```
make db/setup
make ocm/setup OCM_OFFLINE_TOKEN=<ocm-offline-token> OCM_ENV=development
```

To run integration tests with an "emulated" OCM environment, run:

```
OCM_ENV=integration make test/integration
```

To run integration tests with a real OCM environment, run:

```
make test/integration
```

To stop and remove the database container when finished, run:
```
make db/teardown
```

### Running performance tests
See this [README](./test/performance/README.md) for more info about performance tests

## Additional documentation:
* todo

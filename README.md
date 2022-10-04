Connector Service Fleet Manager
---
![build status badge](https://github.com/bf2fc6cc711aee1a0c2a/cos-fleet-manager/actions/workflows/ci.yaml/badge.svg)

A service for provisioning and managing fleets of connector instances.

## Prerequisites
* [Golang 1.19+](https://golang.org/dl/)
* [Docker](https://docs.docker.com/get-docker/) - to create database
* [ocm cli](https://github.com/openshift-online/ocm-cli/releases) - ocm command line tool
* [Node.js v12.20+](https://nodejs.org/en/download/) and [npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm)

## Setup for integrations tests

> All of the steps for integration tests should be done in [kas-fleet-manager](https://github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager) project. This project is for build or running the service. 

1. If you haven't already, open an internal MR asking for the necessary access, similar to [this one](https://gitlab.cee.redhat.com/service/app-interface/-/merge_requests/30178/diffs).
2. [Generate a personal token](https://github.com/settings/tokens) for your own GitHub user with the `repo` access and save it somewhere safe.
3. Setup Keycloak Cert
    ```
    echo "" | openssl s_client -servername identity.api.stage.openshift.com -connect identity.api.stage.openshift.com:443 -prexit 2>/dev/null | sed -n -e '/BEGIN\ CERTIFICATE/,/END\ CERTIFICATE/ p' > secrets/keycloak-service.crt
    ```
4. Setup local keycloak
    ```
    make sso/setup
    make sso/config
    make keycloak/setup MAS_SSO_CLIENT_ID=kas-fleet-manager MAS_SSO_CLIENT_SECRET=kas-fleet-manager OSD_IDP_MAS_SSO_CLIENT_ID=kas-fleet-manager OSD_IDP_MAS_SSO_CLIENT_SECRET=kas-fleet-manager
    ```
5. Touch 3 files to mock them
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
8. When done, tear down test database and keycloak
    ```
    OCM_ENV=integration make db/teardown
    make sso/teardown
    ```

## Setup for running the Service locally

> Steps may seem similar to the previous ones, but in this case all the steps for building and running the service should be done in this project, cos-fleet-manager.

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
   Or, if using SSO_PROVIDER=redhat_sso setup Redhat SSO Client ID and Secret
    ```
    make redhat/sso SSO_CLIENT_ID=<redhat_sso_client_id> SSO_CLIENT_SECRET=<redhat_sso_client_secret>
    ```
    > Values for the above variables can be found in [Vault](https://vault.devshift.net/ui/vault/secrets/managed-services-ci/show/MK-Control-Plane-CI/integration-tests). Log in using the Github token created earlier.
5. Touch files just to mock them
   ```
   touch secrets/ocm-service.clientId
   touch secrets/ocm-service.clientSecret
   touch secrets/ocm-service.token
   touch secrets/osd-idp-keycloak-service.clientSecret
   touch secrets/osd-idp-keycloak-service.clientId
   ```
6. Setup git to use your GitHub Personal Access token so that the go compiler can download go modules in private GitHub repositories.
    ```
   git config --global url."https://${username}:${access_token}@github.com".insteadOf "https://github.com"
    ```
   **Note:** You may also use the [GitHub CLI](https://cli.github.com/manual/gh_auth) to set this up.
7. Compile the binary
   ```
   make binary
   ```
8. Set up database
    ```
    make db/setup && sleep 1 && make db/migrate
    ```
9. (Optional) Verify tables and records are created
    ```
    make db/login
    ```
    ```
    # List all the tables with the "\dt" command
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
10. Start the service
    ```
    ./cos-fleet-manager serve
    ```
   >**NOTE**: The service has numerous feature flags which can be used to enable/disable certain features of the service. Please see the [feature flag](https://github.com/bf2fc6cc711aee1a0c2a/kas-fleet-manager/blob/main/docs/feature-flags.md) documentation for more information. Be aware many of those properties may only apply to the kas-fleet-manager.
11. Verify the local service is working
    ```
    curl http://localhost:8000/api/connector_mgmt/v1/openapi
    ```
12 (Optional) Tear down database
   ```
   make db/teardown
   ```

### Setting up a local connector catalog
At this point the service is running, but that are no connectors available to create. You have to point the application to a directory with the connector definitions so they are available.
1. Clone the [cos-fleet-catalog-camel](https://github.com/bf2fc6cc711aee1a0c2a/cos-fleet-catalog-camel) project
2. Do a `mvn clean package`
3. Connectors schemas will be generated inside `cos-fleet-catalog-camel/etc/connectors/<category name>`
4. Go back to the cos-fleet-manager and run with all the connectors that were generated:
```
./cos-fleet-manager serve \
--connector-catalog=../cos-fleet-catalog-camel/etc/connectors/connector-catalog-camel-aws \
--connector-catalog=../cos-fleet-catalog-camel/etc/connectors/connector-catalog-camel-azure \
--connector-catalog=../cos-fleet-catalog-camel/etc/connectors/connector-catalog-camel-gcp \
--connector-catalog=../cos-fleet-catalog-camel/etc/connectors/connector-catalog-camel-misc \
--connector-catalog=../cos-fleet-catalog-camel/etc/connectors/connector-catalog-camel-nosql \
--connector-catalog=../cos-fleet-catalog-camel/etc/connectors/connector-catalog-camel-social \
--connector-catalog=../cos-fleet-catalog-camel/etc/connectors/connector-catalog-camel-sql \
--connector-catalog=../cos-fleet-catalog-camel/etc/connectors/connector-catalog-camel-storage
``` 
5. You may provide more connectors from other catalogs, like [Debezium](https://github.com/bf2fc6cc711aee1a0c2a/cos-fleet-catalog-debezium).

## Data Plane OSD cluster setup
cos-fleet-manager can be started without a dataplane OSD cluster, however, no connectors will be placed or provisioned. To setup your dataplane, see [cos-fleetshard](https://github.com/bf2fc6cc711aee1a0c2a/cos-fleetshard).

>**NOTE**: For all of the tools from the cos-fleetshard to work correctly it is necessary to add the `public-host-url` flag to run the fleet-manager.
>```
>./cos-fleet-manager serve --public-host-url=$COS_BASE_PATH
>```

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
- `JWKS_URL`: JWK Token Certificate URL.
- `TOKEN_ISSUER_URL`: A token issuer url used to validate if JWT token used are coming from the given issuer. Defaults to `https://sso.redhat.com/auth/realms/redhat-external`.
- `ROUTE53_ACCESS_KEY`: AWS route 53 access key for creating CNAME records
- `ROUTE53_SECRET_ACCESS_KEY`: AWS route 53 secret access key for creating CNAME records
- `KAFKA_TLS_CERT`: Kafka TLS external certificate.
- `KAFKA_TLS_KEY`: Kafka TLS external certificate private key.
- `OBSERVATORIUM_SERVICE_TOKEN`: Token for observatorium service.
- `MAS_SSO_BASE_URL`: MAS SSO base url.
- `MAS_SSO_REALM`: MAS SSO realm url.
- `SSO_PROVIDER_TYPE`: Option to choose between sso providers i.e, mas_sso or redhat_sso, mas_sso by default.
- `ADMIN_AUTHZ_CONFIG`: Configuration file containing endpoints and roles mappings used to grant access to admin API endpoints, Defaults to`"[{method: GET, roles: [cos-fleet-manager-admin-read, cos-fleet-manager-admin-write, cos-fleet-manager-admin-full]}, {method: PATCH, roles: [cos-fleet-manager-admin-write, cos-fleet-manager-admin-full]}, {method: PUT, roles: [cos-fleet-manager-admin-write, cos-fleet-manager-admin-full]}, {method: POST, roles: [cos-fleet-manager-admin-full]}, {method: DELETE, roles: [cos-fleet-manager-admin-full]}]"`
- `ADMIN_API_SSO_BASE_URL`: Base URL of admin API endpints SSO. Defaults to `"https://auth.redhat.com"`
- `ADMIN_API_SSO_ENDPOINT_URI`: admin API SSO endpoint URI. defaults to `"/auth/realms/EmployeeIDP"`
- `ADMIN_API_SSO_REALM`: admin API SSO realm. Defaults to `"EmployeeIDP"`
- `CONNECTOR_ENABLE_UNASSIGNED_CONNECTORS`: Enable support for `unassigned` state for connectors
- `CONNECTOR_EVAL_DURATION`: Connector evaluation namespace expiry duration in Golang duration format, default is 48h
- `CONNECTOR_EVAL_ORGANIZATIONS`: Organization IDs for clusters to be used to create evaluation namespaces
- `CONNECTOR_NAMESPACE_LIFECYCLE_API`: Enable support for public APIs to create and delete non-evaluation namespaces
- `CONNECTORS_EVAL_NAMESPACE_QUOTA_PROFILE`: Name of quota profile for evaluation namespaces
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

### Running integration tests against a real OCM environment

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

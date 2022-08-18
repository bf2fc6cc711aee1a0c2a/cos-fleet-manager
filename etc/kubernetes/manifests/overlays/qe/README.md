## Customization to deploy a fully functional control plane

To set up, run

```
kubectl create ns redhat-openshift-connectors
kubectl create secret generic addon-pullsecret --from-literal=.dockerconfigjson="$RHOAS_QUAY_DOCKER_CONFIG_JSON" --type=kubernetes.io/dockerconfigjson

export BASE_INGRESS=$(kubectl get ingresses.config/cluster -o jsonpath={.spec.domain})
export AWS_ACCESS_KEY=...
export AWS_SECRET_ACCESS_KEY=...
kubectl apply -k .
```

To call admin api, obtain token first:

```
TOKEN=$(curl -d 'client_id=rhoas-cli-prod' -d 'username=rhoc-sre-admin' -d 'password=supersecret' -d 'grant_type=password' -S -s $KC_BASE_PATH/auth/realms/rhoas-kafka-sre/protocol/openid-connect/token | jq -r .access_token )
```

and then use it when calling the api:

```
curl -L --oauth2-bearer "$TOKEN" -S -s $COS_BASE_PATH/api/connector_mgmt/v1/admin/kafka_connector_clusters/ | jq
```

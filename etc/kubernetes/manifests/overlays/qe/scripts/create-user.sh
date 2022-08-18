#!/bin/bash

set -e
set -x

# wait for keycloak to deploy
kubectl wait --for=condition=Available deployment/cos-fleet-manager-kc
KC_BASE_PATH=https://$(kubectl get route cos-fleet-manager-kc -o jsonpath={.spec.host})

# obtain token for keycloak admin (lasts 60s, should be enough)
ADMIN_TOKEN=$(curl -d 'username=admin' -d "password=admin" -d 'grant_type=password' -d 'client_id=admin-cli' $KC_BASE_PATH/auth/realms/master/protocol/openid-connect/token | jq -r .access_token)

# new rhoc admin user to create
USERNAME=rhoc-sre-admin
PASSWORD=supersecret
USER_JSON='{"username":"'$USERNAME'","enabled":true,"emailVerified":true,"access":{"manageGroupMembership":true,"view":true,"mapRoles":true,"impersonate":true,"manage":true}}'

# create rhoc admin user
curl -L -H "Content-Type: application/json"  -d "$USER_JSON" --insecure --oauth2-bearer "$ADMIN_TOKEN" -S -s $KC_BASE_PATH/auth/admin/realms/rhoas-kafka-sre/users

# get new user uuid
ADMIN_ID=$(curl -L --insecure --oauth2-bearer "$ADMIN_TOKEN" -S -s $KC_BASE_PATH/auth/admin/realms/rhoas-kafka-sre/users | jq -r '.[] | select(.username=="'$USERNAME'") | .id')

# get all roles
ROLES=$(curl -L -H "Content-Type: application/json"  --insecure --oauth2-bearer "$ADMIN_TOKEN" -S -s $KC_BASE_PATH/auth/admin/realms/rhoas-kafka-sre/roles )

# apply all roles to the admin user
curl -L --insecure -H "Content-Type: application/json"  -d "$ROLES" --oauth2-bearer "$ADMIN_TOKEN" -S -s $KC_BASE_PATH/auth/admin/realms/rhoas-kafka-sre/users/$ADMIN_ID/role-mappings/realm

# set admin user password
PASSWORD_JSON='{"type":"password","temporary":false,"value":"'$PASSWORD'"}'
curl -L --insecure -H "Content-Type: application/json"  -d "$PASSWORD_JSON" -X PUT --oauth2-bearer "$ADMIN_TOKEN" -S -s $KC_BASE_PATH/auth/admin/realms/rhoas-kafka-sre/users/$ADMIN_ID/reset-password

FRONTEND_URL=$KC_BASE_PATH/auth
# set realm frontend url
curl -L --insecure --oauth2-bearer "$ADMIN_TOKEN" -X PUT -d '{"attributes": {"frontendUrl": "'$FRONTEND_URL'"}}' -H "Content-Type: application/json"   -S -s $KC_BASE_PATH/auth/admin/realms/rhoas-kafka-sre
curl -L --insecure --oauth2-bearer "$ADMIN_TOKEN" -X PUT -d '{"attributes": {"frontendUrl": "'$FRONTEND_URL'"}}' -H "Content-Type: application/json"   -S -s $KC_BASE_PATH/auth/admin/realms/rhoas


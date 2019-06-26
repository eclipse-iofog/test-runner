#!/usr/bin/env bash

. functions.bash

NAMESPACE="${NAMESPACE:-iofog}"

if [[ CONTEXT=$(kubectl config current-context) ]]; then
  echo "Found kubernetes context, using ${CONTEXT} to retrieve configuration..."
  CONTROLLER_URL=$(kubectl -n "${NAMESPACE}" get svc controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}:{.spec.ports[0].port}')
  CONNECTOR_URL=$(kubectl -n "${NAMESPACE}" get svc connector -o jsonpath='{.status.loadBalancer.ingress[0].ip}:{.spec.ports[0].port}')
fi

CONTROLLER_HOST="http://${CONTROLLER_URL}/api/v3"
CONTROLLER_EMAIL="${CONTROLLER_EMAIL:-user@domain.com}"
CONTROLLER_PASSWORD="${CONTROLLER_PASSWORD:-#Bugs4Fun}"

CONNECTOR_HOST="http://${CONNECTOR_URL}/api/v2"

# Agents are comma separated URI
#
# Example:
#     root@1.2.3.4:6451,user@6.7.8.9
#
# Note that you need to mount appropriate ssh keys to /root/.ssh
IFS=',' read -r -a AGENTS_ARR <<< "${AGENTS}"

echo "AGENTS: $AGENTS"
echo "AGENTS_ARR: ${AGENTS_ARR}"
echo "AGENTS_ARR: ${AGENTS_ARR[@]}"
echo "AGENTS_ARR_LEN: ${#AGENTS_ARR[@]}"

echo "----------   CONFIGURATION   ----------
[CONTROLLER]
$CONTROLLER

[CONNECTOR]
$CONNECTOR

[AGENTS]
${AGENTS_ARR[@]}
"


function waitForController() {
  while true; do
    STATUS=$(curl --request GET --url "${CONTROLLER_HOST}/status" 2>/dev/null | jq -r ".status")
    [[ "${STATUS}" == "online" ]] && break || echo "Waiting for Controller ${CONTROLLER_HOST}..."
    sleep 2
  done
  echo "Controller ${CONTROLLER_HOST} is ready."
}

function waitForConnector() {
  while true; do
    STATUS=$(curl --request POST --url "${CONNECTOR_HOST}/status" \
                  --header 'Content-Type: application/x-www-form-urlencoded' --data mappingid=all 2>/dev/null \
             | jq -r '.status')
    [[ "${STATUS}" == "running" ]] && break || echo "Waiting for Connector..."
    sleep 2
  done
  echo "Connector ${CONNECTOR_HOST} is ready."
}

#waitForController
#waitForConnector


echo "Waiting for Agents to provision with Controller..."

for AGENT in "${AGENTS_ARR[@]}"; do
  USERNAME_HOST="${AGENT%:*}"
  PORT="${AGENT##*:}"
  while true; do
    STATUS=$(ssh -o StrictHostKeyChecking=no "${USERNAME_HOST}" -p "${PORT}" sudo iofog-agent status | grep 'Connection to Controller')
    [[ "${STATUS}" == *"ok"* ]] && break || echo "Waiting for Agent ${AGENT}..."
    sleep 2
  done
  echo "Agent ${AGENT_HOST} is ready."
done

echo "---------- ----------------- ----------
"

ERR=0
echo "----------    SMOKE TESTS    ----------"
pyresttest http://"$CONTROLLER":51121 tests/smoke/controller.yml ; (( ERR |= "$?" ))
# TODO: (Serge) Enable Connector tests when Connector is stable
#pyresttest http://"$CONNECTOR":8080 tests/smoke/connector.yml ; (( ERR |= "$?" ))
bats tests/smoke/agent.bats
echo "---------- ----------------- ---------- "

echo "---------- INTEGRATION TESTS ----------"
# Spin up microservices
for IDX in "${!AGENTS[@]}"; do
  export IDX
  pyresttest http://"$CONTROLLER":51121 tests/integration/deploy-weather.yml ; (( ERR |= "$?" ))
done

# TODO: (Serge) Enable these tests when TestRunner container can hit Microservice endpoints
## Test microservices
#for IDX in "${!AGENTS[@]}"; do
#  export IDX
#  # Set endpoint to test microservice
#  ENDPOINT=host.docker.internal:5555
#  if [[ -z "$LOCAL" ]]; then
#    HOST="${AGENTS[$IDX]}"
#    ENDPOINT="${HOST##*@}":5555
#  fi
#
#  # Wait for, and curl the microservices
#  echo "Waiting for endpoint: $ENDPOINT"
#  waitFor http://"$ENDPOINT" 180
#  pyresttest http://"$ENDPOINT" tests/integration/test-weather.yml ; (( ERR |= "$?" ))
#done

# Teardown microservices
for IDX in "${!AGENTS[@]}"; do
  export IDX
  pyresttest http://"$CONTROLLER":51121 tests/integration/destroy-weather.yml ; (( ERR |= "$?" ))
done
echo "---------- ----------------- ----------
"

echo "---------- K4G TESTS ----------"
bats tests/k4g/k4g.bats
echo "---------- ----------------- ----------
"

echo "---------- IOFOGCTL TESTS ----------"
bats tests/iofogctl/iofogctl.bats
echo "---------- ----------------- ----------
"
exit 0

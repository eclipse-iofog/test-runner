#!/usr/bin/env bash

set -o noclobber -o nounset

function loadConfiguration() {
  NAMESPACE="${NAMESPACE:-iofog}"
  CONTROLLER_URL="${CONTROLLER_URL:-}"
  CONNECTOR_URL="${CONNECTOR_URL:-}"
  AGENTS="${AGENTS:-}"
  AGENTS_ARR=()

  CONTEXT=$(kubectl config current-context 2>/dev/null)
  if [[ -n "${CONTEXT}" ]]; then
    echo "Found kubernetes context, using ${CONTEXT} to retrieve configuration..."
    CONTROLLER_URL=$(kubectl -n "${NAMESPACE}" get svc controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}:{.spec.ports[0].port}')
    CONNECTOR_URL=$(kubectl -n "${NAMESPACE}" get svc connector -o jsonpath='{.status.loadBalancer.ingress[0].ip}:{.spec.ports[0].port}')
  fi

  CONTROLLER_HOST="http://${CONTROLLER_URL}/api/v3"
  CONTROLLER_EMAIL="${CONTROLLER_EMAIL:-user@domain.com}"
  CONTROLLER_PASSWORD="${CONTROLLER_PASSWORD:-#Bugs4Fun}"

  CONNECTOR_HOST="http://${CONNECTOR_URL}/api/v2"

  IFS=',' read -r -a AGENTS_ARR <<< "${AGENTS}"

  echo "--- CONFIGURATION ---"
  echo -n "Controller: "
  if [[ -n "${CONTROLLER_URL}" ]]; then
    echo "${CONTROLLER_URL} (username: ${CONTROLLER_EMAIL}, password: $(echo "${CONTROLLER_PASSWORD}" | sed -r 's/./*/g'))"
  fi
  echo
  echo -n "Connector: "
  if [[ -n "${CONNECTOR_URL}" ]]; then
    echo "${CONNECTOR_URL}"
  fi
  echo
  echo -n "Agents: "
  if [[ ${#AGENTS_ARR[@]} -gt 0 ]]; then
    echo "${AGENTS_ARR[@]}"
  fi
  echo
}


function checkController() {
  local CONTROLLER_HOST="$1"
  local STATUS=$(curl --request GET --url "${CONTROLLER_HOST}/status" 2>/dev/null | jq -r ".status")
  if [[ "${STATUS}" != "online" ]]; then
    echo "Controller ${CONTROLLER_HOST} not ready..."
    echo "${STATUS}"
    exit 1
  fi
  echo "Controller ${CONTROLLER_HOST} is ready."
}

function checkConnector() {
  local CONNECTOR_HOST="$1"
  local STATUS=$(curl --request POST --url "${CONNECTOR_HOST}/status" \
                --header 'Content-Type: application/x-www-form-urlencoded' --data mappingid=all 2>/dev/null \
             | jq -r '.status')
  if [[ "${STATUS}" != "running" ]]; then
    echo "Connector ${CONNECTOR_HOST} not ready..."
    echo "${STATUS}"
    exit 1
  fi
  echo "Connector ${CONNECTOR_HOST} is ready."
}

function checkAgent() {
  local AGENT="$1"
  local USERNAME_HOST="${AGENT%:*}"
  local PORT="$(echo "${AGENT}" | cut -d':' -s -f2)"
  local PORT="${PORT:-22}"
  while true; do
    echo "Waiting for Agent ${USERNAME_HOST}:${PORT}..."
    STATUS=$(ssh -o StrictHostKeyChecking=no "${USERNAME_HOST}" -p "${PORT}" sudo iofog-agent status | grep 'Connection to Controller')
    [[ "${STATUS}" == *"ok"* ]] && continue || echo "${STATUS}"
    exit 1
  done
  echo "Agent ${AGENT} is ready."

}

loadConfiguration
[[ -n "${CONTROLLER_URL}" ]] && checkController "${CONTROLLER_HOST}"
[[ -n "${CONTROLLER_URL}" ]] && checkConnector "${CONNECTOR_HOST}"
#for AGENT in "${AGENTS_ARR[@]}"; do checkAgent "${AGENT}"; done


if [[ -n "${CONTROLLER_HOST}" ]] && [[ -n "${CONTROLLER_EMAIL}" ]] && [[ -n "${CONTROLLER_PASSWORD}" ]]; then
  echo "--- Running CONTROLLER SMOKE TEST SUITE ---"
  pyresttest http://"${CONTROLLER_URL}":51121 tests/smoke/controller.yml
  SUITE_CONTROLLER_SMOKE_STATUS=$?
else
  echo "--- Skipped CONTROLLER SMOKE TEST SUITE ---"
  echo "Insufficient configuration to run this test suite!"
  SUITE_CONTROLLER_SMOKE_STATUS="SKIPPED"
fi


# TODO: (Serge) Enable Connector tests when Connector is stable
echo "--- Skipped CONNECTOR SMOKE TEST SUITE ---"
#pyresttest http://"${CONNECTOR_URL}":8080 tests/smoke/connector.yml ; (( ERR |= "$?" ))
SUITE_CONNECTOR_SMOKE_STATUS="SKIPPED"

if [[ ${#AGENTS_ARR[@]} -gt 0 ]]; then
  echo "--- Running AGENT SMOKE TEST SUITE ---"
  bats tests/smoke/agent.bats
  SUITE_AGENT_SMOKE_STATUS=$?
else
  echo "--- Skipped AGENT SMOKE TEST SUITE ---"
  echo "Insufficient configuration to run this test suite!"
  SUITE_AGENT_SMOKE_STATUS="SKIPPED"
fi


if [[ ${#AGENTS_ARR[@]} -gt 0 ]] && [[ -n "${CONTROLLER_HOST}" ]] && [[ -n "${CONTROLLER_EMAIL}" ]] && [[ -n "${CONTROLLER_PASSWORD}" ]]; then
  echo "--- Running BASIC INTEGRATION TEST SUITE ---"
  # Spin up microservices
  for IDX in "${!AGENTS_ARR[@]}"; do
    export IDX
    pyresttest http://"${CONTROLLER_URL}":51121 tests/integration/deploy-weather.yml
    if [[ $? -gt 0 ]]; then
      SUITE_BASIC_INTEGRATION_STATUS=$?
      break;
    fi
  done
  for IDX in "${!AGENTS_ARR[@]}"; do
    export IDX
    pyresttest http://"{CONTROLLER_URL}":51121 tests/integration/destroy-weather.yml
     if [[ $? -gt 0 ]]; then
      SUITE_BASIC_INTEGRATION_STATUS=$?
      break;
    fi
  done
  SUITE_BASIC_INTEGRATION_STATUS=0
else
  echo "--- Skipped BASIC INTEGRATION TEST SUITE ---"
  echo "Insufficient configuration to run this test suite!"
  SUITE_BASIC_INTEGRATION_STATUS="SKIPPED"
fi


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

# TODO: (lkrcal) Enable these tests when ready for a pipeline
#bats tests/k4g/k4g.bats
SUITE_KUBERNETES_STATUS="SKIPPED"
#bats tests/iofogctl/iofogctl.bats
SUITE_IOFOGCTL_STATUS="SKIPPED"


echo "--- Test Results: ---

SUITE_CONTROLLER_SMOKE_STATUS:  ${SUITE_CONTROLLER_SMOKE_STATUS}
SUITE_CONNECTOR_SMOKE_STATUS:   ${SUITE_CONNECTOR_SMOKE_STATUS}
SUITE_AGENT_SMOKE_STATUS:       ${SUITE_AGENT_SMOKE_STATUS}
SUITE_BASIC_INTEGRATION_STATUS: ${SUITE_BASIC_INTEGRATION_STATUS}
SUITE_KUBERNETES_STATUS:        ${SUITE_KUBERNETES_STATUS}
SUITE_IOFOGCTL_STATUS:          ${SUITE_IOFOGCTL_STATUS}
"

if [[ "${SUITE_CONTROLLER_SMOKE_STATUS}" =~ ^(0|SKIPPED)$ ]] && \
   [[ "${SUITE_CONNECTOR_SMOKE_STATUS}" =~ ^(0|SKIPPED)$ ]] && \
   [[ "${SUITE_AGENT_SMOKE_STATUS}" =~ ^(0|SKIPPED)$ ]] && \
   [[ "${SUITE_BASIC_INTEGRATION_STATUS}" =~ ^(0|SKIPPED)$ ]] && \
   [[ "${SUITE_KUBERNETES_STATUS}" =~ ^(0|SKIPPED)$ ]] && \
   [[ "${SUITE_IOFOGCTL_STATUS}" =~ ^(0|SKIPPED)$ ]]; then
  echo "--- SUCCESS ---"
  exit 0
else
  echo "--- SOME TESTS FAILED ---"
  exit 1
fi

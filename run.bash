#!/usr/bin/env bash

set -o noclobber -o nounset

TEST_TOTAL_COUNT=0
TEST_SUCCESS_COUNT=0
TEST_SKIPPED_COUNT=0
TEST_FAILURE_COUNT=0

function loadConfiguration() {
  NAMESPACE="${NAMESPACE:-iofog}"
  CONTROLLER="${CONTROLLER:-}"
  CONNECTOR="${CONNECTOR:-}"
  CONTROLLER_HOST=""
  CONTROLLER_EMAIL="${CONTROLLER_EMAIL:-user@domain.com}"
  CONTROLLER_PASSWORD="${CONTROLLER_PASSWORD:-#Bugs4Fun}"
  CONNECTOR_HOST=""
  AGENTS="${AGENTS:-}"
  AGENTS_ARR=()

  # TODO: (lkrcal) move this to k8s deployment (init containers or such), this script should not be k8s aware
  CONTEXT=$(kubectl config current-context 2>/dev/null)
  if [[ -n "${CONTEXT}" ]]; then
    echo "Found kubernetes context, using ${CONTEXT} to retrieve configuration..."
    CONTROLLER=$(kubectl -n "${NAMESPACE}" get svc controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}:{.spec.ports[0].port}')
    CONNECTOR=$(kubectl -n "${NAMESPACE}" get svc connector -o jsonpath='{.status.loadBalancer.ingress[0].ip}:{.spec.ports[0].port}')
  fi

  if [[ -n "${CONTROLLER}" ]]; then
    CONTROLLER_HOST="http://${CONTROLLER}/api/v3"
  fi

  if [[ -n "${CONNECTOR}" ]]; then
    CONNECTOR_HOST="http://${CONNECTOR}/api/v2"
  fi

  IFS=',' read -r -a AGENTS_ARR <<< "${AGENTS}"

  echo "--- CONFIGURATION ---"
  echo -n "Controller: "
  if [[ -n "${CONTROLLER}" ]]; then
    echo -n "${CONTROLLER} (username: ${CONTROLLER_EMAIL}, password: $(echo "${CONTROLLER_PASSWORD}" | sed -r 's/./*/g'))"
  fi
  echo
  echo -n "Connector: "
  if [[ -n "${CONNECTOR}" ]]; then
    echo -n "${CONNECTOR}"
  fi
  echo
  echo -n "Agents: "
  if [[ ${#AGENTS_ARR[@]} -gt 0 ]]; then
    echo -n "${AGENTS_ARR[@]}"
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
  echo "Waiting for Agent ${USERNAME_HOST}:${PORT}..."
  STATUS="$(ssh -o StrictHostKeyChecking=no "${USERNAME_HOST}" -p "${PORT}" sudo iofog-agent status | grep 'Connection to Controller')"
  if [[ "${STATUS}" != *"ok"* ]]; then
    echo "Agent ${USERNAME_HOST}:${PORT} not ready!"
    echo "${STATUS}"
    exit 1
  fi
  echo "Agent ${AGENT} is ready."
}

function printSuiteResult() {
  local SUITE_STATUS="$1"
  if [[ "${SUITE_STATUS}" == "SKIPPED" ]]; then
    echo -n "SKIPPED"
  elif [[ ${SUITE_STATUS} -eq 0 ]]; then
    echo -n "OK"
  else
    echo -n "FAIL"
  fi
}

function countSuiteResult() {
  local SUITE_STATUS="$1"
  TEST_TOTAL_COUNT=$((TEST_TOTAL_COUNT+1))
  if [[ "${SUITE_STATUS}" == "SKIPPED" ]]; then
    TEST_SKIPPED_COUNT=$((TEST_SKIPPED_COUNT+1))
  elif [[ ${SUITE_STATUS} -eq 0 ]]; then
    TEST_SUCCESS_COUNT=$((TEST_SUCCESS_COUNT+1))
  else
    TEST_FAILURE_COUNT=$((TEST_FAILURE_COUNT+1))
  fi
}

function testSuiteControllerSmoke() {
  if [[ -n "${CONTROLLER_HOST}" ]] && [[ -n "${CONTROLLER_EMAIL}" ]] && [[ -n "${CONTROLLER_PASSWORD}" ]]; then
    echo "--- Running CONTROLLER SMOKE TEST SUITE ---"
    pyresttest http://"${CONTROLLER}" tests/smoke/controller.yml
    SUITE_CONTROLLER_SMOKE_STATUS=$?
  else
    echo "--- Skipping CONTROLLER SMOKE TEST SUITE ---"
    echo "Insufficient configuration to run this test suite!"
    SUITE_CONTROLLER_SMOKE_STATUS="SKIPPED"
  fi
}

function testSuiteConnectorSmoke() {
  if [[ -n "${CONNECTOR_HOST}" ]]; then
    echo "--- Running CONNECTOR SMOKE TEST SUITE ---"
    pyresttest http://"${CONNECTOR}" tests/smoke/connector.yml
    SUITE_CONNECTOR_SMOKE_STATUS=$?
  else
    echo "--- Skipping CONNECTOR SMOKE TEST SUITE ---"
    echo "Insufficient configuration to run this test suite!"
    SUITE_CONNECTOR_SMOKE_STATUS="SKIPPED"
  fi
}

function testSuiteAgentsSmoke() {
  if [[ ${#AGENTS_ARR[@]} -gt 0 ]]; then
    echo "--- Running AGENT SMOKE TEST SUITE ---"
    bats tests/smoke/agent.bats
    SUITE_AGENT_SMOKE_STATUS=$?
  else
    echo "--- Skipping AGENT SMOKE TEST SUITE ---"
    echo "Insufficient configuration to run this test suite!"
    SUITE_AGENT_SMOKE_STATUS="SKIPPED"
  fi
}

function testSuiteBasicIntegration() {
  if [[ ${#AGENTS_ARR[@]} -gt 0 ]] && [[ -n "${CONTROLLER_HOST}" ]] && [[ -n "${CONTROLLER_EMAIL}" ]] && [[ -n "${CONTROLLER_PASSWORD}" ]]; then

    export CONTROLLER_EMAIL
    export CONTROLLER_PASSWORD
    echo "--- Running BASIC INTEGRATION TEST SUITE ---"
    SUITE_BASIC_INTEGRATION_STATUS=0

    # Spin up microservices
    for IDX in "${!AGENTS_ARR[@]}"; do
      export IDX
      pyresttest http://"${CONTROLLER}" tests/integration/deploy-weather.yml
      if [[ "$?" -gt 0 ]]; then
        SUITE_BASIC_INTEGRATION_STATUS=1
      fi
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

    for IDX in "${!AGENTS_ARR[@]}"; do
      export IDX
      pyresttest http://"${CONTROLLER}" tests/integration/destroy-weather.yml
       if [[ "$?" -gt 0 ]]; then
        SUITE_BASIC_INTEGRATION_STATUS=2
      fi
    done

  else
    echo "--- Skipping BASIC INTEGRATION TEST SUITE ---"
    echo "Insufficient configuration to run this test suite!"
    SUITE_BASIC_INTEGRATION_STATUS="SKIPPED"
  fi
}

function buildXML()
{
  countSuiteResult "${SUITE_CONTROLLER_SMOKE_STATUS}"
  countSuiteResult "${SUITE_CONNECTOR_SMOKE_STATUS}"
  countSuiteResult "${SUITE_AGENT_SMOKE_STATUS}"
  countSuiteResult "${SUITE_BASIC_INTEGRATION_STATUS}"
  countSuiteResult "${SUITE_KUBERNETES_STATUS}"
  countSuiteResult "${SUITE_IOFOGCTL_STATUS}"

  if [[ ! -d "/root/test-results" ]]; then
    echo "Directory /root/test-results/ does not exist (or is not mounted in Docker container). Cannot export JUnit XML test results!"
  else
  MY_XML="/test-results/TEST-RESULTS.xml"
    rm -f "${MY_XML}"
    echo "<?xml version=1.0 encoding=UTF-8?>" > "${MY_XML}"
    echo "<testsuites skipped=${TEST_SKIPPED_COUNT} failures=${TEST_FAILURE_COUNT} tests=${TEST_TOTAL_COUNT}>" >> "${MY_XML}"
    echo "  <testsuite name='CONTROLLER_SMOKE' id=0> </testsuite>" >> "${MY_XML}"
    echo "  <testsuite name='CONNECTOR_SMOKE' id=1> </testsuite>" >> "${MY_XML}"
    echo "  <testsuite name='AGENT_SMOKE' id=2> </testsuite>" >> "${MY_XML}"
    echo "  <testsuite name='BASIC_INTEGRATION' id=3> </testsuite>" >> "${MY_XML}"
    echo "  <testsuite name='KUBERNETES' id=4> </testsuite>" >> "${MY_XML}"
    echo "  <testsuite name='IOFOGCTL' id=5> </testsuite>" >> "${MY_XML}"
    echo "</testsuites>" >> "${MY_XML}"
  fi
}

loadConfiguration
[[ -n "${CONTROLLER}" ]] && checkController "${CONTROLLER_HOST}"
[[ -n "${CONNECTOR}" ]] && checkConnector "${CONNECTOR_HOST}"
for AGENT in "${AGENTS_ARR[@]}"; do checkAgent "${AGENT}"; done
testSuiteControllerSmoke
testSuiteAgentsSmoke
testSuiteBasicIntegration

# TODO: (Serge) Enable Connector tests when Connector is stable
# testSuiteConnectorSmoke
echo "--- Skipping CONNECTOR SMOKE TEST SUITE ---"
SUITE_CONNECTOR_SMOKE_STATUS="SKIPPED"

# TODO: (lkrcal) Enable these tests when ready for platform pipeline
# TODO: (xaoc000) Ensure each of these get sub functions and do test_counting there
#bats tests/k4g/k4g.bats
echo "--- Skipping KUBERNETES TEST SUITE ---"
SUITE_KUBERNETES_STATUS="SKIPPED"

# TODO: (lkrcal) Enable these tests when ready for platform pipeline
#bats tests/iofogctl/iofogctl.bats
echo "--- Skipping IOFOGCTL TEST SUITE ---"
SUITE_IOFOGCTL_STATUS="SKIPPED"

echo "--- Test Results: ---

SUITE_CONTROLLER_SMOKE_STATUS:  $( printSuiteResult "${SUITE_CONTROLLER_SMOKE_STATUS}")
SUITE_CONNECTOR_SMOKE_STATUS:   $( printSuiteResult "${SUITE_CONNECTOR_SMOKE_STATUS}")
SUITE_AGENT_SMOKE_STATUS:       $( printSuiteResult "${SUITE_AGENT_SMOKE_STATUS}")
SUITE_BASIC_INTEGRATION_STATUS: $( printSuiteResult "${SUITE_BASIC_INTEGRATION_STATUS}")
SUITE_KUBERNETES_STATUS:        $( printSuiteResult "${SUITE_KUBERNETES_STATUS}")
SUITE_IOFOGCTL_STATUS:          $( printSuiteResult "${SUITE_IOFOGCTL_STATUS}")
"

buildXML

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

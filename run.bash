#!/usr/bin/env bash

set -o noclobber -o nounset

TEST_TOTAL_COUNT=0
TEST_SUCCESS_COUNT=0
TEST_SKIPPED_COUNT=0
TEST_FAILURE_COUNT=0

function loadConfiguration() {
  CONTROLLER="${CONTROLLER:-}"
  AGENT_USER="${AGENT_USER:-}"
  if [[ ! -z "${CONTROLLER}" ]]; then
    # Controller informations provided
    # Prefix Controller with http:// if needed
    if [[ ${CONTROLLER} != "http"* ]]; then
      CONTROLLER="http://${CONTROLLER}"
    fi
    CONTROLLER_EMAIL="${CONTROLLER_EMAIL:-user@domain.com}"
    CONTROLLER_PASSWORD="${CONTROLLER_PASSWORD:-#Bugs4Fun}"
    iofogctl connect --ecn-addr "${CONTROLLER}" --name controller --email "${CONTROLLER_EMAIL}" --pass "${CONTROLLER_PASSWORD}"
  else
    # iofogctl must be used
    CONTROLLER="$(iofogctl describe controlplane | grep endpoint | awk '{print $2}')"
    CONTROLLER_EMAIL="$(iofogctl describe controlplane | grep email | awk '{print $2}')"
    CONTROLLER_PASSWORD="$(iofogctl describe controlplane | grep password | awk '{print $2}' | tr -d \' | base64 --decode)"
  fi
  if [[ ! -z "${AGENT_USER}" ]]; then
    iofogctl configure agents --user "${AGENT_USER}" --key "${AGENT_KEYFILE}"
  fi
  CONTROLLER="${CONTROLLER:-$(iofogctl describe controlplane | grep endpoint | awk '{print $2}')}"
  CONTROLLER_HOST="${CONTROLLER}/api/v3"
  AGENTS=(${AGENTS:-$(iofogctl get agents | awk 'NR>=5 {print $1}' | sed '$d')})

  echo "--- CONFIGURATION ---"
  echo -n "Controller: "
  if [[ -n "${CONTROLLER_HOST}" ]]; then
    echo -n "${CONTROLLER_HOST} (username: ${CONTROLLER_EMAIL}, password: $(echo "${CONTROLLER_PASSWORD}" | sed -r 's/./*/g'))"
  fi
  echo
  echo -n "Agents: "
  if [[ ${#AGENTS[@]} -gt 0 ]]; then
    echo -n "${AGENTS[@]}"
  fi
  echo
}

function checkController() {
  local CONTROLLER_HOST="$1"
  for IDX in $(seq 1 30); do
    STATUS=$(curl --request GET --url "${CONTROLLER_HOST}/status" 2>/dev/null | jq -r ".status")
    if [[ "${STATUS}" == "running" ]]; then
      break
    fi
    sleep 1
  done
  if [[ "${STATUS}" != "online" ]]; then
    echo "Controller ${CONTROLLER_HOST} not ready..."
    echo "${STATUS}"
    exit 1
  fi
  echo "Controller ${CONTROLLER_HOST} is ready."
}

function checkAgent() {
  local AGENT="$1"
  echo "Waiting for Agent ${AGENT}..."
  STATUS="$(iofogctl legacy agent $AGENT status | grep 'Connection to Controller')"
  if [[ "${STATUS}" != *"ok"* ]]; then
    echo "Agent $AGENT not ready!"
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
    pyresttest "${CONTROLLER}" tests/smoke/controller.yml
    SUITE_CONTROLLER_SMOKE_STATUS=$?
  else
    echo "--- Skipping CONTROLLER SMOKE TEST SUITE ---"
    echo "Insufficient configuration to run this test suite!"
    SUITE_CONTROLLER_SMOKE_STATUS="SKIPPED"
  fi
}

function testSuiteAgentsSmoke() {
  if [[ ${#AGENTS[@]} -gt 0 ]]; then
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
  if [[ ${#AGENTS[@]} -gt 0 ]] && [[ -n "${CONTROLLER_HOST}" ]] && [[ -n "${CONTROLLER_EMAIL}" ]] && [[ -n "${CONTROLLER_PASSWORD}" ]]; then

    export CONTROLLER_EMAIL
    export CONTROLLER_PASSWORD
    echo "--- Running BASIC INTEGRATION TEST SUITE ---"
    SUITE_BASIC_INTEGRATION_STATUS=0

    # Spin up microservices
    for IDX in "${!AGENTS[@]}"; do
      export IDX
      pyresttest "${CONTROLLER}" tests/integration/deploy-weather.yml
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

    for IDX in "${!AGENTS[@]}"; do
      export IDX
      pyresttest "${CONTROLLER}" tests/integration/destroy-weather.yml
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
  countSuiteResult "${SUITE_AGENT_SMOKE_STATUS}"
  countSuiteResult "${SUITE_BASIC_INTEGRATION_STATUS}"
  countSuiteResult "${SUITE_KUBERNETES_STATUS}"
  countSuiteResult "${SUITE_IOFOGCTL_STATUS}"

  if [[ ! -d "/root/test-results" ]]; then
    echo "Directory /root/test-results/ does not exist (or is not mounted in Docker container). Cannot export JUnit XML test results!"
  else
  MY_XML="/root/test-results/TEST-RESULTS.xml"
    rm -f "${MY_XML}"
    echo "<?xml version=1.0 encoding=UTF-8?>" > "${MY_XML}"
    echo "<testsuites skipped=${TEST_SKIPPED_COUNT} failures=${TEST_FAILURE_COUNT} tests=${TEST_TOTAL_COUNT}>" >> "${MY_XML}"
    echo "  <testsuite name='CONTROLLER_SMOKE' id=0> </testsuite>" >> "${MY_XML}"
    echo "  <testsuite name='AGENT_SMOKE' id=2> </testsuite>" >> "${MY_XML}"
    echo "  <testsuite name='BASIC_INTEGRATION' id=3> </testsuite>" >> "${MY_XML}"
    echo "  <testsuite name='KUBERNETES' id=4> </testsuite>" >> "${MY_XML}"
    echo "  <testsuite name='IOFOGCTL' id=5> </testsuite>" >> "${MY_XML}"
    echo "</testsuites>" >> "${MY_XML}"
  fi
}

loadConfiguration
checkController "${CONTROLLER_HOST}"
for AGENT in "${AGENTS[@]}"; do checkAgent "${AGENT}"; done
testSuiteControllerSmoke
testSuiteAgentsSmoke
testSuiteBasicIntegration

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
SUITE_AGENT_SMOKE_STATUS:       $( printSuiteResult "${SUITE_AGENT_SMOKE_STATUS}")
SUITE_BASIC_INTEGRATION_STATUS: $( printSuiteResult "${SUITE_BASIC_INTEGRATION_STATUS}")
SUITE_KUBERNETES_STATUS:        $( printSuiteResult "${SUITE_KUBERNETES_STATUS}")
SUITE_IOFOGCTL_STATUS:          $( printSuiteResult "${SUITE_IOFOGCTL_STATUS}")
"

buildXML

if [[ "${SUITE_CONTROLLER_SMOKE_STATUS}" =~ ^(0|SKIPPED)$ ]] && \
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

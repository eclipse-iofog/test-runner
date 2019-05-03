#!/usr/bin/env bash

. functions.bash

# Read Controller, Connector, and Agents from config files
CONTROLLER=$(cat conf/controller.conf | tr -d '\n')
CONNECTOR=$(cat conf/connector.conf | tr -d '\n')
importAgents
echo "----------   CONFIGURATION   ----------
[CONTROLLER]
$CONTROLLER

[CONNECTOR]
$CONNECTOR

[AGENTS]
${AGENTS[@]}
"

# Wait until services are up
echo "Waiting for Controller and Connector APIs..."
for HOST in http://"$CONTROLLER" http://"$CONNECTOR"; do
  waitFor "$HOST" 60
done

# Verify SSH connections to Agents and wait for them to be provisioned
echo "Waiting for Agents to provision with Controller..."
ITER=0
for AGENT in "${AGENTS[@]}"; do
  RESULT=$(ssh -i conf/id_ecdsa -o StrictHostKeyChecking=no "$AGENT" sudo iofog-agent status | grep 'Connection to Controller')
  while [[ "$RESULT" != *"ok"* ]]; do
    if [[ "$ITER" -gt 30 ]]; then exit 1; fi
    RESULT=$(ssh -i conf/id_ecdsa -o StrictHostKeyChecking=no "$AGENT" sudo iofog-agent status | grep 'Connection to Controller')
    sleep 5
    ITER=$((ITER+1))
  done
  echo "$AGENT provisioned successfully"
done
echo "---------- ----------------- ----------
"

ERR=0
echo "----------    SMOKE TESTS    ----------"
pyresttest http://"$CONTROLLER" tests/smoke/controller.yml ; (( ERR |= "$?" ))
pyresttest http://"$CONNECTOR" tests/smoke/connector.yml ; (( ERR |= "$?" ))
tests/smoke/agent.bats
echo "---------- ----------------- ---------- "

echo "---------- INTEGRATION TESTS ----------"
# Spin up microservices
for IDX in "${!AGENTS[@]}"; do
  export IDX
  pyresttest http://"$CONTROLLER" tests/integration/deploy-weather.yml ; (( ERR |= "$?" ))
done

# Test microservices
for IDX in "${!AGENTS[@]}"; do
  export IDX
  # Set endpoint to test microservice
  ENDPOINT=host.docker.internal:5555
  if [[ -z "$LOCAL" ]]; then
    HOST="${AGENTS[$IDX]}"
    ENDPOINT="${HOST##*@}":5555
  fi

  # Wait for, and curl the microservices
  echo "Waiting for endpoint: $ENDPOINT"
  waitFor http://"$ENDPOINT" 180
  pyresttest http://"$ENDPOINT" tests/integration/test-weather.yml ; (( ERR |= "$?" ))
done

# Teardown microservices
for IDX in "${!AGENTS[@]}"; do
  export IDX
  pyresttest http://"$CONTROLLER" tests/integration/destroy-weather.yml ; (( ERR |= "$?" ))
done
echo "---------- ----------------- ----------
"

exit "$ERR"
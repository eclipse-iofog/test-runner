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
    if [[ "$ITER" -gt 60 ]]; then exit 1; fi
    RESULT=$(ssh -i conf/id_ecdsa -o StrictHostKeyChecking=no "$AGENT" sudo iofog-agent status | grep 'Connection to Controller')
    sleep 1
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
echo "---------- ----------------- ----------
"

echo "---------- INTEGRATION TESTS ----------"
# Spin up microservice for each agent
for IDX in "${!AGENTS[@]}"; do
  export IDX
  pyresttest http://"$CONTROLLER" tests/integration/deploy-weather.yml ; (( ERR |= "$?" ))
done
# TODO: (Serge) Test each weather microservice
#for IDX in "${!AGENTS[@]}"; do
#  export IDX
#  pyresttest http://"$CONTROLLER" tests/integration/test-weather.yml ; (( ERR |= "$?" ))

  # Wait for, and curl the microservices
  #HOST="${AGENTS[$IDX]}"
  #echo "Waiting for endpoint: ${HOST##*@}:5555"
  #waitFor http://"${HOST##*@}":5555 180
  #curl http://"${HOST##*@}":5555 --connect-timeout 10
#done
# Spin down microservice for each agent
for IDX in "${!AGENTS[@]}"; do
  export IDX
  pyresttest http://"$CONTROLLER" tests/integration/destroy-weather.yml ; (( ERR |= "$?" ))
done
echo "---------- ----------------- ----------
"

exit "$ERR"
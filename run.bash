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
  waitFor "$HOST"
done

# Verify SSH connections to Agents and wait for them to be provisioned
echo "Waiting for Agents to provision with Controller..."
for AGENT in "${AGENTS[@]}"; do
  RESULT=$(ssh -i conf/id_ecdsa -o StrictHostKeyChecking=no "$AGENT" iofog-agent status | grep 'Connection to Controller')
  while [[ "$RESULT" != *"ok"* ]]; do
    RESULT=$(ssh -i conf/id_ecdsa -o StrictHostKeyChecking=no "$AGENT" iofog-agent status | grep 'Connection to Controller')
    sleep 1
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
tests/integration/integration.bats ; (( ERR |= "$?" ))
echo "---------- ----------------- ----------
"

exit "$ERR"
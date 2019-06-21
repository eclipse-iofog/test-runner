#!/usr/bin/env bats

. functions.bash

# Read Controller, Connector, and Agents from config files
YML_FILE=$1
if ! [[ ${YML_FILE} ]]; then
    YML_FILE="conf/environment.yml"
fi

CONTROLLER=$(yaml ${YML_FILE} controllers[0].kubecontrollerip)
#CONNECTOR=$(yaml ${YML_FILE} connectors[0].connector_ip)
CONNECTOR="TESTING STUFF"
AGENTS=($(yaml ${YML_FILE} agents[0].host) $(yaml ${YML_FILE} agents[1].host))
#i=0
#until [[ $(yaml ${YML_FILE} agents[${i}]) ]]; do
#    AGENTS+=$(yaml ${YML_FILE} agents[${i}].name)":"$(yaml ${YML_FILE} agents[${i}].port)
#    i=${i} + 1
#done

KUBE_CONF=$(yaml ${YML_FILE} controllers[0].kubeconfig)
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
for HOST in http://"$CONTROLLER"; do
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
    echo -ne "."
  done
  echo "$AGENT provisioned successfully"
done
echo "---------- ----------------- ----------
"

ERR=0
echo "----------    SMOKE TESTS    ----------"
pyresttest http://"$CONTROLLER" tests/smoke/controller.yml ; (( ERR |= "$?" ))
# TODO: (Serge) Enable Connector tests when Connector is stable
#pyresttest http://"$CONNECTOR" tests/smoke/connector.yml ; (( ERR |= "$?" ))
tests/smoke/agent.bats
echo "---------- ----------------- ---------- "

echo "---------- INTEGRATION TESTS ----------"
# Spin up microservices
for IDX in "${!AGENTS[@]}"; do
  export IDX
  pyresttest http://"$CONTROLLER" tests/integration/deploy-weather.yml ; (( ERR |= "$?" ))
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
  pyresttest http://"$CONTROLLER" tests/integration/destroy-weather.yml ; (( ERR |= "$?" ))
done
echo "---------- ----------------- ----------
"

echo "---------- K4G TESTS ----------"
tests/k4g/k4g.bats
echo "---------- ----------------- ----------
"

echo "---------- IOFOGCTL TESTS ----------"
echo "Testing..."
echo "---------- ----------------- ----------
"
exit 0
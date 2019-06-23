#!/usr/bin/env bash

. functions.bash

# Read Controller, Connector, and Agents from config files
YML_FILE=$1
if ! [[ ${YML_FILE} ]]; then
    YML_FILE="conf/environment.yml"
fi

KUBE_CONFIG=$(yaml ${YML_FILE} controllers[0].kubeconfig)

CONTROLLER=$(kubectl get svc controller --template=\"{{range.status.loadBalancer.ingress}}{{.ip}}{{end}}\" -n iofog --kubeconfig ${KUBE_CONFIG} )
# Strip Quotes off of the string given, POSIX compliant
CONTROLLER="${CONTROLLER#?}"; CONTROLLER="${CONTROLLER%?}";

CONNECTOR=$(kubectl get svc connector --template=\"{{range.status.loadBalancer.ingress}}{{.ip}}{{end}}\" -n iofog --kubeconfig ${KUBE_CONFIG} )
# Strip Quotes off of the string given, POSIX compliant
CONNECTOR="${CONNECTOR#?}"; CONNECTOR="${CONNECTOR%?}";
AGENT_USERS=()
AGENT_HOSTS=()
AGENT_PORTS=()
AGENT_KEYFILES=()
i=0
while [[ $(yaml ${YML_FILE} agents[${i}]) ]]; do
    agent_user=$(yaml ${YML_FILE} agents[${i}].user)
    agent_ip=$(yaml ${YML_FILE} agents[${i}].host)
    agent_port=$(yaml ${YML_FILE} agents[${i}].port)
    agent_keyfile=$(yaml ${YML_FILE} agents[${i}].keyfile)
    AGENT_USERS+=("${agent_user}")
    AGENT_HOSTS+=("${agent_ip}")
    AGENT_PORTS+=("${agent_port}")
    AGENT_KEYFILES+=(${agent_keyfile})
    i=${i}+1
done

KUBE_CONF=$(yaml ${YML_FILE} controllers[0].kubeconfig)
echo "----------   CONFIGURATION   ----------
[CONTROLLER]
$CONTROLLER

[CONNECTOR]
$CONNECTOR

[AGENTS]
${AGENT_HOSTS[@]}
"

# Wait until services are up
echo "Waiting for Controller and Connector APIs..."
for HOST in http://"$CONTROLLER":51121 http://"$CONNECTOR":8080; do
  waitFor "$HOST" 60
done

# Verify SSH connections to Agents and wait for them to be provisioned
echo "Waiting for Agents to provision with Controller..."
ITER=0
idx=0
for AGENT_HOST in "${AGENT_HOSTS[@]}"; do
  RESULT=$(ssh -i ${AGENT_KEYFILES[${idx}]} -o StrictHostKeyChecking=no "${AGENT_USERS[${idx}]}"@"${AGENT_HOST}" -p "${AGENT_PORTS[${idx}]}" sudo iofog-agent status | grep 'Connection to Controller')
  while [[ "$RESULT" != *"ok"* ]]; do
    if [[ "$ITER" -gt 30 ]]; then exit 1; fi
    RESULT=$(ssh -i ${AGENT_KEYFILES[${idx}]} -o StrictHostKeyChecking=no "${AGENT_USERS[${idx}]}"@"${AGENT_HOST}" -p "${AGENT_PORTS[${idx}]}" sudo iofog-agent status | grep 'Connection to Controller')
    sleep 5
    ITER=$((ITER+1))
    echo -ne "."
  done
  echo "${AGENT_HOST} provisioned successfully"
  idx=$((idx+1))
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
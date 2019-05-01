#!/usr/bin/env bats

. tests/functions.bash

importAgents
#importConfig

# Test that the SSH connection to Agents is Valid
@test "Integration SHH Into Agents Checking" {
  forAgents "echo Connected"
}

#Test that Volumes have been mapped across correctly
#@test "Integration Volume Checking" {
#    forAgents "test -f /usr/"
#}

#@test "Integration Port Checking" {
#    forAgents "telnet localhost $PORTS"
#}

#@test "Integration Routes Checking" {
#    forAgents "cat /etc"
#}
#
#@test "Integration Privileged Checking" {
#    RESULT=$(forAgents "telnet localhost $PORTS" 0)
#    
#    #RESULT="$(docker inspect --format='{{json .Config.ExposedPorts }}' ${CONTAINER_ID})"
#    #[[ "$RESULT" -eq 0 ]]
#}
#
#@test "Integration Environment Variables Checking" {
#    RESULT=$(forAgents "[ ! -z $ENV_VAR ]" 0)
#}


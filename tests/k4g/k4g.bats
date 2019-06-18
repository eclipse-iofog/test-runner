#!/usr/bin/env bats

. tests/functions.bash

# Test that we can get pods
@test "Get All Pods" {
  forKubectl "get pods"
}

# Test that we can get pods
@test "Get Specific Pods" {
  PODS=($(kubectl get pods -n iofog --kubeconfig ${KUBE_CONF} | awk 'NR>1 {print $1}'))
  for pod in ${PODS}; do
      forKubectl "get ${pod}"
  done
}

# Test that the describing individual pods works
@test "Describe Specific Pods" {
  PODS=($(kubectl get pods -n iofog --kubeconfig ${KUBE_CONF} | awk 'NR>1 {print $1}'))
  for pod in ${PODS}; do
      forKubectl "describe ${pod}"
  done
}

# Test that the describing individual pods works
@test "Get Pods under Certain Namespace" {
  forKubectl "get pods -n iofog"
}

# Test that the describing individual pods works
@test "Get Users" {
  forKubectl "config view -o jsonpath='{.users[].name}'"
}

# Test that the describing individual pods works
@test "Get All Services where namespace is not default" {
  forKubectl "get services  --all-namespaces --field-selector metadata.namespace!=default"
}

# Test that the describing individual pods works
@test "Get Pods Wide Test" {
  forKubectl "get pods -o wide"
}

# Test that the describing individual pods works
@test "Get name of containers running on pods" {
  PODS=($(kubectl get pods -n iofog --kubeconfig ${KUBE_CONF} | awk 'NR>1 {print $1}'))
  for pod in ${PODS}; do
      forKubectl "get pods ${pod} -o jsonpath='{.spec.containers[*].name}'"
  done
}

@test "Get Contexts" {
  forKubectl "config get-contexts"
}

@test "Display current-context" {
  forKubectl "get pods --include-uninitialized"
}

@test "Get Services" {
  forKubectl "get services"
}

@test "Get Services and Sort by name" {
  forKubectl "get services --sort-by=.metadata.name"
}

@test "Get Services Sort by restart count" {
  forKubectl "get pods --sort-by='.status.containerStatuses[0].restartCount'"
}

@test "Running Pods in Namespace" {
  forKubectl "get pods --field-selector=status.phase=Running"
}

@test "External IP of all Nodes" {
  forKubectl "get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=='ExternalIP')].address}'"
}

@test "Check Pod Logs" {
  PODS=($(kubectl get pods -n iofog --kubeconfig ${KUBE_CONF} | awk 'NR>1 {print $1}'))
  for pod in ${PODS}; do
      forKubectl "logs ${pod}"
  done
}

@test "List events sorted by timestamp" {
  forKubectl "get events --sort-by=.metadata.creationTimestamp"
}
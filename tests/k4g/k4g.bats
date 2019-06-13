#!/usr/bin/env bats

. tests/functions.bash

# Test that we can get pods
@test "Check Kubectl Pods" {
  forKubectl "get pods"
}

# Test that the pods description is valid
@test "Kubectl Describe" {
  forKubectl "describe pods"
}

# Test that the describing individual pods works
@test "Check Specific Pods" {
  PODS=$("kubectl get pods -n iofog --kubeconfig conf/kube.conf | awk 'NR>1 {print $1}'")
  for pod in $PODS; do
      forKubectl "describe ${pod}"
  done
}
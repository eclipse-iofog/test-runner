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
@test "Describe Specific Pods" {
  PODS=getPods
  for pod in ${PODS}; do
      forKubectl "describe ${pod}"
  done
}
# Test Runner

The ioFog Test Runner provides a convenient way to run multiple smoke test suites on a deployed Edge Compute Network (ECN).

The suite by default does not run any non-smoke tests, i.e. tests that would invalidate or potentially break the ECN, therefore it can be used on staging a productions ECNs to verify correct deployment.  

The following test suites are available:
* Controller REST API smoke tests
* Agent CLI smoke tests
* Basic microservice deployment integration tests

Note that some of additional test suites are automatically skipped as of this release of Test Runner.

## Prerequisites

You must have iofogctl configured with its default namespace pointing to the ECN you want to test

## Usage

| Test suite | Description | Required configuration |
| --- | --- | --- |
| Controller REST API smoke tests | Basic REST API tests on Controller instance | <ul><li>CONTROLLER</li><li>CONTROLLER_EMAIL</li><li>CONTROLLER_PASSWORD</li></ul> |
| Agent CLI smoke tests | Runs Agent tests by SSHing into the Agent nodes and interacting using Agent CLI | <ul><li>AGENTS</li></ul> |
| Basic microservice deployment integration tests | Sets up users and catalog entries, deploys and destroys microservices on each Agent | <ul><li>CONTROLLER</li><li>CONTROLLER_EMAIL</li><li>CONTROLLER_PASSWORD</li><li>AGENTS</li></ul> |


Example usage of the test runner with full configuration:

```bash
docker run --name test-runner \
        -v ~/.iofog/:/root/.iofog/ \
        iofog/test-runner:latest
```

## Test Results

The output of this test-suite currently is a single XML File that is Junit-XML compliant.
This can be used in development pipelines on most DevOps infrastructure to display test results
in easy to consume factor.

This is used in Azure Pipelines to display each builds pass/fail for both entire test suites
as well as for specific tests we may see multiple failures in, to help identify issues that may not be consistent.

The test output is file is `TEST-RESULTS.xml` and is stored in `/root/test-results` of the test-runner container.   

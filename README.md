# Test Runner

Agents are comma separated URI

Example:
    root@1.2.3.4:6451,user@6.7.8.9

Note that you need to mount appropriate ssh keys to /root/.ssh

docker run --rm --name test-runner -v ~/.ssh/google_compute_engine:/root/.ssh/id_rsa --network host -e AGENTS="lkrcal@34.66.151.77,lkrcal@35.222.182.230" gcr.io/focal-freedom-236620/test-runner:lkrcal


 ~/.ssh/id_dsa, ~/.ssh/id_ecdsa, ~/.ssh/id_ed25519 and ~/.ssh/id_rsa

## Usage

It is recommended you run Test Runner using docker-compose.

You must provide agents.conf and a corresponding id_ecdsa/id_ecdsa.pub pair in /conf of the runner. This should be done through a volume in your docker-compose.yml.

For local deployments:
```bash
./run.bash
```
or 
```
version: "3"
services:
    test-runner:
        image: iofog/test-runner-develop:latest
        container_name: test-runner
        environment:
            - LOCAL=1
        network_mode: "bridge"
        external_links: 
            - iofog-controller
            - iofog-connector
            - iofog-agent
        volumes:
            - /path/to/host/conf:/conf
volumes:
  conf:
```

For remote deployments:
```
version: "3"
services:
    test-runner:
        image: iofog/test-runner-develop:latest
        container_name: test-runner
        network_mode: "bridge"
        volumes:
            - /path/to/host/conf:/conf
volumes:
  conf:
```

Once the docker-compose.yml is ready, run the following.

```
docker-compose pull test-runner

docker-compose up \
    --build \
    --abort-on-container-exit \
    --exit-code-from test-runner \
    --force-recreate \
    --renew-anon-volumes

docker-compose down -v
```

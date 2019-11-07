#
# Test Runner is an image built to execute a set of unit and integration tests for
# the 'demo' project.
#
FROM python:3-alpine

# Install dependencies
RUN apk add --no-cache jq git bash libcurl curl openssh-client

# Install pycurl
ENV PYCURL_SSL_LIBRARY=openssl
RUN apk add --no-cache --virtual .build-dependencies build-base curl-dev \
    && pip install pycurl \
    && apk del .build-dependencies

RUN pip install \
  future \
  jmespath \
  jsonschema \
  pyresttest \
  shyaml

# TODO: (lkrcal) Enable these when kubectl tests are ready
# Set the Kubernetes version as found in the UCP Dashboard or API
# RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.11.5/bin/linux/amd64/kubectl && \
#    chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl

RUN git clone https://github.com/sstephenson/bats.git && cd bats && ./install.sh /usr/local && cd .. && rm -rf bats

# Make dir for test results
RUN mkdir -p /test-results

# Copy over all the files we need
COPY run.bash /
COPY tests /tests/

# Run our tests
ENTRYPOINT ["/bin/sh", "-c", "/run.bash"]

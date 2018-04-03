#!/bin/bash

set -eou pipefail

REPO=${TRAVIS_REPO_SLUG} ;

for tag in ${DOCKER_TAGS}
do
    echo "Building $REPO:$tag"
    
    if [ -z "${SPARK_VERSION:-}" ]
    then
        docker build -t "$REPO:$tag" \
            --pull \
            --target no-spark .
    else
        docker build -t "$REPO:$tag" \
            --pull \
            --target with-spark \
            "--build-arg=SPARK_VERSION=${SPARK_VERSION}" \
            "--build-arg=SPARK_PY4J=${SPARK_PY4J}" \
            "--build-arg=SPARK_VARIANT=${SPARK_VARIANT}" \
            .
    fi
done


#!/usr/bin/env bash
set -euo pipefail

echo "${DOCKER_PASSWORD}" | docker login -u="${DOCKER_USERNAME}" --password-stdin

docker tag "${IMAGE_NAME}:${TAG_NAME}" "${IMAGE_ORG}/${IMAGE_NAME}:${TAG_NAME}"
docker push "${IMAGE_ORG}/${IMAGE_NAME}:${TAG_NAME}"

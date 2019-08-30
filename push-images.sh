#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=${IMAGE_NAME:-airflow-pipeline}
TAG_NAME="${AIRFLOW_VERSION}_spark-${SPARK_VERSION}_hadoop-${HADOOP_VERSION}_python-${PYTHON_VERSION}_sqlalchemy-${SQLALCHEMY_VERSION}"

docker login -u="${DOCKER_USERNAME}" -p="${DOCKER_PASSWORD}"
docker push "${DOCKER_USERNAME}/${IMAGE_NAME}:${TAG_NAME}"

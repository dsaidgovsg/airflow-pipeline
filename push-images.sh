#!/usr/bin/env bash
set -euo pipefail

DOCKER_IMAGE=${DOCKER_IMAGE:-guangie88/airflow-pipeline}
docker login -u="${DOCKER_USERNAME}" -p="${DOCKER_PASSWORD}"

for SELECTED_PYTHON_MAJOR_VERSION in "2" "3"; do
    docker push "${DOCKER_IMAGE}:${AIRFLOW_VERSION}_spark-${SPARK_VERSION}_hadoop-${HADOOP_VERSION}_sqlalchemy-${SQLALCHEMY_VERSION}_py-${SELECTED_PYTHON_MAJOR_VERSION}"
done

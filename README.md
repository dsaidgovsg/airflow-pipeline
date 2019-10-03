# Airflow Pipeline Docker Image Set-up

[![Build Status](https://travis-ci.org/guangie88/airflow-pipeline.svg?branch=master)](https://travis-ci.org/guangie88/airflow-pipeline)

This is a fork of <https://github.com/dsaidgovsg/airflow-pipeline>.

This repo is a set-up to build Docker images of
[Airflow](https://airflow.incubator.apache.org/), and has been heavily modified
from the original to generate different version combinations of the following
parts:

- Airflow
- Spark
- Hadoop integration with Spark
- Python
- SQL Alchemy

## How to build

```bash
AIRFLOW_VERSION=1.9
SPARK_VERSION=2.4.4
HADOOP_VERSION=3.1.0
PYTHON_VERSION=3.6
SQLALCHEMY_VERSION=1.1
PY4J_FILE="$(curl -s https://github.com/apache/spark/tree/v${SPARK_VERSION}/python/lib | grep -oE 'py4j-[^\s]+-src\.zip' | uniq)"
docker build . -t airflow-pipeline \
  --build-arg AIRFLOW_VERSION=${AIRFLOW_VERSION} \
  --build-arg SPARK_VERSION=${SPARK_VERSION} \
  --build-arg HADOOP_VERSION=${HADOOP_VERSION} \
  --build-arg PYTHON_VERSION=${PYTHON_VERSION} \
  --build-arg "SPARK_PY4J=python/lib/${PY4J_FILE}" \
  --build-arg SQLALCHEMY_VERSION=${SQLALCHEMY_VERSION}
```

You may refer to the [vars.yml](templates/vars.yml) to have a sensing of all the
possible build arguments to combine.

`SPARK_PY4J` can only be properly derived by running the above `PY4J_FILE`
command to locate it.

## Additional Useful Perks

There is already an AWS S3 log configuration file in this set-up.

If you wish to save the Airflow logs into S3 bucket instead, provide the
following environment variables when launcher the Docker container:

```yml
AIRFLOW__CORE__TASK_LOG_READER: s3.task
AIRFLOW__CORE__LOGGING_CONFIG_CLASS: s3_log_config.LOGGING_CONFIG
S3_LOG_FOLDER: s3://yourbucket/path/to/your/dir
```

## Caveat

Because this image is based on Spark with Kubernetes compatible image, which
always generates Alpine based Docker images, the images generated from this
repository are likely to stay Alpine based as well.

However, note that there is no guarantee that this is always true, and any GNU
tool can break due to discrepancy between Alpine and other distributions such as
Debian.

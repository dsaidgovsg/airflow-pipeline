# Airflow Pipeline Docker Image Set-up

[![Build Status](https://travis-ci.org/guangie88/airflow-pipeline.svg?branch=master)](https://travis-ci.org/guangie88/airflow-pipeline)

This is a fork of <https://github.com/datagovsg/airflow-pipeline>.

This repo is a set-up to build Docker images of
[Airflow](https://airflow.incubator.apache.org/), and has been heavily modified
from the original to generate different version combinations of the following
parts:

- Airflow
- Spark
- Hadoop integration with Spark
- SQL Alchemy
- Python (2 and 3 based on Debian distribution)

## How to build

```bash
AIRFLOW_VERSION=1.10.4
SPARK_VERSION=2.4.3
HADOOP_VERSION=3.1.0
PYTHON_VERSION=3.5
SQLALCHEMY_VERSION=1.3
PY4J_FILE="$(curl -s https://github.com/apache/spark/tree/v${SPARK_VERSION}/python/lib | grep -oE 'py4j-[^\s]+-src\.zip' | uniq)"
docker build . -t airflow-pipeline \
  --build-arg AIRFLOW_VERSION=${AIRFLOW_VERSION} \
  --build-arg SPARK_VERSION=${SPARK_VERSION} \
  --build-arg HADOOP_VERSION=${HADOOP_VERSION} \
  --build-arg PYTHON_VERSION=${PYTHON_VERSION} \
  --build-arg "SPARK_PY4J=python/lib/${PY4J_FILE}" \
  --build-arg SQLALCHEMY_VERSION=${SQLALCHEMY_VERSION} \
  --build-arg AIRFLOW_SUBPACKAGES="hive,jdbc,s3"
```

You may refer to the [vars.yml](templates/vars.yml) to have a sensing of all the
possible build arguments to combine.

`SPARK_PY4J` can only be properly derived by running the above `PY4J_FILE`
command to locate it.

Also `SELECTED_PYTHON_MAJOR_VERSION` is not in the above file to prevent having
different Travis set-up just for different Python versions, since both Python
versions are already installed in the base image. The build argument can only
be `2` (default) or `3`.

## Additional Useful Perks

There is already an AWS S3 log configuration file in this set-up.

If you wish to save the Airflow logs into S3 bucket instead, provide the
following environment variables when launcher the Docker container:

```yml
AIRFLOW__CORE__TASK_LOG_READER: s3.task
AIRFLOW__CORE__LOGGING_CONFIG_CLASS: s3_log_config.LOGGING_CONFIG
S3_LOG_FOLDER: s3://yourbucket/path/to/your/dir
```

## Caveats

Due to this [issue](https://issues.apache.org/jira/browse/AIRFLOW-5033) with
Kerberos not playing well with Python 3, all Docker images built for Python 3
will not contain the `apache-airflow[kerberos]` package. Otherwise, the built
Docker images will contain all other packages in both Python 2 and 3 variants.

FROM python:2.7 AS no-spark
MAINTAINER Chris Sng <chris@data.gov.sg>

# Setup airflow
RUN set -ex \
    && (echo 'deb http://deb.debian.org/debian jessie-backports main' > /etc/apt/sources.list.d/backports.list) \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y --force-yes vim-tiny libsasl2-dev libffi-dev gosu krb5-user \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir "apache-airflow[devel_hadoop, crypto]==1.9.0" psycopg2 \
    && pip install --no-cache-dir sqlalchemy==1.1.17

ENV AIRFLOW_HOME /airflow

WORKDIR ${AIRFLOW_HOME}

# Setup airflow dags path
ENV AIRFLOW_DAG ${AIRFLOW_HOME}/dags

RUN mkdir -p ${AIRFLOW_DAG}

COPY setup_auth.py ${AIRFLOW_HOME}/setup_auth.py
VOLUME ${AIRFLOW_HOME}/logs
COPY airflow.cfg ${AIRFLOW_HOME}/airflow.cfg
COPY unittests.cfg ${AIRFLOW_HOME}/unittests.cfg

# Delay creation of user and group
ONBUILD ARG THEUSER=afpuser
ONBUILD ARG THEGROUP=hadoop

ONBUILD ENV USER ${THEUSER}
ONBUILD ENV GROUP ${THEGROUP}
ONBUILD RUN groupadd -r "${GROUP}" && useradd -rmg "${GROUP}" "${USER}"

# Number of times the Airflow scheduler will run before it terminates (and restarts)
ENV SCHEDULER_RUNS=5
# parallelism = number of physical python processes the scheduler can run
ENV AIRFLOW__CORE__PARALLELISM=8
# dag_concurrency = the number of TIs to be allowed to run PER-dag at once
ENV AIRFLOW__CORE__DAG_CONCURRENCY=6
# max_threads = number of processes to parallelize the scheduler over, cannot exceed the cpu count
ENV AIRFLOW__SCHEDULER__MAX_THREADS=4

# Airflow uses postgres as its database, following are the examples env vars
ENV POSTGRES_HOST=localhost
ENV POSTGRES_PORT=5999
ENV POSTGRES_USER=fixme
ENV POSTGRES_PASSWORD=fixme
ENV POSTGRES_DB=airflow

WORKDIR ${AIRFLOW_HOME}

# Setup pipeline dependencies
COPY requirements.txt ${AIRFLOW_HOME}/requirements.txt
RUN pip install -r "${AIRFLOW_HOME}/requirements.txt"

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

## To build your own image:
# ONBUILD COPY dags/ ${AIRFLOW_DAG}

FROM no-spark AS with-spark

# Install Java
RUN apt-get update \
  && apt-get install -t jessie-backports --no-install-recommends -y openjdk-8-jre-headless \
  && rm -rf /var/lib/apt/lists/*

ARG SPARK_VERSION
ARG SPARK_VARIANT
ARG SPARK_PY4J

ENV SPARK_HOME=/opt/spark-${SPARK_VERSION}
ENV PATH=$PATH:${SPARK_HOME}/bin
ENV PYTHONPATH=${SPARK_HOME}/${SPARK_PY4J}:${SPARK_HOME}/python
ENV PYSPARK_SUBMIT_ARGS="--driver-memory 8g --py-files ${SPARK_HOME}/python/lib/pyspark.zip pyspark-shell"

# Download Spark
ARG SPARK_EXTRACT_LOC=/sparkbin
RUN set -eux && \
    mkdir -p ${SPARK_EXTRACT_LOC} && \
    curl https://www.mirrorservice.org/sites/ftp.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-${SPARK_VARIANT}.tgz |\
    tar -xz -C ${SPARK_EXTRACT_LOC} && \
    mkdir -p ${SPARK_HOME} && \
    mv ${SPARK_EXTRACT_LOC}/spark-${SPARK_VERSION}-bin-${SPARK_VARIANT}/* ${SPARK_HOME} && \
    rm -rf ${SPARK_EXTRACT_LOC} && \
    echo SPARK_HOME is ${SPARK_HOME} && \
    ls -al --g ${SPARK_HOME}

# Less verbose logging
COPY log4j.properties.production ${SPARK_HOME}/conf/log4j.properties



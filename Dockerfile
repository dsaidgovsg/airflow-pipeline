FROM python:2.7 AS no-spark
LABEL maintainer="Chris Sng <chris@data.gov.sg>"

# Setup airflow
RUN set -ex \
    && (echo 'deb http://deb.debian.org/debian jessie-backports main' > /etc/apt/sources.list.d/backports.list) \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y --force-yes vim-tiny libsasl2-dev libffi-dev gosu krb5-user \
    && rm -rf /var/lib/apt/lists/* \
    && AIRFLOW_GPL_UNIDECODE=yes pip install --no-cache-dir "apache-airflow[devel_hadoop, crypto]==1.10.0" psycopg2

ARG airflow_home=/airflow
ENV AIRFLOW_HOME=${airflow_home}

WORKDIR ${AIRFLOW_HOME}

# Setup airflow dags path
ENV AIRFLOW_DAG=${AIRFLOW_HOME}/dags

RUN mkdir -p ${AIRFLOW_DAG}

COPY setup_auth.py ${AIRFLOW_HOME}/setup_auth.py
VOLUME ${AIRFLOW_HOME}/logs
COPY airflow.cfg ${AIRFLOW_HOME}/airflow.cfg
COPY unittests.cfg ${AIRFLOW_HOME}/unittests.cfg

# Create default user and group
ARG user=afpuser
ENV USER=${user}
ARG group=hadoop
ENV GROUP=${group}
RUN groupadd -r "${GROUP}" && useradd -rmg "${GROUP}" "${USER}"

# Number of times the Airflow scheduler will run before it terminates (and restarts)
ARG scheduler_runs=5
ENV SCHEDULER_RUNS=${scheduler_runs}
# parallelism = number of physical python processes the scheduler can run
ARG airflow__core__parallelism=8
ENV AIRFLOW__CORE__PARALLELISM=${airflow__core__parallelism}
# dag_concurrency = the number of TIs to be allowed to run PER-dag at once
ARG airflow__core__dag_concurrency=6
ENV AIRFLOW__CORE__DAG_CONCURRENCY=${airflow__core__dag_concurrency}
# max_threads = number of processes to parallelize the scheduler over, cannot exceed the cpu count
ARG airflow__scheduler__max_threads=4
ENV AIRFLOW__SCHEDULER__MAX_THREADS=${airflow__scheduler__max_threads}

# Airflow uses postgres as its database, following are the examples env vars
ARG postgres_host=localhost
ENV POSTGRES_HOST=${postgres_host}
ARG postgres_port=5999
ENV POSTGRES_PORT=${postgres_port}
ARG postgres_user=fixme
ENV POSTGRES_USER=${postgres_user}
ARG postgres_password=fixme
ENV POSTGRES_PASSWORD=${postgres_password}
ARG postgres_db=airflow
ENV POSTGRES_DB=${postgres_db}

WORKDIR ${AIRFLOW_HOME}

# Setup pipeline dependencies
COPY requirements.txt ${AIRFLOW_HOME}/requirements.txt
RUN pip install -r "${AIRFLOW_HOME}/requirements.txt"

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]


FROM no-spark AS with-spark-optional-dag

# Install Java
RUN apt-get update \
    && apt-get install -t jessie-backports --no-install-recommends -y openjdk-8-jre-headless \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

ARG SPARK_VERSION
ARG HADOOP_VERSION
ARG SPARK_PY4J

ARG hadoop_home=/opt/hadoop
ENV HADOOP_HOME=${hadoop_home}
ENV PATH=${PATH}:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin

ENV SPARK_HOME=/opt/spark-${SPARK_VERSION}
ENV PATH=$PATH:${SPARK_HOME}/bin
ENV PYTHONPATH=${SPARK_HOME}/${SPARK_PY4J}:${SPARK_HOME}/python
ENV PYSPARK_SUBMIT_ARGS="--driver-memory 8g --py-files ${SPARK_HOME}/python/lib/pyspark.zip pyspark-shell"

# Download Spark
ARG SPARK_EXTRACT_LOC=/sparkbin
RUN ["/bin/bash", "-c", "set -eoux pipefail && \
    (curl https://www.mirrorservice.org/sites/ftp.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz | \
    tar -xz -C /opt/) && \
    mv /opt/hadoop-${HADOOP_VERSION} /opt/hadoop && \
    mkdir -p ${SPARK_EXTRACT_LOC} && \
    (curl https://www.mirrorservice.org/sites/ftp.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION:0:3}.tgz | \
    tar -xz -C ${SPARK_EXTRACT_LOC}) && \
    mkdir -p ${SPARK_HOME} && \
    mv ${SPARK_EXTRACT_LOC}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION:0:3}/* ${SPARK_HOME} && \
    rm -rf ${SPARK_EXTRACT_LOC} && \
    echo SPARK_HOME is ${SPARK_HOME} && \
    ls -al --g ${SPARK_HOME}"]

# Less verbose logging
COPY log4j.properties.production ${SPARK_HOME}/conf/log4j.properties

# for optional S3 logging
COPY ./config/ ${AIRFLOW_HOME}/config/

FROM with-spark-optional-dag AS with-spark

## To build your own image:
ONBUILD COPY dags/ ${AIRFLOW_DAG}

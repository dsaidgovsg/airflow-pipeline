FROM python:2.7-stretch AS no-spark

# Setup airflow
RUN set -ex \
    && (echo 'deb http://deb.debian.org/debian stretch-backports main' > /etc/apt/sources.list.d/backports.list) \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y --force-yes build-essential libkrb5-dev libsasl2-dev libffi-dev default-libmysqlclient-dev vim-tiny gosu krb5-user \
    && apt-get purge --auto-remove -yqq \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/doc \
        /usr/share/doc-base \
    && pip install --no-cache-dir "apache-airflow[devel_hadoop,crypto,celery,redis,postgres,jdbc,ssh]==1.10.3" psycopg2

ARG airflow_home=/airflow
ENV AIRFLOW_HOME=${airflow_home}

WORKDIR ${AIRFLOW_HOME}

# Setup airflow dags path
ENV AIRFLOW_DAG=${AIRFLOW_HOME}/dags

RUN mkdir -p ${AIRFLOW_DAG}

COPY airflow.cfg ${AIRFLOW_HOME}/airflow.cfg
COPY unittests.cfg ${AIRFLOW_HOME}/unittests.cfg
COPY webserver_config.py ${AIRFLOW_HOME}/webserver_config.py

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

ENV AIRFLOW__CORE__EXECUTOR=LocalExecutor

WORKDIR ${AIRFLOW_HOME}

# Setup pipeline dependencies
COPY requirements.txt ${AIRFLOW_HOME}/requirements.txt
RUN pip install -r "${AIRFLOW_HOME}/requirements.txt"

# For optional S3 logging
COPY ./config/ ${AIRFLOW_HOME}/config/

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]


FROM no-spark AS with-spark-optional-dag

# Install Java
RUN apt-get update \
    && apt-get install --no-install-recommends -y openjdk-8-jre-headless \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

ARG SPARK_VERSION=2.1.2
ARG HADOOP_VERSION=2.6.5
ARG SPARK_PY4J=python/lib/py4j-0.10.4-src.zip

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
    (curl https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz | \
    tar -xz -C /opt/) && \
    mv /opt/hadoop-${HADOOP_VERSION} /opt/hadoop && \
    mkdir -p ${SPARK_EXTRACT_LOC} && \
    (curl https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION:0:3}.tgz | \
    tar -xz -C ${SPARK_EXTRACT_LOC}) && \
    mkdir -p ${SPARK_HOME} && \
    mv ${SPARK_EXTRACT_LOC}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION:0:3}/* ${SPARK_HOME} && \
    rm -rf ${SPARK_EXTRACT_LOC} && \
    echo SPARK_HOME is ${SPARK_HOME} && \
    ls -al --g ${SPARK_HOME}"]

# Less verbose logging
COPY log4j.properties.production ${SPARK_HOME}/conf/log4j.properties


FROM with-spark-optional-dag AS with-spark

## To build your own image:
ONBUILD COPY dags/ ${AIRFLOW_DAG}

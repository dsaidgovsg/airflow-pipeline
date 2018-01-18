FROM datagovsg/python-spark:2.7-1.6
MAINTAINER Chris Sng <chris@data.gov.sg>

# Setup airflow
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y vim-tiny libsasl2-dev libffi-dev \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir "apache-airflow[devel_hadoop, crypto]==1.9.0" psycopg2

ENV AIRFLOW_HOME /airflow

WORKDIR ${AIRFLOW_HOME}

# Setup airflow dags path
ENV AIRFLOW_DAG ${AIRFLOW_HOME}/dags

RUN mkdir -p ${AIRFLOW_DAG}

# Install gosu
ARG GOSU_VERSION=1.10
RUN set -x \
    && apt-get update && apt-get install -y --no-install-recommends ca-certificates wget \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true \
    && apt-get remove -y wget \
    && apt-get -y autoremove \
    && rm -rf /var/lib/apt/lists/*

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

# Example HDFS drop point which PySpark can use to access its datasets
ONBUILD ENV PIPELINE_DATA_PATH=hdfs://dsg-cluster-node01:8020/datasets/"${GROUP}"

WORKDIR ${AIRFLOW_HOME}

# Setup pipeline dependencies
COPY requirements.txt ${AIRFLOW_HOME}/requirements.txt
RUN pip install -r "${AIRFLOW_HOME}/requirements.txt"


ONBUILD COPY hadoop/conf/ ${HADOOP_CONF_DIR}/
ONBUILD COPY dags/ ${AIRFLOW_DAG}

COPY install_spark_packages.py ${AIRFLOW_HOME}/install_spark_packages.py
ONBUILD RUN gosu "${USER}" python install_spark_packages.py

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

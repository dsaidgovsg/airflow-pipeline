FROM datagovsg/python-spark-airflow:1.7
MAINTAINER Chris Sng <chris@data.gov.sg>

# Install gosu
ENV GOSU_VERSION 1.7
RUN set -x \
    && apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/* \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true \
    && apt-get -y autoremove

ENV USER afpuser
ENV GROUP hadoop
RUN groupadd -r "${GROUP}" && useradd -rmg "${GROUP}" "${USER}"

# Number of times the Airflow scheduler will run before it terminates (and restarts)
ENV SCHEDULER_RUNS=5
# parallelism = number of physical python processes the scheduler can run
ENV AIRFLOW_PARALLELISM=8
# dag_concurrency = the number of TIs to be allowed to run PER-dag at once
ENV AIRFLOW_DAG_CONCURRENCY=6

# Airflow uses postgres as its database, following are the examples env vars
ENV POSTGRES_HOST=localhost
ENV POSTGRES_PORT=5999
ENV POSTGRES_USER=fixme
ENV POSTGRES_PASSWORD=fixme
ENV POSTGRES_DB=airflow

# Example HDFS drop point which PySpark can use to access its datasets
ENV PIPELINE_DATA_PATH=hdfs://dsg-cluster-node01:8020/datasets/"${GROUP}"

WORKDIR ${AIRFLOW_HOME}

# Setup pipeline dependencies
COPY requirements.txt ${AIRFLOW_HOME}/requirements.txt
RUN pip install -r "${AIRFLOW_HOME}/requirements.txt"

VOLUME ${AIRFLOW_HOME}/logs

COPY airflow.cfg ${AIRFLOW_HOME}/airflow.cfg

COPY hadoop-sample/conf/ ${HADOOP_CONF_DIR}/
COPY dags/ ${AIRFLOW_DAG}

COPY setup_auth.py ${AIRFLOW_HOME}/setup_auth.py

COPY install_spark_packages.py ${AIRFLOW_HOME}/install_spark_packages.py
RUN gosu "${USER}" python install_spark_packages.py

COPY entrypoint.sh ${AIRFLOW_HOME}/entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]

# CMD ["airflow", "webserver"]

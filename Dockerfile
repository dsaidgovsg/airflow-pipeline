FROM python:2.7
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


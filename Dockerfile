ARG SPARK_VERSION=
ARG HADOOP_VERSION=

FROM guangie88/spark-k8s-addons:${SPARK_VERSION}_hadoop-${HADOOP_VERSION} AS base

# System and Hadoop side of set-up
ARG HADOOP_VERSION=

## Other Spark / Airflow related defaults
ARG HADOOP_HOME="/opt/hadoop"
ENV HADOOP_HOME="${HADOOP_HOME}"

ARG HADOOP_CONF_DIR="/opt/hadoop/etc/hadoop"
ENV HADOOP_CONF_DIR="${HADOOP_CONF_DIR}"

# Airflow will run as root instead of the spark 185 user meant for k8s
USER root

# Setup airflow
RUN set -euo pipefail && \
    # apk requirements
    apk add --no-cache \
        curl \
        su-exec \
        ; \
    # Set up gosu
    ln -s /sbin/su-exec /usr/local/bin/gosu; \
    gosu >/dev/null; \
    # Hadoop external installation
    mkdir -p "$(dirname "${HADOOP_HOME}")"; \
    wget "https://archive.apache.org/dist/hadoop/core/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"; \
    tar xf "hadoop-${HADOOP_VERSION}.tar.gz"; \
    mv "hadoop-${HADOOP_VERSION}" "${HADOOP_HOME}"; \
    rm "hadoop-${HADOOP_VERSION}.tar.gz"; \
    # Install JARs to Hadoop external
    ## AWS S3 JARs
    ## Get the aws-java-sdk version dynamic based on Hadoop version
    ## Do not use head -n1 because it will trigger 141 exit code due to early return on pipe
    AWS_JAVA_SDK_VERSION="$(curl -s https://raw.githubusercontent.com/apache/hadoop/branch-${HADOOP_VERSION}/hadoop-project/pom.xml | grep -A1 aws-java-sdk | grep -oE "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+" | tr "\r\n" " " | cut -d " " -f 1)"; \
    cd "${HADOOP_HOME}/share/hadoop/hdfs/"; \
    wget "http://central.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar"; \
    wget "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_JAVA_SDK_VERSION}/aws-java-sdk-bundle-${AWS_JAVA_SDK_VERSION}.jar"; \
    cd -; \
    printf "\
<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n\
<configuration>\n\
<property>\n\
    <name>fs.s3a.impl</name>\n\
    <value>org.apache.hadoop.fs.s3a.S3AFileSystem</value>\n\
</property>\n\
</configuration>\n" > ${HADOOP_CONF_DIR}/core-site.xml; \
    ## Google Storage JAR
    cd "${HADOOP_HOME}/share/hadoop/hdfs/"; \
    wget https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop2-latest.jar; \
    cd -; \
    ## MariaDB JAR
    cd "${HADOOP_HOME}/share/hadoop/tools/lib"; \
    wget https://downloads.mariadb.com/Connectors/java/connector-java-2.4.0/mariadb-java-client-2.4.0.jar; \
    cd -; \
    # Remove unused apk packages
    apk del \
        curl \
        ; \
    :

ENV PATH "${PATH}:${HADOOP_HOME}/bin"

# Conda side of set-up
ARG AIRFLOW_VERSION
ENV AIRFLOW_VERSION="${AIRFLOW_VERSION}"

ARG SQLALCHEMY_VERSION
ENV SQLALCHEMY_VERSION="${SQLALCHEMY_VERSION}"

ARG PYTHON_VERSION=

## Default user and group for running Airflow
ARG USER=afpuser
ENV USER="${USER}"
ARG GROUP=hadoop
ENV GROUP="${GROUP}"

RUN set -euo pipefail && \
    # Set up 
    addgroup "${GROUP}" && adduser -g "" -D -G "${GROUP}" "${USER}"; \
    # Airflow and SQLAlchemy
    ## These two version numbers can take MAJ.MIN[.PAT]
    AIRFLOW_NORM_VERSION="$(printf "%s.%s" "${AIRFLOW_VERSION}" "*" | cut -d '.' -f1,2,3)"; \
    SQLALCHEMY_NORM_VERSION="$(printf "%s.%s" "${SQLALCHEMY_VERSION}" "*" | cut -d '.' -f1,2,3)"; \
    conda config --add channels conda-forge; \
    conda create -y -n airflow "python=${PYTHON_VERSION}" "airflow=${AIRFLOW_NORM_VERSION}" "airflow-with-s3=${AIRFLOW_NORM_VERSION}" "sqlalchemy=${SQLALCHEMY_NORM_VERSION}" psycopg2 flask-bcrypt; \
    echo "conda activate airflow" >> "${HOME}/.bashrc"; \
    :

ARG AIRFLOW_HOME=/airflow
ENV AIRFLOW_HOME="${AIRFLOW_HOME}"

# Create the Airflow home
WORKDIR ${AIRFLOW_HOME}

# Setup airflow dags path
ENV AIRFLOW_DAG="${AIRFLOW_HOME}/dags"
RUN mkdir -p "${AIRFLOW_DAG}"

COPY setup_auth.py "${AIRFLOW_HOME}/setup_auth.py"
VOLUME "${AIRFLOW_HOME}/logs"
COPY airflow.cfg "${AIRFLOW_HOME}/airflow.cfg"
COPY unittests.cfg "${AIRFLOW_HOME}/unittests.cfg"

# Less verbose logging
COPY log4j.properties "${SPARK_HOME}/conf/log4j.properties"

# for optional S3 logging
COPY ./config/ "${AIRFLOW_HOME}/config/"

# All the other env vars that don't affect the build here
ENV PYTHONPATH="${PYTHONPATH}:${AIRFLOW_HOME}/config"
ENV PYSPARK_SUBMIT_ARGS="--py-files ${SPARK_HOME}/python/lib/pyspark.zip pyspark-shell"

## Airflow uses Postgres as its database, example env vars below
ARG POSTGRES_HOST=localhost
ENV POSTGRES_HOST="${POSTGRES_HOST}"

ARG POSTGRES_PORT=5999
ENV POSTGRES_PORT="${POSTGRES_PORT}"

ARG POSTGRES_USER=fixme
ENV POSTGRES_USER="${POSTGRES_USER}"

ARG POSTGRES_PASSWORD=fixme
ENV POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"

ARG POSTGRES_DB=airflow
ENV POSTGRES_DB="${POSTGRES_DB}"

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

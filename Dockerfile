ARG BASE_VERSION=v2
ARG SPARK_VERSION=
ARG HADOOP_VERSION=
ARG SCALA_VERSION=

FROM guangie88/spark-k8s-addons:${BASE_VERSION}_${SPARK_VERSION}_hadoop-${HADOOP_VERSION}_scala-${SCALA_VERSION} AS base

# Airflow will run as root instead of the spark 185 user meant for k8s
USER root

# Set up gosu
RUN set -euo pipefail && \
    apt-get update; \
    apt-get install -y --no-install-recommends gosu; \
	rm -rf /var/lib/apt/lists/*; \
    # Verify that the binary works
	gosu nobody true; \
    :

# Set up tini
ARG TINI_VERSION=0.18.0
ADD https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static-amd64 /usr/local/bin/tini
RUN set -euo pipefail && \
    chmod +x /usr/local/bin/tini; \
    tini --version >/dev/null; \
    :

# Set up Hadoop
ARG HADOOP_VERSION

## Other Spark / Airflow related defaults
ARG HADOOP_HOME="/opt/hadoop"
ENV HADOOP_HOME="${HADOOP_HOME}"

ARG HADOOP_CONF_DIR="/opt/hadoop/etc/hadoop"
ENV HADOOP_CONF_DIR="${HADOOP_CONF_DIR}"

RUN set -euo pipefail && \
    mkdir -p "$(dirname "${HADOOP_HOME}")"; \
    wget "https://archive.apache.org/dist/hadoop/core/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"; \
    tar xf "hadoop-${HADOOP_VERSION}.tar.gz"; \
    mv "hadoop-${HADOOP_VERSION}" "${HADOOP_HOME}"; \
    rm "hadoop-${HADOOP_VERSION}.tar.gz"; \
    # Install JARs to Hadoop external
    ## AWS S3 JARs
    ## Get the aws-java-sdk version dynamic based on Hadoop version
    ## Do not use head -n1 because it will trigger 141 exit code due to early return on pipe
    AWS_JAVA_SDK_VERSION="$(wget -qO- https://raw.githubusercontent.com/apache/hadoop/branch-${HADOOP_VERSION}/hadoop-project/pom.xml | grep -A1 aws-java-sdk | grep -oE "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+" | tr "\r\n" " " | cut -d " " -f 1)"; \
    cd "${HADOOP_HOME}/share/hadoop/hdfs/"; \
    wget "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar"; \
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
    cd "${HADOOP_HOME}/share/hadoop/tools/lib"; \
    ## MariaDB JAR
    wget https://downloads.mariadb.com/Connectors/java/connector-java-2.4.0/mariadb-java-client-2.4.0.jar; \
    ## Postgres JDBC JAR
    wget https://jdbc.postgresql.org/download/postgresql-42.2.9.jar; \
    cd -; \
    :

ENV PATH="${PATH}:${HADOOP_HOME}/bin"

# Set up Airflow via conda
ARG AIRFLOW_VERSION
ENV AIRFLOW_VERSION="${AIRFLOW_VERSION}"

ARG SQLALCHEMY_VERSION
ENV SQLALCHEMY_VERSION="${SQLALCHEMY_VERSION}"

ARG PYTHON_VERSION

ARG BOTO3_VERSION="1.9"
ARG CRYPTOGRAPHY_VERSION="2.8"
ARG PSYCOPG2_VERSION="2.8"
ARG FLASK_BCRYPT_VERSION="0.7"

RUN set -euo pipefail && \
    # Airflow and SQLAlchemy
    ## These two version numbers can take MAJ.MIN[.PAT]
    AIRFLOW_NORM_VERSION="$(printf "%s.%s" "${AIRFLOW_VERSION}" "*" | cut -d '.' -f1,2,3)"; \
    SQLALCHEMY_NORM_VERSION="$(printf "%s.%s" "${SQLALCHEMY_VERSION}" "*" | cut -d '.' -f1,2,3)"; \
    BOTO3_NORM_VERSION="$(printf "%s.%s" "${BOTO3_VERSION}" "*" | cut -d '.' -f1,2,3)"; \
    CRYPTOGRAPHY_NORM_VERSION="$(printf "%s.%s" "${CRYPTOGRAPHY_VERSION}" "*" | cut -d '.' -f1,2,3)"; \
    PSYCOPG2_NORM_VERSION="$(printf "%s.%s" "${PSYCOPG2_VERSION}" "*" | cut -d '.' -f1,2,3)"; \
    FLASK_BCRYPT_NORM_VERSION="$(printf "%s.%s" "${FLASK_BCRYPT_VERSION}" "*" | cut -d '.' -f1,2,3)"; \
    if [[ "${AIRFLOW_NORM_VERSION}" == "1.9.*" ]]; then \
        conda install -p "${CONDA_PREFIX}" -y \
            "python=${PYTHON_VERSION}" \
            "airflow=${AIRFLOW_NORM_VERSION}" \
            "airflow-with-celery=${AIRFLOW_NORM_VERSION}" \
            "airflow-with-crypto=${AIRFLOW_NORM_VERSION}" \
            "airflow-with-dask=${AIRFLOW_NORM_VERSION}" \
            "airflow-with-s3=${AIRFLOW_NORM_VERSION}" \
            "airflow-with-slack=${AIRFLOW_NORM_VERSION}" \
            "sqlalchemy=${SQLALCHEMY_NORM_VERSION}" \
            "boto3=${BOTO3_NORM_VERSION}" \
            "cryptography=${CRYPTOGRAPHY_NORM_VERSION}" \
            "psycopg2=${PSYCOPG2_NORM_VERSION}" \
            "flask-bcrypt=${FLASK_BCRYPT_NORM_VERSION}" \
            ; \
    else \
        conda install -p "${CONDA_PREFIX}" -y \
            "python=${PYTHON_VERSION}" \
            "airflow=${AIRFLOW_NORM_VERSION}" \
            "airflow-with-celery=${AIRFLOW_NORM_VERSION}" \
            "airflow-with-crypto=${AIRFLOW_NORM_VERSION}" \
            "airflow-with-dask=${AIRFLOW_NORM_VERSION}" \
            "airflow-with-kubernetes=${AIRFLOW_NORM_VERSION}" \
            "airflow-with-s3=${AIRFLOW_NORM_VERSION}" \
            "airflow-with-slack=${AIRFLOW_NORM_VERSION}" \
            "sqlalchemy=${SQLALCHEMY_NORM_VERSION}" \
            "boto3=${BOTO3_NORM_VERSION}" \
            "cryptography=${CRYPTOGRAPHY_NORM_VERSION}" \
            "psycopg2=${PSYCOPG2_NORM_VERSION}" \
            "flask-bcrypt=${FLASK_BCRYPT_NORM_VERSION}" \
            ; \
    fi; \
    ## Need to fix werkzeug <https://stackoverflow.com/a/60104502>
    conda install -p "${CONDA_PREFIX}" -y "werkzeug>=0.15,<0.17"; \
    conda clean -a -y; \
    :

ARG AIRFLOW_HOME=/airflow
ENV AIRFLOW_HOME="${AIRFLOW_HOME}"

# Create the Airflow home
WORKDIR ${AIRFLOW_HOME}

# Copy the entrypoint as root first but allow user to run
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x "/entrypoint.sh"
ENTRYPOINT ["/entrypoint.sh"]

# Less verbose logging
COPY log4j.properties "${SPARK_HOME}/conf/log4j.properties"

# Setup airflow dags path
ENV AIRFLOW_DAG="${AIRFLOW_HOME}/dags"
RUN mkdir -p "${AIRFLOW_DAG}"

COPY setup_auth.py test_db_conn.py ${AIRFLOW_HOME}/

# For S3 logging feature
COPY ./config/ "${AIRFLOW_HOME}/config/"

# All the other env vars that don't affect the build here
ENV PYTHONPATH="${PYTHONPATH}:${AIRFLOW_HOME}/config"
ENV PYSPARK_SUBMIT_ARGS="--py-files ${SPARK_HOME}/python/lib/pyspark.zip pyspark-shell"

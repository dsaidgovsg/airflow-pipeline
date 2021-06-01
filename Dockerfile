ARG BASE_VERSION=v4
ARG SPARK_VERSION
ARG HADOOP_VERSION
ARG SCALA_VERSION
ARG PYTHON_VERSION

FROM dsaidgovsg/spark-k8s-addons:${BASE_VERSION}_${SPARK_VERSION}_hadoop-${HADOOP_VERSION}_scala-${SCALA_VERSION}_python-${PYTHON_VERSION} AS base

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

# Set up Hadoop
ARG HADOOP_VERSION

## Other Spark / Airflow related defaults
ARG HADOOP_HOME="/opt/hadoop"
ENV HADOOP_HOME="${HADOOP_HOME}"

ARG HADOOP_CONF_DIR="/opt/hadoop/etc/hadoop"
ENV HADOOP_CONF_DIR="${HADOOP_CONF_DIR}"

RUN set -euo pipefail && \
    mkdir -p "$(dirname "${HADOOP_HOME}")"; \
    curl -LO "https://archive.apache.org/dist/hadoop/core/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"; \
    tar xf "hadoop-${HADOOP_VERSION}.tar.gz"; \
    mv "hadoop-${HADOOP_VERSION}" "${HADOOP_HOME}"; \
    rm "hadoop-${HADOOP_VERSION}.tar.gz"; \
    # Install JARs to Hadoop external
    ## AWS S3 JARs
    ## Get the aws-java-sdk version dynamic based on Hadoop version
    ## Do not use head -n1 because it will trigger 141 exit code due to early return on pipe
    AWS_JAVA_SDK_VERSION="$(curl https://raw.githubusercontent.com/apache/hadoop/branch-${HADOOP_VERSION}/hadoop-project/pom.xml | grep -A1 aws-java-sdk | grep -oE "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+" | tr "\r\n" " " | cut -d " " -f 1)"; \
    cd "${HADOOP_HOME}/share/hadoop/hdfs/"; \
    curl -LO "https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_VERSION}/hadoop-aws-${HADOOP_VERSION}.jar"; \
    curl -LO "https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_JAVA_SDK_VERSION}/aws-java-sdk-bundle-${AWS_JAVA_SDK_VERSION}.jar"; \
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
    curl -LO https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-hadoop2-latest.jar; \
    cd -; \
    cd "${HADOOP_HOME}/share/hadoop/tools/lib"; \
    ## MariaDB JAR
    curl -LO https://downloads.mariadb.com/Connectors/java/connector-java-2.4.0/mariadb-java-client-2.4.0.jar; \
    ## Postgres JDBC JAR
    curl -LO https://jdbc.postgresql.org/download/postgresql-42.2.9.jar; \
    cd -; \
    :

ENV PATH="${PATH}:${HADOOP_HOME}/bin"

# Set up Airflow via poetry
ARG AIRFLOW_VERSION
ENV AIRFLOW_VERSION="${AIRFLOW_VERSION}"

ARG SQLALCHEMY_VERSION
ENV SQLALCHEMY_VERSION="${SQLALCHEMY_VERSION}"

RUN set -euo pipefail && \
    # Airflow and SQLAlchemy
    # Postgres dev prereqs to install Airflow
    apt-get update; \
    apt-get install -y --no-install-recommends build-essential libpq5 libpq-dev; \
    ## These two version numbers can take MAJ.MIN[.PAT]
    if [ -z "${AIRFLOW_VERSION}" ]; then >&2 echo "Please specify AIRFLOW_VERSION" && exit 1; fi; \
    if [ -v "${SQLALCHEMY_VERSION}" ]; then >&2 echo "Please specify SQLALCHEMY_VERSION" && exit 1; fi; \
    AIRFLOW_NORM_VERSION="$(printf "%s.%s" "${AIRFLOW_VERSION}" "*" | cut -d '.' -f1,2,3)"; \
    SQLALCHEMY_NORM_VERSION="$(printf "%s.%s" "${SQLALCHEMY_VERSION}" "*" | cut -d '.' -f1,2,3)"; \
    pushd "${POETRY_SYSTEM_PROJECT_DIR}"; \
    if [[ "${AIRFLOW_NORM_VERSION}" == "2.1.*" ]]; then \
        poetry add \
            "apache-airflow==${AIRFLOW_NORM_VERSION}" \
            "sqlalchemy==${SQLALCHEMY_NORM_VERSION}" \
            "boto3" \
            "psycopg2" \
            ; \
    elif [[ "${AIRFLOW_NORM_VERSION}" == "1.9.*" ]]; then \
        poetry add \
            "apache-airflow==${AIRFLOW_NORM_VERSION}" \
            "sqlalchemy==${SQLALCHEMY_NORM_VERSION}" \
            "boto3" \
            "cryptography" \
            "psycopg2" \
            "flask-bcrypt" \
            # Required due to poetry issue https://github.com/python-poetry/poetry/issues/1287
            "python3-openid" \
            ## Need to fix werkzeug <https://stackoverflow.com/a/60459142>
            "werkzeug<1.0" \
            ; \
    else \
        poetry add \
            "apache-airflow==${AIRFLOW_NORM_VERSION}" \
            "sqlalchemy==${SQLALCHEMY_NORM_VERSION}" \
            "boto3" \
            "cryptography" \
            "psycopg2" \
            "flask-bcrypt" \
            # Required due to poetry issue https://github.com/python-poetry/poetry/issues/1287
            "python3-openid" \
            ## Need to fix werkzeug <https://stackoverflow.com/a/60459142>
            "werkzeug<1.0" \
            ; \
    fi; \
    popd; \
    ## Clean up dev files and only retain the runtime of Postgres lib
    apt-get remove -y build-essential libpq-dev; \
    rm -rf /var/lib/apt/lists/*; \
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

# All the other env vars that don't affect the build here
ENV PYSPARK_SUBMIT_ARGS="--py-files ${SPARK_HOME}/python/lib/pyspark.zip pyspark-shell"

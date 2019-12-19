# CHANGELOG

## v2

- Distro: Alpine
- Advertized CLI tools:
  - `gosu`
  - `conda`
- Advertized env vars:
  - `ENABLE_AIRFLOW_INITDB="true"`
    - Set to `"false"` to disable running `airflow initdb` when the command is
      either of the following:
      1. `"afp-scheduler"`
      2. `"afp-webserver"`
  - `HADOOP_HOME="/opt/hadoop"`
  - `HADOOP_CONF_DIR="/opt/hadoop/etc/hadoop"`
  - `USER="airflow"`
  - `GROUP="airflow"`
  - `AIRFLOW_HOME="/airflow"`
  - `AIRFLOW_DAG="${AIRFLOW_HOME}/dags"`
  - `PYTHONPATH="${PYTHONPATH}:${AIRFLOW_HOME}/config"`
  - `PYSPARK_SUBMIT_ARGS="--py-files ${SPARK_HOME}/python/lib/pyspark.zip pyspark-shell"`
  - `POSTGRES_HOST="localhost"`
  - `POSTGRES_PORT="5999"`
  - `POSTGRES_USER="fixme"`
  - `POSTGRES_PASSWORD="fixme"`
  - `POSTGRES_DB="airflow"`

## v1

- Distro: Alpine
- Advertized CLI tools:
  - `gosu`
  - `conda`
- Advertized env vars:
  - `HADOOP_HOME="/opt/hadoop"`
  - `HADOOP_CONF_DIR="/opt/hadoop/etc/hadoop"`
  - `USER="afpuser"`
  - `GROUP="hadoop"`
  - `AIRFLOW_HOME="/airflow"`
  - `AIRFLOW_DAG="${AIRFLOW_HOME}/dags"`
  - `PYTHONPATH="${PYTHONPATH}:${AIRFLOW_HOME}/config"`
  - `PYSPARK_SUBMIT_ARGS="--py-files ${SPARK_HOME}/python/lib/pyspark.zip pyspark-shell"`
  - `POSTGRES_HOST="localhost"`
  - `POSTGRES_PORT="5999"`
  - `POSTGRES_USER="fixme"`
  - `POSTGRES_PASSWORD="fixme"`
  - `POSTGRES_DB="airflow"`

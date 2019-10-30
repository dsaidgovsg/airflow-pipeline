# CHANGELOG

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

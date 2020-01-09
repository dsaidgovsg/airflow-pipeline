# CHANGELOG

## v3

Default `ENABLE_AIRFLOW_INITDB` to `"false"` instead of `"true"`, because
it generally not recommended to have defaults that make state changes
unknowingly that is hard to reverse. As such, one needs to set
`ENABLE_AIRFLOW_INITDB` to start off the entrypoint to perform
`airflow initdb` if preferred.

Combine `scheduler` and `webserver` by default, taking the tradeoff of ease of
setting up. `tini` is added and run by default when using default entrypoint to
manage the background processes.

As such, `afp-scheduler` and `afp-webserver` no longer have any meaning, and are
no longer captured by the entrypoint script.

Remove running of `airflow serve_logs`, which is meaningless outside of Celery
worker context.

No longer allow `USER` and `GROUP` to be overridden at runtime. The `USER` and
`GROUP` when running Airflow are assumed to be `airflow:airflow`, which is
aligned to set up the service to run on `systemd` as described in:
<https://airflow.apache.org/docs/1.10.7/howto/run-with-systemd.html>.

If Airflow logs directory is mounted into `/airflow/logs` (or the value in
`AIRFLOW__CORE__BASE_LOG_FOLDER`), one has to at least
`chown airflow <mounted directory>`. It is not recommended for the Docker
container to make ownership amendments on the host side in general. The default
Docker named volume mount that was present in `docker-compose.override.yml` was
also removed.

Install `airflow-with-crypto` in order to use `AIRFLOW__CORE__FERNET_KEY`
correctly.

Previous `POSTGRES_XXX` was wrongly advertized, one can simply use the standard
`AIRFLOW__CORE__SQL_ALCHEMY_CONN` to point to the desired database backend.

- Distro: Alpine
- Advertized CLI tools:
  - `tini`
  - `conda`
- Advertized additional scripts:
  - `"${AIRFLOW_HOME}/setup_auth.py"`
    - You can run it to easily add Airflow Web UI admin user with the following
      env vars (all are compulsory fields):
      - `AIRFLOW_USER`
      - `AIRFLOW_EMAIL`
      - `AIRFLOW_PASSWORD`
- Advertized env vars:
  - `ENABLE_AIRFLOW_INITDB="false"`
    - Set to `"true"` to enable `airflow initdb` as the starting command of the
      default entrypoint.
  - `ENABLE_AIRFLOW_WEBSERVER_LOG="false"`
    - This is set to `"false"` by default because of the verboseness when mixed
      together with the `scheduler`, which is usually the more important source
      of log.
  - `ENABLE_AIRFLOW_SETUP_AUTH="false"`
    - Note this is only useful to set to `"true"`, if
      `AIRFLOW__WEBSERVER__AUTHENTICATE` is set to `"true"`.
  - `HADOOP_HOME="/opt/hadoop"`
  - `HADOOP_CONF_DIR="/opt/hadoop/etc/hadoop"`
  - `AIRFLOW_HOME="/airflow"`
  - `AIRFLOW_DAG="${AIRFLOW_HOME}/dags"`
  - `PYTHONPATH="${PYTHONPATH}:${AIRFLOW_HOME}/config"`
  - `PYSPARK_SUBMIT_ARGS="--py-files ${SPARK_HOME}/python/lib/pyspark.zip pyspark-shell"`

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

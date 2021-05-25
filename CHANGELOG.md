# CHANGELOG

## v8

Add Airflow builds for v2.1.0.

Remove support for builds with Airflow v1.9 and Spark v2.

Update `entrypoint.sh` to support the new version of Airflow.

### BREAKING CHANGES:

`ENABLE_AIRFLOW_RBAC_SETUP_AUTH` takes on a different meaning for Airflow V2,
as only the RBAC UI is available in V2 while RBAC and non-RBAC UI is available
in V1. In V2, it creates a user with the given env vars.

Early return if Docker commands are supplied is shifted to after Airflow util
setups like `airflow db upgrade`, `airflow db init` etc. in `entrypoint.sh`

`ENABLE_AIRFLOW_TEST_DB_CONN` default value is now "false" instead of "true"

Remove installation of Airflow provider packages in the base image. They have
to be manually added back.

Remove logging config. Now instead of `S3_LOG_FOLDER` for S3 logging, use:
- `AIRFLOW__CORE__REMOTE_BASE_LOG_FOLDER` for v1.x Airflow
- `AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER` for v2.x Airflow

## v7

Same as [v6](#v6), but change base image again to use the native Python without
`pyenv`. Add `poetry` to properly manage pip dependency management. All
installations should be done only via `poetry`, and not via raw `pip`.

- Advertized CLI tools:
  - `gosu`
  - `tini`
  - `poetry` (`cd` to `${POETRY_SYSTEM_PROJECT_DIR}` before installing)

Advertized new env vars.
No changes to previous set of env vars, but the following are newly added:

- `POETRY_SYSTEM_PROJECT_DIR`
- `POETRY_HOME`
- `ENABLE_AIRFLOW_INITDB`, defaults to `"false"` in `entrypoint.sh`.
- `ENABLE_AIRFLOW_RBAC_SETUP_AUTH`, defaults to `"false"` in `entrypoint.sh`.
  Even if it set to true, it is only effective if `AIRFLOW__WEBSERVER__RBAC` is
  also set to `"true"`, since `airflow.cfg` needs to know if RBAC should be
  enabled.

  The following env vars are required when `ENABLE_AIRFLOW_RBAC_SETUP_AUTH` is
  set to `"true`:

  - `AIRFLOW_WEBSERVER_RBAC_ROLE`, defaults to `Admin`.
  - `AIRFLOW_WEBSERVER_RBAC_USER`
  - `AIRFLOW_WEBSERVER_RBAC_PASSWORD`
  - `AIRFLOW_WEBSERVER_RBAC_EMAIL`
  - `AIRFLOW_WEBSERVER_RBAC_FIRST_NAME`
  - `AIRFLOW_WEBSERVER_RBAC_LAST_NAME`

  Note that using RBAC makes the previous `ENABLE_AIRFLOW_SETUP_AUTH` set-up
  irrelevant, since the login mechanism in newer Airflow has two different
  bifurcated set-ups.

## v6

Change base image, therefore dropping `conda` and now comes with `pyenv`.

Remove all build args to control non-critical `pip` package versions, which
include:

- `boto3`
- `cryptography`
- `psycopg2`
- `flask-bcrypt`

This is allow `pip` to have flexibility to choose the appropriate versions to
prevent version compabilities across all the packages.

Changes to advertized CLI tools:

- No more `conda`, due to the switch of image to use `pyenv`. Thus `pip` is now
  the de-facto package installer.

## v5

The only change from `v4` is the distro has been changed from Alpine to Debian,
because only the Spark v3 preview release candidates have been built. The
Kubernetes Dockerfiles for these tags are entirely based on Debian, hence the
above change.

The above also reverts the need to use custom built `.so` to make things work
for `glibc`, because previously Alpine needed them.

Also target specific Scala versions to build for, and now Scala version is part
of the Docker image tag.

No changes to env vars.

- Distro: Debian
- Advertized CLI tools:
  - `gosu`
  - `tini`
  - `conda`
- Advertized JARs for Hadoop:
  - Hadoop AWS SDK
  - AWS Java SDK Bundle
  - GCS Connector
  - MariaDB Connector
  - Postgres JDBC
- Advertized additional scripts:
  - `"${AIRFLOW_HOME}/setup_auth.py"`
  - `"${AIRFLOW_HOME}/test_db_conn.py"`
    - Suffice to just run `python "${AIRFLOW_HOME}/test_db_conn.py"` as it will
      automatically take the `('core', 'sql_alchemy_conn')` Airflow conf value.
      Both setting via env var `AIRFLOW__CORE__SQL_ALCHEMY_CONN` (this takes
      precedence) and `airflow.cfg` conf file would work.
- Advertized env vars:
  - `ENABLE_AIRFLOW_ADD_USER_GROUP="true"`
    - Default to `"true"`. Add Airflow user and group based on `AIRFLOW_USER`
      and `AIRFLOW_GROUP`. If set to `"false"`, you are likely and should set
      `ENABLE_AIRFLOW_CHOWN` to `"false"`.
  - `ENABLE_AIRFLOW_CHOWN="true"`
    - Default to `"true"`. Allow entrypoint to perform recursive `chown` to
      `${AIRFLOW_USER}:${AIRFLOW_GROUP}` on `${AIRFLOW_HOME}` directory.
  - `ENABLE_AIRFLOW_TEST_DB_CONN="true"`
    - Default to `"true"`. Enable database test connection before running any
      other Airflow commands.
  - `ENABLE_AIRFLOW_INITDB="false"`
  - `ENABLE_AIRFLOW_WEBSERVER_LOG="false"`
  - `ENABLE_AIRFLOW_SETUP_AUTH="false"`
  - `AIRFLOW_USER=airflow`
  - `AIRFLOW_GROUP=airflow`
  - `HADOOP_HOME="/opt/hadoop"`
  - `HADOOP_CONF_DIR="/opt/hadoop/etc/hadoop"`
  - `AIRFLOW_HOME="/airflow"`
  - `AIRFLOW_DAG="${AIRFLOW_HOME}/dags"`
  - `PYTHONPATH="${PYTHONPATH}:${AIRFLOW_HOME}/config"`
  - `PYSPARK_SUBMIT_ARGS="--py-files ${SPARK_HOME}/python/lib/pyspark.zip pyspark-shell"`

## v4

The following env vars are renamed:

- `AIRFLOW_USER` -> `AIRFLOW_WEBSERVER_USER`
- `AIRFLOW_EMAIL` -> `AIRFLOW_WEBSERVER_EMAIL`
- `AIRFLOW_PASSWORD` -> `AIRFLOW_WEBSERVER_PASSWORD`

Revert and allow back the usage of `gosu`, now Airflow user and group are
always created at runtime if the `entrypoint.sh` is used. As such, the `USER` in
Dockerfile is reverted back to `root`, and the usage of Airflow user is only
impersonated via `gosu`. This gives much better installation / file copy
ergonomics when other Docker images derive over this image.

Also the Airflow user and group names can be overridden via the respective env
vars:

- `AIRFLOW_USER` (hence the above env vars naming change was required)
- `AIRFLOW_GROUP`

The default is `airflow:airflow`.

- Distro: Alpine
- Advertized CLI tools:
  - `gosu`
  - `tini`
  - `conda`
- Advertized Airflow add-ons installed:
  - `airflow-with-celery`
  - `airflow-with-crypto`
  - `airflow-with-dask`
  - `airflow-with-kubernetes` (only for Airflow 1.10)
  - `airflow-with-s3`
  - `airflow-with-slack`
- Advertized JARs for Hadoop:
  - Hadoop AWS SDK
  - AWS Java SDK Bundle
  - GCS Connector
  - MariaDB Connector
  - Postgres JDBC
- Advertized additional scripts:
  - `"${AIRFLOW_HOME}/setup_auth.py"`
  - `"${AIRFLOW_HOME}/test_db_conn.py"`
    - Suffice to just run `python "${AIRFLOW_HOME}/test_db_conn.py"` as it will
      automatically take the `('core', 'sql_alchemy_conn')` Airflow conf value.
      Both setting via env var `AIRFLOW__CORE__SQL_ALCHEMY_CONN` (this takes
      precedence) and `airflow.cfg` conf file would work.
- Advertized env vars:
  - `ENABLE_AIRFLOW_ADD_USER_GROUP="true"`
    - Default to `"true"`. Add Airflow user and group based on `AIRFLOW_USER`
      and `AIRFLOW_GROUP`. If set to `"false"`, you are likely and should set
      `ENABLE_AIRFLOW_CHOWN` to `"false"`.
  - `ENABLE_AIRFLOW_CHOWN="true"`
    - Default to `"true"`. Allow entrypoint to perform recursive `chown` to
      `${AIRFLOW_USER}:${AIRFLOW_GROUP}` on `${AIRFLOW_HOME}` directory.
  - `ENABLE_AIRFLOW_TEST_DB_CONN="true"`
    - Default to `"true"`. Enable database test connection before running any
      other Airflow commands.
  - `ENABLE_AIRFLOW_INITDB="false"`
  - `ENABLE_AIRFLOW_WEBSERVER_LOG="false"`
  - `ENABLE_AIRFLOW_SETUP_AUTH="false"`
  - `AIRFLOW_USER=airflow`
  - `AIRFLOW_GROUP=airflow`
  - `HADOOP_HOME="/opt/hadoop"`
  - `HADOOP_CONF_DIR="/opt/hadoop/etc/hadoop"`
  - `AIRFLOW_HOME="/airflow"`
  - `AIRFLOW_DAG="${AIRFLOW_HOME}/dags"`
  - `PYTHONPATH="${PYTHONPATH}:${AIRFLOW_HOME}/config"`
  - `PYSPARK_SUBMIT_ARGS="--py-files ${SPARK_HOME}/python/lib/pyspark.zip pyspark-shell"`

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

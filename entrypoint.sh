#!/bin/bash
set -euo pipefail

# Set up default user and group for running Airflow
AIRFLOW_USER="${AIRFLOW_USER:-airflow}"
AIRFLOW_GROUP="${AIRFLOW_GROUP:-airflow}"
addgroup "${AIRFLOW_GROUP}" && adduser -g "" -D -G "${AIRFLOW_GROUP}" "${AIRFLOW_USER}"

# This possibly changes the log directory that might be mounted in
chown "${AIRFLOW_USER}:${AIRFLOW_GROUP}" -R "${AIRFLOW_HOME}/"

# This "early returns" so that it gives bash-like effect when we don't want to
# do Airflow related operations
if [ "$#" -ne 0 ]; then
  exec tini -- gosu "${AIRFLOW_USER}" "$@"
fi

# Set to "true" to enable the following env vars
ENABLE_AIRFLOW_TEST_DB_CONN="${ENABLE_AIRFLOW_TEST_DB_CONN:-true}"
ENABLE_AIRFLOW_INITDB="${ENABLE_AIRFLOW_INITDB:-false}"
ENABLE_AIRFLOW_WEBSERVER_LOG="${ENABLE_AIRFLOW_WEBSERVER_LOG:-false}"
ENABLE_AIRFLOW_SETUP_AUTH="${ENABLE_AIRFLOW_SETUP_AUTH:-false}"

# To include Hadoop JAR classes for Spark usage
SPARK_DIST_CLASSPATH="$(hadoop classpath)"
export SPARK_DIST_CLASSPATH

if [ "${ENABLE_AIRFLOW_TEST_DB_CONN}" = "true" ] || [ "${ENABLE_AIRFLOW_TEST_DB_CONN}" = "True" ]; then
  echo "Testing database connection for Airflow..."
  gosu "${AIRFLOW_USER}" python test_db_conn.py
  echo "Database connection test successful!"
fi


# https://groups.google.com/forum/#!topic/airbnb_airflow/4ZGWUzKkBbw
if [ "${ENABLE_AIRFLOW_INITDB}" = "true" ] || [ "${ENABLE_AIRFLOW_INITDB}" = "True" ]; then
  echo "Initializing database for Airflow..."
  gosu "${AIRFLOW_USER}" airflow initdb
  echo "Database is initialized with Airflow metadata!"
fi

if [ "${ENABLE_AIRFLOW_SETUP_AUTH}" = "true" ] || [ "${ENABLE_AIRFLOW_SETUP_AUTH}" = "True" ]; then
  echo "Adding admin user for Airflow Web UI login..."
  gosu "${AIRFLOW_USER}" python "${AIRFLOW_HOME}/setup_auth.py" \
    -u "${AIRFLOW_WEBSERVER_USER}" \
    -e "${AIRFLOW_WEBSERVER_EMAIL}" \
    -p "${AIRFLOW_WEBSERVER_PASSWORD}"
  echo "Admin user added!"
fi

# Start webserver as background process first
if [ "${ENABLE_AIRFLOW_WEBSERVER_LOG}" = "true" ] || [ "${ENABLE_AIRFLOW_WEBSERVER_LOG}" = "True" ]; then
  echo "Starting webserver with logging..."
  gosu "${AIRFLOW_USER}" airflow webserver &
else
  echo "Starting webserver without logging..."
  gosu "${AIRFLOW_USER}" airflow webserver >/dev/null &
fi

# Then start scheduler as foreground
echo "Starting scheduler..."
exec tini -- gosu "${AIRFLOW_USER}" airflow scheduler

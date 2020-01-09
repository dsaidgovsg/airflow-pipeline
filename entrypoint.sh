#!/bin/bash
set -euo pipefail

# This "early returns" so that it gives bash-like effect when we don't want to
# do Airflow related operations
if [ "$#" -ne 0 ]; then
  exec tini -- "$@"
fi

echo "Running as: $(whoami)"

# Set to "true" to enable the following env vars
ENABLE_AIRFLOW_INITDB="${ENABLE_AIRFLOW_INITDB:-false}"
ENABLE_AIRFLOW_WEBSERVER_LOG="${ENABLE_AIRFLOW_WEBSERVER_LOG:-false}"
ENABLE_AIRFLOW_SETUP_AUTH="${ENABLE_AIRFLOW_SETUP_AUTH:-false}"

# To include Hadoop JAR classes for Spark usage
SPARK_DIST_CLASSPATH="$(hadoop classpath)"
export SPARK_DIST_CLASSPATH

# For Airflow scheduler and webserver usage
POSTGRES_TIMEOUT=60
CONN_PARTS_REGEX='postgresql://\([-a-zA-Z0-9_]\+\):\([[:print:]]\+\)@\([-a-zA-Z0-9_\.]\+\):\([0-9]\+\)/\([[:print:]]\+\)'

# Do not use `/` or whatever symbol that exists in the above var
POSTGRES_USER="$(echo "${AIRFLOW__CORE__SQL_ALCHEMY_CONN}" | sed -e "s#${CONN_PARTS_REGEX}#\1#")"
export POSTGRES_USER
POSTGRES_PASSWORD="$(echo "${AIRFLOW__CORE__SQL_ALCHEMY_CONN}" | sed -e "s#${CONN_PARTS_REGEX}#\2#")"
export POSTGRES_PASSWORD
POSTGRES_HOST="$(echo "${AIRFLOW__CORE__SQL_ALCHEMY_CONN}" | sed -e "s#${CONN_PARTS_REGEX}#\3#")"
export POSTGRES_HOST
POSTGRES_PORT="$(echo "${AIRFLOW__CORE__SQL_ALCHEMY_CONN}" | sed -e "s#${CONN_PARTS_REGEX}#\4#")"
export POSTGRES_PORT
POSTGRES_DB="$(echo "${AIRFLOW__CORE__SQL_ALCHEMY_CONN}" | sed -e "s#${CONN_PARTS_REGEX}#\5#")"
export POSTGRES_DB

set +e
# Wait for Postgres to be available
# Strategy from http://superuser.com/a/806331/98716
DATABASE_DEV="/dev/tcp/${POSTGRES_HOST}/${POSTGRES_PORT}"
echo "Checking database connection ${DATABASE_DEV}"
timeout -t ${POSTGRES_TIMEOUT} bash <<EOT
while ! (echo > "${DATABASE_DEV}") >/dev/null 2>&1; do
    echo "Waiting for database ${DATABASE_DEV}"
    sleep 2;
done;
EOT
RESULT=$?

if [ ${RESULT} -eq 0 ]; then
    echo "Database available"
else
    echo "Database is not available"
    exit 1
fi
set -e

# https://groups.google.com/forum/#!topic/airbnb_airflow/4ZGWUzKkBbw
if [ "${ENABLE_AIRFLOW_INITDB}" = "true" ] || [ "${ENABLE_AIRFLOW_INITDB}" = "True" ]; then
  echo "Initializing Postgres database for Airflow..."
  airflow initdb
fi

if [ "${ENABLE_AIRFLOW_SETUP_AUTH}" = "true" ] || [ "${ENABLE_AIRFLOW_SETUP_AUTH}" = "True" ]; then
  echo "Adding admin user for Airflow Web UI login..."
  python "${AIRFLOW_HOME}/setup_auth.py" \
    -u "${AIRFLOW_USER}" \
    -e "${AIRFLOW_EMAIL}" \
    -p "${AIRFLOW_PASSWORD}"
fi

# Start webserver as background process first
if [ "${ENABLE_AIRFLOW_WEBSERVER_LOG}" = "true" ] || [ "${ENABLE_AIRFLOW_WEBSERVER_LOG}" = "True" ]; then
  echo "Starting webserver with logging..."
  airflow webserver &
else
  echo "Starting webserver without logging..."
  airflow webserver >/dev/null &
fi

# Then start scheduler as foreground
echo "Starting scheduler..."
exec tini -- airflow scheduler

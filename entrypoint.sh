#!/bin/bash
set -euo pipefail

# Set to "false" to disable Airflow initdb at the start
ENABLE_AIRFLOW_INITDB="${ENABLE_AIRFLOW_INITDB:-true}"

# To include Hadoop JAR classes for Spark usage
SPARK_DIST_CLASSPATH="$(hadoop classpath)"
export SPARK_DIST_CLASSPATH

# This "early returns" so that it gives bash-like effect when we don't want to
# do Airflow related operations
if [ "$#" -eq 0 ]; then
  exec bash
elif [ "$1" = "gosu-run" ]; then
  shift
  exec gosu "${USER}" "$@"
elif [ "$1" != "afp-scheduler" ] && [ "$1" != "afp-webserver" ]; then
  exec "$@"
fi

# For Airflow scheduler and webserver usage
POSTGRES_TIMEOUT=60

getent group "${GROUP}" || addgroup -S "${GROUP}"
id "${USER}" || adduser -S -D -G "${GROUP}" "${USER}"

echo "Running as: ${USER}"
if [ "${USER}" != "root" ]; then
  echo "Changing owner of files in ${AIRFLOW_HOME} to ${USER}"
  chown -R "${USER}" "${AIRFLOW_HOME}" || true
fi

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
if [ "${ENABLE_AIRFLOW_INITDB}" = "true" ]; then
  gosu "${USER}" airflow initdb
fi

if [ "$1" = "afp-scheduler" ]; then
  (while :; do echo "Serving logs"; gosu "${USER}" airflow serve_logs; sleep 1; done) &
  (while :; do echo "Starting scheduler"; gosu "${USER}" airflow scheduler -n "${SCHEDULER_RUNS:-5}"; sleep 1; done)
elif [ "$1" = "afp-webserver" ]; then
  echo "Starting webserver"
  python "${AIRFLOW_HOME}"/setup_auth.py

  if [[ -v WEBSERVER_PORT ]]; then
    exec gosu "${USER}" airflow webserver -p "${WEBSERVER_PORT}"
  else
    exec gosu "${USER}" airflow webserver
  fi
fi

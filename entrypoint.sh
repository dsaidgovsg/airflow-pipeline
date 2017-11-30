#!/bin/bash
set -euo pipefail

export SPARK_DIST_CLASSPATH=$(hadoop classpath)
POSTGRES_TIMEOUT=60

echo "Running as: ${USER}"
if [ "${USER}" != "root" ]; then
  echo "Changing owner of files in ${AIRFLOW_HOME} to ${USER}"
  chown -R "${USER}" ${AIRFLOW_HOME} || true
fi

CONN_PARTS_REGEX='postgresql://\([-a-zA-Z0-9_]\+\):\([[:print:]]\+\)@\([-a-zA-Z0-9_\.]\+\):\([0-9]\+\)/\([[:print:]]\+\)'
export POSTGRES_USER=$(echo $AIRFLOW__CORE__SQL_ALCHEMY_CONN | sed -e 's#'${CONN_PARTS_REGEX}'#\1#')
export POSTGRES_PASSWORD=$(echo $AIRFLOW__CORE__SQL_ALCHEMY_CONN | sed -e 's#'${CONN_PARTS_REGEX}'#\2#')
export POSTGRES_HOST=$(echo $AIRFLOW__CORE__SQL_ALCHEMY_CONN | sed -e 's#'${CONN_PARTS_REGEX}'#\3#')
export POSTGRES_PORT=$(echo $AIRFLOW__CORE__SQL_ALCHEMY_CONN | sed -e 's#'${CONN_PARTS_REGEX}'#\4#')
export POSTGRES_DB=$(echo $AIRFLOW__CORE__SQL_ALCHEMY_CONN | sed -e 's#'${CONN_PARTS_REGEX}'#\5#')

set +e
# Wait for Postgres to be available
# Strategy from http://superuser.com/a/806331/98716
DATABASE_DEV="/dev/tcp/${POSTGRES_HOST}/${POSTGRES_PORT}"
echo "Checking database connection ${DATABASE_DEV}"
timeout ${POSTGRES_TIMEOUT} bash <<EOT
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

gosu "${USER}" airflow initdb # https://groups.google.com/forum/#!topic/airbnb_airflow/4ZGWUzKkBbw

if [ "$1" = 'afp-scheduler' ]; then
  (while :; do echo 'Serving logs'; gosu "${USER}" airflow serve_logs; sleep 1; done) &
  (while :; do echo 'Starting scheduler'; gosu "${USER}" airflow scheduler -n ${SCHEDULER_RUNS}; sleep 1; done)
elif [ "$1" = 'afp-webserver' ]; then
  echo "Starting webserver"
  python "${AIRFLOW_HOME}"/setup_auth.py
  exec gosu "${USER}" airflow webserver
else
  exec gosu "${USER}" "$@"
fi

#!/bin/bash
set -euo pipefail

export SPARK_DIST_CLASSPATH=$(hadoop classpath)
WAIT_TIMEOUT=60

getent group ${GROUP} || groupadd -r ${GROUP}
id ${USER} || useradd -rmg ${GROUP} ${USER}

echo "Running as: ${USER}"
if [ "${USER}" != "root" ]; then
  echo "Changing owner of files in ${AIRFLOW_HOME} to ${USER}"
  chown -R "${USER}" ${AIRFLOW_HOME} || true
fi

SQL_ALCHEMY_CONN_PARTS_REGEX='postgresql://\([-a-zA-Z0-9_]\+\):\([[:print:]]\+\)@\([-a-zA-Z0-9_\.]\+\):\([0-9]\+\)/\([[:print:]]\+\)'
export POSTGRES_USER=$(echo $AIRFLOW__CORE__SQL_ALCHEMY_CONN | sed -e 's#'${SQL_ALCHEMY_CONN_PARTS_REGEX}'#\1#')
export POSTGRES_PASSWORD=$(echo $AIRFLOW__CORE__SQL_ALCHEMY_CONN | sed -e 's#'${SQL_ALCHEMY_CONN_PARTS_REGEX}'#\2#')
export POSTGRES_HOST=$(echo $AIRFLOW__CORE__SQL_ALCHEMY_CONN | sed -e 's#'${SQL_ALCHEMY_CONN_PARTS_REGEX}'#\3#')
export POSTGRES_PORT=$(echo $AIRFLOW__CORE__SQL_ALCHEMY_CONN | sed -e 's#'${SQL_ALCHEMY_CONN_PARTS_REGEX}'#\4#')
export POSTGRES_DB=$(echo $AIRFLOW__CORE__SQL_ALCHEMY_CONN | sed -e 's#'${SQL_ALCHEMY_CONN_PARTS_REGEX}'#\5#')

wait_for_service() {
  set +e
  local name="$1" host="$2" port="$3"
  local device="/dev/tcp/${host}/${port}"
  timeout $WAIT_TIMEOUT bash <<EOT
while ! (echo > "${device}") >/dev/null 2>&1; do
    echo "Waiting for ${name} ${device}"
    sleep 2;
done;
EOT
  result=$?

  if [ ${result} -eq 0 ]; then
    echo "${name} available"
  else
    echo "${name} is not available"
    exit 1
  fi
  set -e
}

wait_for_postgres() {
  if [ "$AIRFLOW__CORE__EXECUTOR" != "SequentialExecutor" ]; then
    export AIRFLOW__CELERY__RESULT_BACKEND="db+postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB"
    wait_for_service "Postgres" "$POSTGRES_HOST" "$POSTGRES_PORT"
  fi
}

wait_for_redis() {
  if [ "$AIRFLOW__CORE__EXECUTOR" = "CeleryExecutor" ]; then
    CELERY_CONN_PARTS_REGEX='\([[:print:]]\+\)://\([[:print:]]\+\)@\([-a-zA-Z0-9_\.]\+\):\([0-9]\+\)/\([[:print:]]\+\)'
    export CELERY_PROTO=$(echo $AIRFLOW__CELERY__BROKER_URL | sed -e 's#'${CELERY_CONN_PARTS_REGEX}'#\1#')
    export CELERY_HOST=$(echo $AIRFLOW__CELERY__BROKER_URL | sed -e 's#'${CELERY_CONN_PARTS_REGEX}'#\3#')
    export CELERY_PORT=$(echo $AIRFLOW__CELERY__BROKER_URL | sed -e 's#'${CELERY_CONN_PARTS_REGEX}'#\4#')
    wait_for_service "$CELERY_PROTO" "$CELERY_HOST" "$CELERY_PORT"
  fi
}


if [ "$1" = 'afp-scheduler' ]; then
  wait_for_postgres
  wait_for_redis
  if [ "$AIRFLOW_SCHEDULER_INITDB" = "true" ]; then
    gosu "${USER}" airflow initdb
  fi
  (while :; do echo 'Serving logs'; gosu "${USER}" airflow serve_logs; sleep 1; done) &
  (while :; do echo 'Starting scheduler'; gosu "${USER}" airflow scheduler -n ${SCHEDULER_RUNS}; sleep 1; done)
elif [ "$1" = 'afp-webserver' ]; then
  wait_for_postgres
  gosu "${USER}" airflow create_user -r Admin -u ${AIRFLOW_USER} -p ${AIRFLOW_PASSWORD} -e ${AIRFLOW_EMAIL} -f ${AIRFLOW_USER} -l Admin || true
  echo "Starting webserver"
  exec gosu "${USER}" airflow webserver
elif [ "$1" = 'afp-flower' ]; then
  wait_for_postgres
  wait_for_redis
  echo "Starting flower"
  exec gosu "${USER}" airflow flower
elif [ "$1" = 'afp-worker' ]; then
  wait_for_postgres
  wait_for_redis
  echo "Starting worker"
  exec gosu "${USER}" airflow worker
else
  exec gosu "${USER}" "$@"
fi

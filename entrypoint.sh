#!/bin/bash
set -euo pipefail

check_set () {
  [ "$1" = "true" ] || [ "$1" = "True" ]
}

# Set to "false" to disable the following env vars
ENABLE_AIRFLOW_ADD_USER_GROUP="${ENABLE_AIRFLOW_ADD_USER_GROUP:-true}"
ENABLE_AIRFLOW_CHOWN="${ENABLE_AIRFLOW_CHOWN:-true}"

# Set to "true" to enable the following env vars
ENABLE_AIRFLOW_INITDB="${ENABLE_AIRFLOW_INITDB:-false}"
ENABLE_AIRFLOW_UPGRADEDB="${ENABLE_AIRFLOW_UPGRADEDB:-false}"
ENABLE_AIRFLOW_WEBSERVER_LOG="${ENABLE_AIRFLOW_WEBSERVER_LOG:-false}"
ENABLE_AIRFLOW_SETUP_AUTH="${ENABLE_AIRFLOW_SETUP_AUTH:-false}"
ENABLE_AIRFLOW_RBAC_SETUP_AUTH="${ENABLE_AIRFLOW_RBAC_SETUP_AUTH:-false}"
ENABLE_AIRFLOW_TEST_DB_CONN="${ENABLE_AIRFLOW_TEST_DB_CONN:-false}"

# Other good defaults
## https://airflow.apache.org/docs/stable/security.html?highlight=ldap#default-roles
AIRFLOW_WEBSERVER_RBAC_ROLE="${AIRFLOW_WEBSERVER_RBAC_ROLE:-Admin}"

# Set up default user and group for running Airflow
if check_set "${ENABLE_AIRFLOW_ADD_USER_GROUP}"; then
  AIRFLOW_USER="${AIRFLOW_USER:-airflow}"
  AIRFLOW_GROUP="${AIRFLOW_GROUP:-airflow}"

  # Add group if does not exist yet
  if ! getent group "${AIRFLOW_GROUP}" >/dev/null; then
    echo "Adding Airflow group \"${AIRFLOW_GROUP}\"..."
    addgroup "${AIRFLOW_GROUP}"
  else
    echo "Airflow group \"${AIRFLOW_GROUP}\" already exists, ignoring..."
  fi

  # Add user if does not exist yet
  if ! getent passwd "${AIRFLOW_USER}" >/dev/null; then
    echo "Adding Airflow user \"${AIRFLOW_USER}\"..."
    adduser --gecos "" --disabled-password --ingroup "${AIRFLOW_GROUP}" "${AIRFLOW_USER}"
  else
    echo "Airflow user \"${AIRFLOW_USER}\" already exists, ignoring..."
  fi

  find "${AIRFLOW_HOME}" -executable -print0 | xargs --null chmod g+x && \
      find "${AIRFLOW_HOME}" -print0 | xargs --null chmod g+rw

  echo "Done adding Airflow user and group!"
else
  AIRFLOW_USER="$(id -nu)"
  AIRFLOW_GROUP="$(id -ng)"
fi

# This possibly changes the log directory that might be mounted in
if check_set "${ENABLE_AIRFLOW_CHOWN}"; then
  echo "Chowning ${AIRFLOW_HOME} to ${AIRFLOW_USER}:${AIRFLOW_GROUP}..."
  mkdir -pv "${AIRFLOW_HOME}/dags"; \
  mkdir -pv "${AIRFLOW_HOME}/logs"; \
  chown -R "${AIRFLOW_USER}:root" "${AIRFLOW_HOME}/"
  echo "Chowning done!"
fi

# To include Hadoop JAR classes for Spark usage
SPARK_DIST_CLASSPATH="$(hadoop classpath)"
export SPARK_DIST_CLASSPATH

if check_set "${ENABLE_AIRFLOW_TEST_DB_CONN}"; then
  echo "Testing database connection for Airflow..."
  gosu "${AIRFLOW_USER}" python test_db_conn.py
  echo "Database connection test successful!"
fi

# https://groups.google.com/forum/#!topic/airbnb_airflow/4ZGWUzKkBbw
if check_set "${ENABLE_AIRFLOW_INITDB}"; then
  echo "Initializing database for Airflow..."
  gosu "${AIRFLOW_USER}" airflow db init
  echo "Database is initialized with Airflow metadata!"
fi

if check_set "${ENABLE_AIRFLOW_UPGRADEDB}"; then
  echo "Upgrading database schema for Airflow..."
  gosu "${AIRFLOW_USER}" airflow db upgrade
  echo "Database is upgraded with latest Airflow metadata schema!"
fi

if check_set "${ENABLE_AIRFLOW_SETUP_AUTH}"; then
  echo "Adding admin user for Airflow Web UI login..."
  gosu "${AIRFLOW_USER}" python "${AIRFLOW_HOME}/setup_auth.py" \
    -u "${AIRFLOW_WEBSERVER_USER}" \
    -e "${AIRFLOW_WEBSERVER_EMAIL}" \
    -p "${AIRFLOW_WEBSERVER_PASSWORD}"
  echo "Admin user added!"
fi

AIRFLOW_VERSION="$(gosu "${AIRFLOW_USER}" airflow version)"
AIRFLOW_X_VERSION="$(echo ${AIRFLOW_VERSION} | cut -d . -f 1)"
AIRFLOW_Y_VERSION="$(echo ${AIRFLOW_VERSION} | cut -d . -f 2)"

# Requires 'rbac' mode to be set to true to run the command properly
if check_set "${ENABLE_AIRFLOW_RBAC_SETUP_AUTH}"; then
  echo "Adding user for Airflow Web UI RBAC login..."
  # Both RBAC set-up and `create_user` is only available together from v1.10.11 onwards.
  if [ "${AIRFLOW_X_VERSION}" -eq "1" ] && [ "${AIRFLOW_Y_VERSION}" -ge "10" ]; then
    gosu "${AIRFLOW_USER}" airflow create_user \
         -r "${AIRFLOW_WEBSERVER_RBAC_ROLE}" \
         -u "${AIRFLOW_WEBSERVER_RBAC_USER}" \
         -p "${AIRFLOW_WEBSERVER_RBAC_PASSWORD}" \
         -e "${AIRFLOW_WEBSERVER_RBAC_EMAIL}" \
         -f "${AIRFLOW_WEBSERVER_RBAC_FIRST_NAME}" \
         -l "${AIRFLOW_WEBSERVER_RBAC_LAST_NAME}"
  # RBAC UI is the only option available from v2 onwards.
  elif [ "${AIRFLOW_X_VERSION}" -ge "2" ]; then
    gosu "${AIRFLOW_USER}" airflow users create \
         -r "${AIRFLOW_WEBSERVER_RBAC_ROLE}" \
         -u "${AIRFLOW_WEBSERVER_RBAC_USER}" \
         -p "${AIRFLOW_WEBSERVER_RBAC_PASSWORD}" \
         -e "${AIRFLOW_WEBSERVER_RBAC_EMAIL}" \
         -f "${AIRFLOW_WEBSERVER_RBAC_FIRST_NAME}" \
         -l "${AIRFLOW_WEBSERVER_RBAC_LAST_NAME}"
  fi
  echo "User "${AIRFLOW_WEBSERVER_RBAC_USER}" of role "${AIRFLOW_WEBSERVER_RBAC_ROLE}" added!"
fi

# This "early returns" so that it gives bash-like effect if more control is required over the
# default Airflow scheduler + webserver start
if [ "$#" -ne 0 ]; then
  exec tini -- gosu "${AIRFLOW_USER}" "$@"
fi

# Start webserver as background process first
if check_set "${ENABLE_AIRFLOW_WEBSERVER_LOG}"; then
  echo "Starting webserver with logging..."
  gosu "${AIRFLOW_USER}" airflow webserver &
else
  echo "Starting webserver without logging..."
  gosu "${AIRFLOW_USER}" airflow webserver >/dev/null &
fi

# Then start scheduler as foreground
echo "Starting scheduler..."
exec tini -- gosu "${AIRFLOW_USER}" airflow scheduler

"""
Setup password authentication for Airflow Admin UI
"""

import argparse
import os
from typing import Optional

from airflow import models, settings
from airflow.contrib.auth.backends.password_auth import PasswordUser
from sqlalchemy.exc import IntegrityError

AIRFLOW_WEBSERVER_USER_ENV_VAR = "AIRFLOW_WEBSERVER_USER"
AIRFLOW_WEBSERVER_EMAIL_ENV_VAR = "AIRFLOW_WEBSERVER_EMAIL"
AIRFLOW_WEBSERVER_PASSWORD_ENV_VAR = "AIRFLOW_WEBSERVER_PASSWORD"

def add_user(username: Optional[str] = None,
             email: Optional[str] = None,
             password: Optional[str] = None) -> None:
    """
    Create the admin user. If user already exists, the process will ignore the error.
    :param username: airflow admin ui's username
    :param email: email of admin
    :param password: admin's password
    """
    user = PasswordUser(models.User())
    user.username = username if username else os.environ[AIRFLOW_WEBSERVER_USER_ENV_VAR]
    user.email = email if email else os.environ[AIRFLOW_WEBSERVER_EMAIL_ENV_VAR]
    user.password = password if password else os.environ[AIRFLOW_WEBSERVER_PASSWORD_ENV_VAR]

    session = settings.Session()

    try:
        session.add(user)
        session.commit()
    except IntegrityError as error_object:
        print(error_object)
    finally:
        session.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Set up Airflow Web UI authentication.")
    parser.add_argument(
        "-u", "--user",
        dest="user",
        help="Airflow Web UI Airflow admin user, can also use env var {}" \
            .format(AIRFLOW_WEBSERVER_USER_ENV_VAR))
    parser.add_argument(
        "-e", "--email",
        dest="email",
        help="Email of admin user, can also use env var {}" \
            .format(AIRFLOW_WEBSERVER_EMAIL_ENV_VAR))
    parser.add_argument(
        "-p", "--password",
        dest="password",
        help="Password of admin user, can also use env var {}" \
            .format(AIRFLOW_WEBSERVER_PASSWORD_ENV_VAR))
    args = parser.parse_args()

    add_user(username=args.user, email=args.email, password=args.password)

"""Setup password authentication for Airflow Admin UI
"""

import os
from sqlalchemy.exc import IntegrityError
from airflow import models, settings
from airflow.contrib.auth.backends.password_auth import PasswordUser


def add_user(username=os.environ['AIRFLOW_USER'],
             email=os.environ['AIRFLOW_EMAIL'],
             password=os.environ['AIRFLOW_PASSWORD']):
    """Create the admin user
    :param username: airflow admin ui's username
    :param email: email of admin
    :param password: admin's password
    :return: None
    """
    user = PasswordUser(models.User())
    user.username = username
    user.email = email
    user.password = password

    session = settings.Session()

    try:
        session.add(user)
        session.commit()
    except IntegrityError as error_object:
        print(error_object)
    finally:
        session.close()

if __name__ == "__main__":
    add_user()

"""
Setup password authentication for Airflow Admin UI
"""

import argparse
import os
from typing import Optional

from airflow.configuration import conf
import sqlalchemy
import sys
import time

DB_MAX_ATTEMPTS = 10
DB_RETRY_DELAY_SEC = 2

def test_db_conn(conn_str: str,
                 max_attempts: int,
                 retry_delay_sec: int) -> bool:
    """
    Test the database connection given a SQLAlchemy connection string.
    :param max_attempts: max number of attempts to test database connection
    :param retry_delay_sec: retry delay in seconds between each test connection attempt
    """
    engine = sqlalchemy.create_engine(conn_str)

    for c in range(max_attempts):
        try:
            conn = engine.connect()
            conn.close()
            return True
        except Exception as e:
            print(e, file=sys.stderr)
            print('Failed database connection attempt ({}/{})' \
                .format(c + 1, max_attempts), file=sys.stderr)
            time.sleep(retry_delay_sec)

    return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Perform Airflow database test connection.")
    parser.add_argument(
        "-c", "--conn-str",
        dest="conn_str",
        help="SQLAlchemy connection string, can also use Airflow core sql_alchemy_conn setting")
    parser.add_argument(
        "--max-attempts",
        dest="max_attempts",
        help="Max number of attempts to test database connection")
    parser.add_argument(
        "--retry-delay-sec",
        dest="retry_delay_sec",
        help="Retry delay in seconds between each test connection attempt")
    args = parser.parse_args()

    # Set default values
    conn_str = args.conn_str if args.conn_str else conf.get('core', 'sql_alchemy_conn')
    max_attempts = args.max_attempts if args.max_attempts else DB_MAX_ATTEMPTS
    retry_delay_sec = args.retry_delay_sec if args.retry_delay_sec else DB_RETRY_DELAY_SEC

    conn_ok = test_db_conn(
        conn_str=conn_str,
        max_attempts=max_attempts,
        retry_delay_sec=retry_delay_sec)

    if not conn_ok:
        print('Unable to connect to "{}"'.format(conn_str))
        sys.exit(1)

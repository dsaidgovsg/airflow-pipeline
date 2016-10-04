# coding=utf-8
"""

Parse URL connection string into its useful components

"""
import os

from future.moves.urllib.parse import urlparse


def __split_db_and_table_path(path):
    """Splits URL path to parts"""
    allparts = []
    while True:
        parts = os.path.split(path)
        if parts[0] == path:  # sentinel for absolute paths
            if parts[0] != '/':
                allparts.insert(0, parts[0])
            break
        elif parts[1] == path:  # sentinel for relative paths

            allparts.insert(0, parts[1])
            break
        else:
            path = parts[0]
            allparts.insert(0, parts[1])
    return allparts


def decode_url_connection_string(conn_str):
    """URL connection string into more useful parts"""
    parse_result = urlparse(conn_str)

    try:
        decoded = dict()
        decoded['scheme'] = parse_result.scheme
        decoded['username'] = parse_result.username
        decoded['password'] = parse_result.password
        decoded['hostname'] = parse_result.hostname
        decoded['port'] = parse_result.port
        decoded['database'] = __split_db_and_table_path(parse_result.path)[0]
        # decoded['table'] = __split_db_and_table_path(parse_result.path)[1]

        if any(v in {None, ''} for k, v in decoded.items()):
            return None
    except IndexError:
        return None

    return decoded


def decode_simple_url_conn_string(conn_str):
    """URL connection string into more useful parts"""
    parse_result = urlparse(conn_str)

    try:
        decoded = dict()
        decoded['scheme'] = parse_result.scheme
        decoded['hostname'] = parse_result.hostname
        decoded['port'] = parse_result.port
        decoded['path'] = parse_result.path

        if any(v in {None, ''} and (k in ('scheme', 'hostname', 'path'))
               for k, v in decoded.items()):
            return None
    except IndexError:
        return None

    return decoded


def encode_db_connstr(name,  # pylint: disable=too-many-arguments
                      host='127.0.0.1',
                      port=5432,
                      user='postgres',
                      password='password',
                      scheme='postgresql'):
    """ builds a database connection string """
    conn_str = (
        str(scheme) + '://' +
        str(user) + ':' +
        str(password) + '@' +
        str(host) + ':' +
        str(port) + '/' +
        str(name)
    )

    return conn_str

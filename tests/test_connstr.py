# coding=utf-8
"""
Unit testing of connstr module
"""
from fncore.utils.connstr import decode_simple_url_conn_string
from fncore.utils.connstr import decode_url_connection_string
from fncore.utils.connstr import encode_db_connstr


def test_decode_connection_string(dummy_graph_spec):
    """Unit test connstr.py module for decoding of correct conn. string"""
    connection_string = dummy_graph_spec['connection']
    split_conn_str = decode_url_connection_string(connection_string)
    assert split_conn_str['scheme'] == 'mssql'
    assert split_conn_str['username'] == 'admin'
    assert split_conn_str['password'] == 'P@ssw0rd'
    assert split_conn_str['hostname'] == '10.2.105.80'
    assert split_conn_str['port'] == 1433
    assert split_conn_str['database'] == 'test_url'


def test_decode_connection_string_2():
    """Unit test connstr.py module for decoding containing '@' in password"""
    split_conn_str = decode_url_connection_string('sqlserver://'
                                                  'sa:Passwor@@@123@@'
                                                  'localhost:1433/'
                                                  'acra_dump')
    assert split_conn_str['scheme'] == 'sqlserver'
    assert split_conn_str['username'] == 'sa'
    assert split_conn_str['password'] == 'Passwor@@@123@'
    assert split_conn_str['hostname'] == 'localhost'
    assert split_conn_str['port'] == 1433
    assert split_conn_str['database'] == 'acra_dump'


def test_decode_connection_string_3():
    """Unit test connstr.py module for decoding of incorrect string"""
    split_conn_str = decode_url_connection_string('mysql://test_db')
    assert split_conn_str is None


def test_decode_simple_conn_string():
    """Unit test connstr.py module for decoding simple URL"""
    hdfs_url_path = 'hdfs://fn01:8020/datasets/finnet'
    split_conn_str = decode_simple_url_conn_string(hdfs_url_path)
    assert split_conn_str['scheme'] == 'hdfs'
    assert split_conn_str['hostname'] == 'fn01'
    assert split_conn_str['port'] == 8020
    assert split_conn_str['path'] == '/datasets/finnet'


def test_decode_simple_conn_string_b():
    """Unit test connstr.py module for decoding simple URL"""
    hdfs_url_path = 'hdfs://gaproduce0/datasets/finnet'
    split_conn_str = decode_simple_url_conn_string(hdfs_url_path)
    assert split_conn_str['scheme'] == 'hdfs'
    assert split_conn_str['hostname'] == 'gaproduce0'
    assert split_conn_str['path'] == '/datasets/finnet'


def test_decode_simple_conn_string_c():
    """Unit test connstr.py module for decoding simple URL"""
    hdfs_url_path = 'hdfs://gaproduce0/'
    split_conn_str = decode_simple_url_conn_string(hdfs_url_path)
    assert split_conn_str['scheme'] == 'hdfs'
    assert split_conn_str['hostname'] == 'gaproduce0'
    assert split_conn_str['path'] == '/'


def test_encode_db_connstr():
    """ Unit test constr.py module for encoding db connection string """
    provide_only_db_name = encode_db_connstr('my_database')
    assert provide_only_db_name == (
        'postgresql://postgres:password@127.0.0.1:5432/my_database')

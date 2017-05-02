# coding=utf-8
"""

Spark context manager

"""
# pylint: disable=import-error
import os
import uuid
from contextlib import contextmanager
from pyspark import SparkContext
from pyspark import SparkConf


@contextmanager
def get_spark_context(conf):
    """Get the spark context for submitting pyspark applications"""
    spark_context = None
    try:
        spark_context = SparkContext(conf=conf)

        from fncore.utils.zip_py_module import zip_py

        import fncore
        spark_context.addPyFile(zip_py(os.path.dirname(fncore.__file__)))
        import py2neo
        spark_context.addPyFile(zip_py(os.path.dirname(py2neo.__file__)))

        yield spark_context
    except:
        raise
    finally:
        if spark_context:
            spark_context.stop()


def set_spark_defaults(conf, name='spark-job'):
    """
    Update the configuration dictionary for setting up spark, creating the
    dictionary if does not exist yet
    """
    if not conf:
        conf = dict()

    home = os.path.join('/tmp', str(uuid.uuid4()))
    conf['SparkConfiguration'] = SparkConf()\
        .setMaster('yarn-client')\
        .setAppName(name)\
        .set("spark.sql.shuffle.partitions", "1000")\
        .set("spark.scheduler.revive.interval", "3")\
        .set("spark.task.maxFailures", "0")\
        .set("spark.executorEnv.HOME", home)

    return conf

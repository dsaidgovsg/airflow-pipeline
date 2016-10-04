"""
Pre install the required packages used in Spark
"""
# pylint: disable=import-error, invalid-name
from pyspark import SparkContext

spark_ctx = SparkContext()
spark_ctx.stop()

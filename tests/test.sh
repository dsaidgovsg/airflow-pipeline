#!/bin/bash
set -euo pipefail

which airflow
which gosu


cat <<EOF >/tmp/testscript.scala
try {
    require { sc.parallelize(0 until 1000).reduce(_ + _) == (500 * 999) }
    System.exit(0)
} catch {
    case _: Throwable => System.exit(1)
}

EOF


$SPARK_HOME/bin/spark-shell --master local[2] -i /tmp/testscript.scala


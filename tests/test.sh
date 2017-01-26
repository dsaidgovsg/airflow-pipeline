#!/bin/bash
set -euo pipefail

mkdir -p tmp

echo "Running python tests"
export PYTHONPATH=dags/
py.test tests/

set +e
echo "Running python linting"
pylint --rcfile=tests/.pylintrc -f parseable `find dags -iname "*.py" | grep -v "node_modules/"` | tee tmp/pylint.txt

pushd $SPARK_HOME
./bin/spark-submit examples/src/main/python/pi.py 1000
popd

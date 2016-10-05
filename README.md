# airflow-pipeline

An [Airflow](https://airflow.incubator.apache.org/) setup that aims to work well with Hadoop and Spark


## Docker image

You might have to `docker login` first before you can build any images.

To change the environment variables, edit `docker-compose.yml` instead of `Dockerfile` without the need to rebuild the docker image.

To bring the containers up for development, use `docker-compose up --build -d`. The `docker-compose.override.yml` file will create a volume at `./airflow/dags` and mounted in the container at `/airflow/dags`, allowing you to do edit the DAG files directly on your development machine and having them updated with the container immediately.

To deploy, use only the `docker-compose.yml` file i.e. `docker-compose -p afp -f docker-compose.yml up --build -d`


## Environment dependencies for deployment (in Docker images)

This docker image depends on [`datagovsg/python-spark-airflow:1.7`](https://hub.docker.com/r/datagovsg/python-spark-airflow/) image which depends on [`datagovsg/python-spark:2.7-1.6.1`](https://hub.docker.com/r/datagovsg/python-spark/). See their respective docker files to know where the dependencies are loaded.

- Python 2.7
- Spark 1.6.1
- Hadoop 2.6.1
- Sqoop 1.4.6
- PostgreSQL, MySQL and MS SQL JDBC connectors
- PostgreSQL 9.5
- Airflow 1.7


## Hadoop configuration

#### Hadoop user and group

Since the docker user is `afpuser` and group is `afpgroup`, see [Dockerfile](Dockerfile). Therefore, your Hadoop admin should also add the same user and group to your hadoop cluster. Also grant HDFS permissions on `PIPELINE_DATA_PATH` e.g. /dataset/afpgroup

#### Hadoop client configuration files

Obtain from your Hadoop administrator and place in `./hadoop*` directory. Note the environment variables that might be overwritten. e.g. Overriding `HADOOP_MAPRED_HOME` in `hadoop-env.sh`


## Tests

To run tests, use `docker-compose -f docker-compose.test.yml up --build`


## Logs

To follow docker logs, use `docker-compose -f docker-compose.yml logs --tail=10 -f`


## Accessing the docker container
1. Ensure that container is deployed on your server
2. SSH into server
3. Access the container's bash shell: `docker exec -ti afp_airflow_1 bash`
4. Change user to afpuser: `gosu afpuser bash`

#### To backfill DAGs
- Run the airflow backfill: `airflow backfill -s <YYYY-MM-DD> -e <YYYY-MM-DD> <dag_name>`

#### Manually execute a DAG
- Run the airflow DAG: `airflow trigger_dag <dag_name>`

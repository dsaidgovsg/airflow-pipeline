# airflow-pipeline [![Build Status](https://travis-ci.org/datagovsg/airflow-pipeline.svg?branch=)](https://travis-ci.org/datagovsg/airflow-pipeline) [![Docker pulls](https://img.shields.io/docker/pulls/datagovsg/airflow-pipeline.svg)](https://hub.docker.com/r/datagovsg/airflow-pipeline/)

An [Airflow](https://airflow.incubator.apache.org/) setup that aims to work well with Hadoop and Spark. This is a base image that should be derived further by individual projects as needed. Unless the defaults are sufficient, derivative images would have to set the necessary configurations (see below).


## What this gives you

This image is based off the [`python-spark`](https://github.com/datagovsg/python-spark) image and contains standard Python, Hadoop and Spark installations.

- <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Python-logo-notext.svg/240px-Python-logo-notext.svg.png" height="20"> Python 2.7
- <img src="https://airflow.incubator.apache.org/_images/pin_large.png" height="20"> Airflow 1.10 (with PostgreSQL 9.6)
- <img src="http://spark.apache.org/images/spark-logo-trademark.png" height="24"> Spark 1.6 and 2.1
- <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/0/0e/Hadoop_logo.svg/320px-Hadoop_logo.svg.png" height="20"> Hadoop 2.6
- <img src="https://upload.wikimedia.org/wikipedia/commons/b/b4/Apache_Sqoop_logo.svg" height="16"> Sqoop 1.4.6 (with JDBC connectors for PostgreSQL, MySQL and SQL Server)


# Configuration for derivative images

The following instructions refer to configuring the Compose files of derivative images. It is assumed that the Dockerfile the Compose files are using is based on this image.
The repository contains example Compose files for reference.

## Authentication

Password authentication is enabled as a security mechanism for administering Airflow via its admin UI.

Set `AIRFLOW_USER`, `AIRFLOW_EMAIL` and `AIRFLOW_PASSWORD` under `webserver` service in the docker compose file before starting the container.

Every time the airflow web server starts, it will create the user if it does not exist.

## Airflow DAGs

Place the airflow DAGs in ./dags which will be copied into the image

## Hadoop configuration

#### Hadoop user and group

The default docker user is 'afpuser' and group is 'hadoop'. Subsequent images that bases on this image can change the user by specifying docker env vars for 'USER' and 'GROUP' respectively. For example, the Compose file that is based on this image would look something like this:

```
  scheduler:
    environment:
      USER: someuser
      GROUP: somegroup
    command: ["some-scheduler"]
    ...
```

Based on the specified docker user and group, see [Dockerfile](Dockerfile). Therefore, your Hadoop admin should also add the same user and group to your hadoop cluster. Also grant the necessary HDFS directory/file permissions.

#### Hadoop client configuration files

To write to HDFS and connect to the YARN ResourceManager, the (client side) configuration files for Hadoop, Yarn and Hive must be added. Unlike previous versions of this image, the Hadoop configuration files has to be included when building this or any derivative images as they will be copied into the image.

**In your derivative images, you should copy these configuration files and set the environment variables `HADOOP_CONF_DIR`, `HIVE_CONF_DIR` and `YARN_CONF_DIR` appropriately.**

The configuration contained in this directory will be distributed to the YARN cluster so that all containers used by the application use the same configuration.

See also http://spark.apache.org/docs/latest/running-on-yarn.html

# Deploy on Amazon EMR cluster

The Airflow scheduler and webserver containers can be deployed on an Amazon EMR cluster in the master node. Docker engine and Docker compose has to be installed on the EMR master instance either by preparing a custom AMI or using bootstrap actions. The building of the custom AMI, secrets management and encryption are beyond the scope of this README. Regardless, consider provisioning an EMR cluster quickly using [Terraform](https://www.terraform.io/) and the [terraform-aws-emr-cluster module](https://github.com/chrissng/terraform-aws-emr-cluster)

To start the Airflow containers in the master instance,
```bash
sudo /usr/local/bin/docker-compose -f docker-compose.emr.yml up -d
```

Logging to S3 bucket is enabled by the following lines in [`docker-compose.emr.yml`](./docker-compose.emr.yml):

```yml
AIRFLOW__CORE__TASK_LOG_READER: s3.task
AIRFLOW__CORE__LOGGING_CONFIG_CLASS: s3_log_config.LOGGING_CONFIG
S3_LOG_FOLDER: s3://fixme/
```

To disable S3 logging, simply comment out the above three lines of configuration.

Airflow webserver runs at port 8888 as port 8080 is used by Tomcat (Apache Tez).

*Tested on Amazon EMR 5.*

# Deployment using Docker

## Docker image

You might have to `docker login` first before you can build any images.

To change the environment variables, edit `docker-compose.yml` instead of
`Dockerfile` without the need to rebuild the docker image.

### Local Airflow

To start, use only the `docker-compose.yml` file i.e. `docker-compose -p afp -f docker-compose.yml up --build -d`

To start with Macvlan networking mode, use only the `docker-compose.macvlan.yml` file i.e. `docker-compose -p afp -f docker-compose.macvlan.yml up --build -d`

#### Setup macvlan
Make sure that the containers also have name resolution configured so it can communicate with resources on the network. (e.g. `extra_hosts`, `dns` and `dns_search` configurations in Compose)
```bash
docker network create -d macvlan --subnet=192.168.150.0/24 --ip-range=192.168.150.48/28 -o parent=p2p1 afpnet
```

### Distributed Airflow

To start distributed Airflow (using Celery), `docker-compose -f docker-compose.yml -f docker-compose.celeryexecutor.yml up --scale worker=3 -d` with three Airflow workers.

To bring the containers up for development, use also the `docker-compose.override.yml`. This will additionally create a volume at `./dags` and mounted in the container at `/airflow/dags`, allowing you to do edit the DAG files directly on your development machine and having them updated with the container immediately.


## Deploying into production

Since credentials are managed as environment variables, it is recommended that your env file or `docker-compose.production.yml` be stored securely. Do not commit them to any source code repositories.

In the given `docker-compose.yml`, the environment variables used to store credentials are placeholders only.


## Tests

To run tests, use `docker-compose -f tests/docker-compose.test.yml up --build`


## Logs

To follow docker logs, use `docker-compose -p afp -f docker-compose.yml logs --tail=10 -f`


## Accessing the docker container
1. Ensure that container is deployed on your server
2. SSH into server
3. Access the container's bash shell: `docker exec -ti afp_airflow_1 bash`
4. Change user to afpuser: `gosu afpuser bash`

#### To backfill DAGs
- Run the airflow backfill: `airflow backfill -s <YYYY-MM-DD> -e <YYYY-MM-DD> <dag_name>`

#### Manually execute a DAG
- Run the airflow DAG: `airflow trigger_dag <dag_name>`

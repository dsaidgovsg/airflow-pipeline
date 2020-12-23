# Airflow Pipeline Docker Image Set-up

![CI Status](https://img.shields.io/github/workflow/status/dsaidgovsg/airflow-pipeline/CI/master?label=CI&logo=github&style=for-the-badge)

This repo is a GitHub Actions build matrix set-up to generate Docker images of
[Airflow](https://airflow.incubator.apache.org/), and other major applications
as below:

- Airflow
- Spark
- Hadoop integration with Spark
- Python
- SQL Alchemy

Note that this repo is actually a fork of
<https://github.com/dsaidgovsg/airflow-pipeline>, but has been heavily revamped
in order to do build matrix to generate Docker images with varying application
versions.

Additionally, `poetry` is used to perform all Python related installations at a
predefined global project directory, so that it is easy to add on new packages
without conflicting dependency package versions, which raw `pip` cannot achieve.
See
<https://github.com/dsaidgovsg/spark-k8s-addons#how-to-properly-manage-pip-packages>
for more information.

Also, for convenience, the current version runs both the `webserver` and
`scheduler` together in the same instance by the default entrypoint, with the
`webserver` being at the background and `scheduler` at the foreground. All the
convenient environment variables only works on the basis that the entrypoint is
used without any extra command.

If there is a preference to run the various Airflow CLI services separately,
you can simply pass the full command into the Docker command, but it will no
longer trigger any of the convenient environment variables / functionalities.

The above convenience functionalities include:

1. Discovering if database (`sqlite` and `postgres`) is ready
2. Automatically running `airflow initdb`
3. Easy creation of Airflow Web UI admin user by simple env vars.

Also note that the command that will be run will also be run as `airflow`
user/group, unless the host overrides the user/group to run the Docker
container.

## Commands to demo

You will need `docker-compose` and `docker` command installed.

### Default Combined Airflow Webserver and Scheduler

```bash
docker-compose up --build
```

Navigate to `http://localhost:8080/`, and log in using the following RBAC
credentials to try out the DAGs:

- Username: `admin`
- Password: `Password123`

Note that the `webserver` logs are suppressed by default.

`CTRL-C` to gracefully terminate the services.

### Separate Airflow Webserver and Scheduler

```bash
docker-compose -f docker-compose.split.yml up --build
```

Navigate to `http://localhost:8080/` to try out the DAGs.

Both `webserver` and `scheduler` logs are shown separately.

`CTRL-C` to gracefully terminate the services.

## Versioning

Starting from Docker tags that give self-version `v1`, any Docker image usage
related breaking change will generate a new self-version so that this will
minimize any impact on the user-facing side trying to use the most updated
image.

These are considered breaking changes:

- Change of Linux distro, e.g. Alpine <-> Debian. This will automatically lead
  to a difference in the package management tool used such as `apk` vs `apt`.
  Note that however this does not include upgrading of Linux distro that may
  affect the package management, e.g. `alpine:3.9` vs `alpine:3.10`.
- Removal of advertized installed CLI tools that is not listed within the
  Docker tag. E.g. Spark and Hadoop are part of the Docker tag, so they are not
  part of the advertized CLI tools.
- Removal of advertized environment variables
- Change of any environment variable value

In the case where a CLI tool is known to perform a major version upgrade, this
set-up will try to also release a new self-version number. But note that this is
at a best effort scale only because most of the tools are inherited upstream,
or simply unable / undesirable to specify the version to install.

## Changelogs

All self-versioned change logs are listed in [`CHANGELOG.md`](CHANGELOG.md).

The advertized CLI tools and env vars are also listed in the detailed change
logs.

## How to Manually Build Docker Image

Example build command:

```bash
AIRFLOW_VERSION=1.10
SPARK_VERSION=3.0.0
HADOOP_VERSION=3.2.0
SCALA_VERSION=2.12
PYTHON_VERSION=3.6
SQLALCHEMY_VERSION=1.3
docker build -t airflow-pipeline \
  --build-arg "AIRFLOW_VERSION=${AIRFLOW_VERSION}" \
  --build-arg "SPARK_VERSION=${SPARK_VERSION}" \
  --build-arg "HADOOP_VERSION=${HADOOP_VERSION}" \
  --build-arg "SCALA_VERSION=${SCALA_VERSION}" \
  --build-arg "PYTHON_VERSION=${PYTHON_VERSION}" \
  --build-arg "SQLALCHEMY_VERSION=${SQLALCHEMY_VERSION}" \
  .
```

You may refer to the [vars.yml](templates/vars.yml) to have a sensing of all the
possible build arguments to combine.

## Entrypoint

## Additional Useful Perks

There is already an AWS S3 log configuration file in this set-up.

If you wish to save the Airflow logs into S3 bucket instead, provide the
following environment variables when launcher the Docker container:

```yml
AIRFLOW__CORE__TASK_LOG_READER: s3.task
AIRFLOW__CORE__LOGGING_CONFIG_CLASS: s3_log_config.LOGGING_CONFIG
S3_LOG_FOLDER: s3://yourbucket/path/to/your/dir
```

## Caveat

Because this image is based on Spark with Kubernetes compatible image, which
always generates Debian based Docker images, the images generated from this
repository are likely to stay Debian based as well. But note that there is no
guarantee that this is always true, but such changes are always marked with
Docker image release tag.

Also, currently the default entrypoint without command logic assumes that
a Postgres server will always be used (the default `sqlite` can work as an
alternative). As such, when using in this mode, an external Postgres server
has to be made available for Airflow services to access.

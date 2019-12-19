# Airflow Pipeline Docker Image Set-up

![CI Status](https://img.shields.io/github/workflow/status/guangie88/airflow-pipeline/CI/master?label=CI&logo=github&style=for-the-badge)

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

Additionally, Conda and specialized environment are being used to perform all
Python related installations, so that it is easy to generate images with
specific Python versions without conflicting dependency package versions.

The entrypoint of this repository is heavily specialized to give the following
effects:

- (Airflow) If the first command/arg is `afp-scheduler` or `afp-webserver`, the
  entrypoint will run Airflow service, and you may need to provide additional
  environment variables to run the service properly.

  It is recommended that you run `docker-compose up --build` instead to run the
  orchestration of services that involve both the above services.

- (Bash-like)
    1. If no command/arg is passed in, it will just run a `bash` interactive
       shell as `root` user.

       E.g. `docker run --rm -it airflow-pipeline` -> (bash interactive)

    2. If the first command/arg is `gosu-run`, it will run the **remaining**
       arguments like this: `gosu ${USER} $@`, where `$@` are the rest of the
       arguments.

       E.g. `docker run --rm -it airflow-pipeline gosu-run whoami` -> `afpuser`

    3. If the first command/arg is neither `afp-scheduler` nor `afp-webserver`,
       it will simply run the command and arguments as it is as `root` user,
       with no presumption of running under `bash`.

       E.g. `docker run --rm -it airflow-pipeline whoami` -> `root`
       E.g. `docker run --rm -it airflow-pipeline echo Hello` -> `Hello`

Note that the specialized Conda environment is activated in all Bash-like
scenarios, regardless of whether `gosu` was used to run as a different user.

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

## How to build

```bash
AIRFLOW_VERSION=1.9
SPARK_VERSION=2.4.4
HADOOP_VERSION=3.1.0
PYTHON_VERSION=3.6
SQLALCHEMY_VERSION=1.1
docker build -t airflow-pipeline \
  --build-arg "AIRFLOW_VERSION=${AIRFLOW_VERSION}" \
  --build-arg "SPARK_VERSION=${SPARK_VERSION}" \
  --build-arg "HADOOP_VERSION=${HADOOP_VERSION}" \
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
always generates Alpine based Docker images, the images generated from this
repository are likely to stay Alpine based as well.

However, note that there is no guarantee that this is always true, and any GNU
tool can break due to discrepancy between Alpine and other distributions such as
Debian.

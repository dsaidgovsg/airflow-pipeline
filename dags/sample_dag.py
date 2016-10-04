# coding=utf-8
"""

A sample Airflow DAG

"""
# pylint: disable=import-error
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators import BashOperator

# pylint: disable=invalid-name
pipeline_args = {
    'owner': 'pipeliner',
    'depends_on_past': False,
    'start_date': datetime(2016, 10, 1),
    'email': ['pipeliner@data.gov.sg'],
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=1)
}

dag_id = 'pipeline_sample_dag'

dag = DAG(dag_id,
          default_args=pipeline_args,
          schedule_interval='0 0 * * 6')

globals()[dag_id] = dag

# Create sample task operators

task_1 = BashOperator(
    task_id='print_date',
    bash_command='date',
    dag=dag)

task_2 = BashOperator(
    task_id='sleep',
    bash_command='sleep 60',
    retries=3,
    dag=dag)

task_3 = BashOperator(
    task_id='print_date_again',
    bash_command='date',
    dag=dag)

task_2.set_upstream(task_1)
task_3.set_upstream(task_2)

####################################################################################
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
####################################################################################

# Author:  Adam Paternostro
# Summary: Shows some sample task groups along with an SLA miss 

import datetime
import airflow
from airflow.utils import trigger_rule
from airflow.operators.dummy_operator import DummyOperator
from airflow.operators.bash_operator import BashOperator
from airflow.utils.task_group import TaskGroup


def print_sla_miss(dag, task_list, blocking_task_list, slas, blocking_tis):
    print ("######################################################")
    print ("SLA was missed on DAG {dag}")
    print ("SLA was missed by task id {blocking_task_list}")
    print ("######################################################")


default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email': [''],
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 0,
    'retry_delay': datetime.timedelta(minutes=5),
    'start_date': datetime.datetime(2017, 1, 1),
    'sla':datetime.timedelta(seconds=15)
}

dag = airflow.DAG(
    dag_id='sample-sla-miss-task-groups', 
    default_args=default_args, 
    schedule_interval=datetime.timedelta(minutes=15),
    catchup=False,
    sla_miss_callback=print_sla_miss,
    dagrun_timeout=datetime.timedelta(minutes=5)
)

with dag:
    import_data_operator = DummyOperator(task_id='import_data', retries=3)

    with TaskGroup('load_data') as load_data:
        load_data_raw = DummyOperator(task_id='load_data_raw', retries=3)        
        load_data_compressed = DummyOperator(task_id='load_data_compressed', retries=3)        

    with TaskGroup('load_lookup_tables') as load_lookup_tables_tasks:
        load_lookup_table_main = DummyOperator(task_id='load_lookup_table_main', retries=3)        
        load_lookup_table_etl = DummyOperator(task_id='load_lookup_table_etl', retries=3)        

    with TaskGroup('load_fact_tables') as load_fact_tables:
        load_fact_table_customer = DummyOperator(task_id='load_fact_table_customer', retries=3)        
        load_fact_table_invoice = DummyOperator(task_id='load_fact_table_invoice', retries=3)        

    clean_up = DummyOperator(task_id='clean_up', retries=3)

    sleep_operator = BashOperator(task_id='sleep', sla=datetime.timedelta(seconds=10), bash_command='sleep 15', retries=0)

    import_data_operator >> load_data >> [load_lookup_tables_tasks,load_fact_tables] >> clean_up >> sleep_operator
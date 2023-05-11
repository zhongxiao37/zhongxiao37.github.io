---
layout: default
title: 通过Airflow调度Sagemaker实现ML pipeline
date: 2023-04-03 14:22 +0800
categories: airflow sagemaker ml
---

Sagemaker有自己的pipeline，但是我很不喜欢，如果实现起来，就等于我在Airflow的DAG里面还要嵌套一个dag，查看日志等都不方便。不过我们可以把他们拍平，都放到Airflow里面来实现。

下面这段代码就是通过Airflow调度Athena和Sagemaker。


```python
# -*- coding: utf-8 -*-
import time
import airflow
from airflow import DAG
from airflow.operators.bash_operator import BashOperator
from airflow.operators.python_operator import PythonOperator
from datetime import timedelta 
# airflow sagemaker configuration
from sagemaker.workflow.airflow import processing_config 
from sagemaker.tensorflow import TensorFlowProcessor
from sagemaker.processing import ProcessingInput, ProcessingOutput
from sagemaker import get_execution_role
import sagemaker
import boto3
#-------------------------------------------------------------------------------
# these args will get passed on to each operator
# you can override them on a per-task basis during operator initialization
default_args = {
    'owner': 'xxxx',
    'depends_on_past': False,
    'start_date': airflow.utils.dates.days_ago(2),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}
#-------------------------------------------------------------------------------
# dag define
dag = DAG(
    'example_dag_all_v1_dag',
    default_args=default_args,
    description='DAG pipeline athena and sagemaker v1',
    schedule_interval=None,
    default_view='graph',
    tags=['sagemaker', 'manual']
    )
#-------------------------------------------------------------------------------
# first task print date
date_operator = BashOperator(
    task_id='date_task',
    bash_command='date',
    dag=dag)
#-------------------------------------------------------------------------------
# second task : athena query 
def athena_query_job():
    client = boto3.client('athena',region_name='us-east-1')
    response = client.start_query_execution(
        QueryString='select * from tbl;',
        QueryExecutionContext={
        'Database': 'default'
        },
        ResultConfiguration={
             'OutputLocation': 's3://your-bucket-name/athena-query-result/',
        },
        WorkGroup='primary'
     )
    print(response)
    execution_id=response['QueryExecutionId']
    wait_result=True
    while wait_result:
        response = client.get_query_execution(
          QueryExecutionId=execution_id
        )
        if response['QueryExecution']['Status']['State']=='SUCCEEDED':
           print(response)
           wait_result=False
        else:
           print('wait 1 second')
           time.sleep(1)
    return execution_id

athena_query_operator = PythonOperator(
    task_id='athena_query_job',
    python_callable=athena_query_job,
    dag=dag)
#-------------------------------------------------------------------------------
# third: task copy athena query to fixed name arpu_example.csv
def copy_query_result_job(**kwargs): 
    ti = kwargs['ti']
    execution_id = ti.xcom_pull(task_ids='athena_query_job')
    s3 = boto3.resource('s3')
    source= { 'Bucket' : 'your-bucket-name', 'Key': f'athena-query-result/{execution_id}.csv'}
    dest = s3.Bucket('your-bucket-name')
    dest.copy(source, 'starunion/arpu_example.csv')
    return f"copy s3://your-bucket-name/athena-query-result/{execution_id}.csv to s3://your-bucket-name/starunion/arpu_example.csv"

copy_query_result_operator = PythonOperator(
    task_id='copy_query_result_job',
    python_callable=copy_query_result_job,
    dag=dag) #-------------------------------------------------------------------------------
# fourth: task sagemaker process 
def sagemaker_process_job(**kwargs):
    sm_session = sagemaker.Session(boto3.session.Session(region_name='us-east-1'))
    iam = boto3.client('iam')
    sm_role = iam.get_role(RoleName='RoleName')['Role']['Arn']
    tp = TensorFlowProcessor(
        framework_version='1.15',
        role=sm_role,
        sagemaker_session=sm_session,
        instance_type='ml.c5.2xlarge',
        instance_count=1,
        base_job_name='frameworkprocessor-TF',
        py_version='py37'
    )
    tp.run(
        code='preprocessing.py', #脚本
        source_dir='s3://your-bucket-name/code/sourcedir.tar.gz',
        inputs=[
           ProcessingInput(
            source='s3://your-bucket-name/starunion/arpu_example.csv',
            destination='/opt/ml/processing/input'
           )
        ],
        outputs=[
           ProcessingOutput(
            source='/opt/ml/processing/output',
            destination='s3://your-bucket-name/starunion/'
           )
        ]
    )
    return "tp"
sagemaker_info_operator = PythonOperator(
    task_id='sagemaker_process_job',
    python_callable=sagemaker_process_job,
    dag=dag)
#-------------------------------------------------------------------------------
# dependencies
athena_query_operator.set_upstream(date_operator)
copy_query_result_operator.set_upstream(athena_query_operator)
sagemaker_info_operator.set_upstream(copy_query_result_operator)
```


## 通过配置文件来调度

上面的文件虽然可以用，但是没有集成训练任务，而且没有参数化。因此，我们可以配置一个config.json文件，作为DAG的默认参数，这样就可以通过Airflow的run with config来传入不同的超参，生成不同的训练模型。


```json
{
  "pipeline_name": "sagemaker-example",
  "bucket_name": "bucket_name",
  "artifacts_path": "ml-pipleline-artifacts",
  "sagemaker_role": "arn:xxx",
  "image": {
    "region": "cn-north-1",
    "framework": "xgboost",
    "version": "1.5-1"
  },
  "steps": {
    "data-source": {
      "columns": [
        "a",
        "b"
      ],
      "label_column": "label",
      "source_table": "datamart.table",
      "where_clause": "where timestamp between ''2020-01'' and ''2022-07''",
      "source_connection": "rds",
      "target_connection": "s3"
    },
    "splitor": {
      "instance_type": "ml.t3.large",
      "code_path": "code/preprocessing.py",
      "data_destination": "/opt/ml/processing/input/data-source",
      "config_path": "code/config.json",
      "config_destination": "/opt/ml/processing/input/config",
      "label_column": "label",
      "split_strategy": {
        "by": "timestamp",
        "datasets": {
          "train": {
            "range": { "start": "2020-01", "end": "2021-12" }
          },
          "test": { "equal": "2022-07" }
        }
      },
      "outputs": {
        "train": { "source": "/opt/ml/processing/train" },
        "test": { "source": "/opt/ml/processing/test" }
      }
    },
    "transformer": {},
    "feature-selection": {},
    "trainer": {}
  }
}

```

```python
# preprocessing.py
import pandas as pd
import os
import json

if __name__ == "__main__":

    with open(f'/opt/ml/processing/input/config/config.json', 'r') as f:
        config = json.load(f)

    step_config = config['steps']['splitor']

    model_df = pd.read_parquet(step_config['data_destination'])
    label = step_config['label_column']

    timestamp_column = step_config['split_strategy']['by']

    for dataset_name, dataset_v in step_config['split_strategy']['datasets'].items():
        if 'range' in dataset_v:
            feature_data = model_df[(model_df[timestamp_column]>=dataset_v['range']['start'])&(model_df[timestamp_column]<=dataset_v['range']['end'])]
        if 'equal' in dataset_v:
            feature_data = model_df[(model_df[timestamp_column]==dataset_v['equal'])]

        label_data = feature_data.pop(label)
        feature_data.pop(timestamp_column)
        contact_data = pd.concat([label_data, feature_data], axis=1)
        output_directory = step_config['outputs'][dataset_name]['source']
        output_path = os.path.join(output_directory, f'{dataset_name}.csv')

        pd.DataFrame(contact_data).to_csv(output_path, header=True, index=False)

```

### Airflow DAG

这个示例有两个步骤，一个是从数据库里面导出数据到S3，第二步是拆分数据集。后面可以继续追加其他的步骤，必须训练任务。

```python

file_path = pathlib.Path(__file__).parent.resolve()
with open(f'{file_path}/code/config.json', 'r') as f:
    default_params = json.load(f)

@task(task_id='data-source')
def data_source(**context):
    from airflow.providers.amazon.aws.transfers.redshift_to_s3 import RedshiftToS3Operator

    config = context['params']
    job_name = config['pipeline_name']
    step_name = 'data-source'

    step_config = config['steps'][step_name]
    select_columns = list(step_config['columns'])
    select_columns.append(step_config['label_column'])
    query = f"select {','.join(select_columns)} from {step_config['source_table']} {step_config['where_clause']}"

    job_dt = datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
    s3_bucket = config['bucket_name']
    job_s3_path = f"{config['artifacts_path']}/{job_name}-{job_dt}"
    s3_output_path = f'{job_s3_path}/{step_name}'

    redshift_to_s3_task = RedshiftToS3Operator(
      task_id='redshift_to_s3_operator',
      s3_bucket=s3_bucket,
      s3_key=f'{s3_output_path}/',
      redshift_conn_id=step_config['source_connection'],
      select_query=query,
      aws_conn_id=step_config['target_connection'],
      unload_options=[
          "FORMAT AS PARQUET"
      ]
    )

    redshift_to_s3_task.execute(dict())

    return {"job_s3_path": f"s3://{s3_bucket}/{job_s3_path}", "output_s3_path": f"s3://{s3_bucket}/{s3_output_path}"}


@task(task_id='splitor')
def splitor(s3_paths, **context):
    from sagemaker.processing import ScriptProcessor

    config = context['params']
    job_name = config['pipeline_name']
    step_name = 'splitor'
    step_config = config['steps'][step_name]

    data_source_s3_path = s3_paths['output_s3_path']
    job_s3_path = s3_paths['job_s3_path']

    s3_output_path = os.path.join(job_s3_path, step_name)
    processor = ScriptProcessor(
        image_uri=image_uri(config),
        command=["python3"],
        role=config['sagemaker_role'],
        sagemaker_session=sagemaker.Session(boto3.session.Session()),
        instance_type=step_config['instance_type'],
        instance_count=1,
        base_job_name=f'{job_name}-{step_name}'
    )

    inputs = [
        ProcessingInput(
            input_name='data-source',
            source=data_source_s3_path,
            destination=step_config['data_destination']
        ),
        ProcessingInput(
            input_name='config',
            source=os.path.join(file_path, step_config['config_path']),
            destination=step_config['config_destination']
        )
    ]

    outputs = []
    for output_name, output_source in step_config['outputs'].items():
        outputs.append(
            ProcessingOutput(
            output_name=output_name,
            source=output_source['source'],
            destination=f"{s3_output_path}/{output_name}",
            )
        )

    processor.run(
        code=os.path.join(file_path, step_config['code_path']),
        inputs=inputs,
        outputs=outputs
    )

    xcom_outputs = {'job_s3_path': job_s3_path}
    for output in processor.latest_job.outputs:
        xcom_outputs.update({output.output_name: output.destination})

    return xcom_outputs


args = {
    'owner': 'airflow',
    'start_date': airflow.utils.dates.days_ago(0),
    'params': default_params
}

with DAG(
    'sagemaker_example',
    schedule_interval='0 0 * * *',
    dagrun_timeout=timedelta(minutes=30),
    tags=['ml'],
    default_args=args,
    catchup=False) as dag:

    data_source_path = data_source()
    splited_data_set_paths = splitor(data_source_path)

```


### 本地起Sagemaker

将`sagemaker_session=sagemaker.Session(boto3.session.Session())`换成的`LocalSession`就可以了。



---
layout: default
title: great_expectation 自定义数据集
date: 2023-10-19 16:00 +0800
categories: great_expectations
---

Great Expectation 是针对数据的验证工具，基于 Python 的一个 package。

## 数据集

Great Expectation 支持 pandas dataframe， csv， sql，在 Great Expectation 里面叫做 Data Source。数据集可以在 great_expectations.yml 文件里面找到，即 gx 里面的 context。

用`InferredAssetSqlDataConnector`可以快速的针对一个表进行验证，用`RuntimeDataConnector`可以针对一段 SQL 的结果来执行验证。这里想要展示如何实现后者。

```yml
datasources:
  pg_datasource:
    module_name: great_expectations.datasource
    execution_engine:
      module_name: great_expectations.execution_engine
      credentials:
        host: 127.0.0.1
        port: 5432
        database: public
        drivername: postgresql
      class_name: SqlAlchemyExecutionEngine
    data_connectors:
      default_inferred_data_connector_name:
        include_schema_name: true
        name: default_inferred_data_connector_name
        module_name: great_expectations.datasource.data_connector
        class_name: InferredAssetSqlDataConnector
      default_runtime_data_connector_name:
        name: default_runtime_data_connector_name
        module_name: great_expectations.datasource.data_connector
        batch_identifiers:
          - default_identifier_name
        class_name: RuntimeDataConnector
    class_name: Datasource
```

## 测试用例

在 Great Exceptation 里面叫做 expectations，下面一个是例子。这个测试里面做了两个验证，一个非空验证，一个是值范围验证。

```json
{
  "data_asset_type": null,
  "expectation_suite_name": "public_cases_expectation_suite",
  "expectations": [
    {
      "expectation_type": "expect_column_values_to_not_be_null",
      "kwargs": {
        "column": "case_id"
      },
      "meta": {}
    },
    {
      "expectation_type": "expect_column_values_to_be_between",
      "kwargs": {
        "column": "status_details",
        "max_value": 15,
        "min_value": 0
      },
      "meta": {}
    }
  ],
  "ge_cloud_id": null,
  "meta": {
    "great_expectations_version": "0.16.14"
  }
}
```

## 验证点

把数据和测试绑定起来，就是 Checkpoint。在下面的例子中，我用了一个 query 去限定数据集，而不是整个表。

```yml
name: public_cases_checkpoint
config_version: 1.0
template_name:
module_name: great_expectations.checkpoint
class_name: Checkpoint
run_name_template: "%Y%m%d-%H%M%S_public_cases_postgresql"
expectation_suite_name:
batch_request: {}
action_list:
  - name: store_validation_result
    action:
      class_name: StoreValidationResultAction
  - name: store_evaluation_params
    action:
      class_name: StoreEvaluationParametersAction
  - name: update_data_docs
    action:
      class_name: UpdateDataDocsAction
      site_names: []
evaluation_parameters: {}
runtime_configuration: {}
validations:
  - batch_request:
      datasource_name: pg_datasource
      data_connector_name: default_runtime_data_connector_name
      data_asset_name: public.cases
      batch_identifiers:
        default_identifier_name: default_identifier_name
      runtime_parameters:
        query: SELECT * FROM public.cases LIMIT 10
    expectation_suite_name: public_cases_expectation_suite
profilers: []
ge_cloud_id:
expectation_suite_ge_cloud_id:
```

如果把`default_runtime_data_connector_name`切换成`default_inferred_data_connector_name`，就可以做整个表的验证。

```yml
validations:
  - batch_request:
      datasource_name: pg_datasource
      data_connector_name: default_inferred_data_connector_name
      data_asset_name: public.cases
    expectation_suite_name: public_cases_expectation_suite
```

## Airflow 中用 GreatExpectationsOperator 来自定义数据集

在 Airflow 中，事情会比较简单，你可以按照上面的定义好 Checkpoint 和 Expectation，再按照下面的例子做。

```python
base_path = Path(__file__).parents[0]
ge_root_dir = str(base_path / "great_expectations")

with DAG(
    'gx',
    start_date=datetime(2021, 12, 15),
    catchup=False,
    tags=['gx'],
    schedule_interval=None,
    concurrency=1,
    dagrun_timeout=timedelta(minutes=180),
    default_args={'owner': 'airflow', 'provide_context': True}
) as dag:

    GreatExpectationsOperator(
        task_id='gx_table',
        data_context_root_dir=ge_root_dir,
        return_json_dict=True,
        conn_id='local_pg',
        database='postgres',
        data_asset_name='data_asset_name',
        checkpoint_name='public_cases_checkpoint',
        expectation_suite_name='public_cases_expectation_suite',
        fail_task_on_validation_failure=False
    )

```

也可以通过`query_to_validation`加 Expectation 来验证，不需要传入 checkpoint，因为自动会创建 Checkpoint。

```python
GreatExpectationsOperator(
    task_id='gx_table',
    data_context_root_dir=ge_root_dir,
    return_json_dict=True,
    conn_id='local_pg',
    database='postgres',
    data_asset_name='data_asset_name',
    query_to_validate="SELECT * FROM public.test WHERE start_month > CURRENT_DATE",
    expectation_suite_name='public_cases_expectation_suite',
    fail_task_on_validation_failure=False
)
```

## GreatExpectationsOperator

### 如何创建 DataSource 和 BatchRequest

一旦传入了`query_to_validate`，那么就会创建一个 runtime datasource（credentials 是通过 Airflow 的 connection 生成的），验证的数据集就是这个 query 的返回结果，否则就是基于 connection 和 data_asset_name 的整个表。

```python
    def build_runtime_sql_datasource_batch_request(self):
        batch_request = {
            "datasource_name": f"{self.conn.conn_id}_runtime_sql_datasource",
            "data_connector_name": "default_runtime_data_connector",
            "data_asset_name": f"{self.data_asset_name}",
            "runtime_parameters": {"query": f"{self.query_to_validate}"},
            "batch_identifiers": {
                "query_string": f"{self.query_to_validate}",
                "airflow_run_id": "{{ task_instance_key_str }}",
            },
        }
        return RuntimeBatchRequest(**batch_request)


    def build_runtime_datasources(self):
        """Builds datasources at runtime based on Airflow connections or for use with a dataframe."""
        self.conn = BaseHook.get_connection(self.conn_id) if self.conn_id else None
        batch_request = None
        if self.is_dataframe:
            self.datasource = self.build_runtime_datasource()
            batch_request = self.build_runtime_datasource_batch_request()
        elif isinstance(self.conn, Connection):
            if self.query_to_validate:
                self.datasource = self.build_runtime_sql_datasource_config_from_conn_id()
                batch_request = self.build_runtime_sql_datasource_batch_request()
            elif self.conn:
                self.datasource = self.build_configured_sql_datasource_config_from_conn_id()
                batch_request = self.build_configured_sql_datasource_batch_request()
            else:
                raise ValueError("Unrecognized, or lack of, runtime query or Airflow connection passed.")
        if not self.checkpoint_kwargs:
            self.batch_request = batch_request
```

### 如何创建 Checkpoint

在 GreatExpectationsOperator 中，会判断是否传入了`checkpoint_name`，如果传入，就会去`checkpoints`目录下面去找对应的文件。
如果没有，就会创建一个默认的 Checkpoint，绑定传入的测试用例 expectation_suite_name。

```python
    def execute(self, context: "Context") -> Union[CheckpointResult, Dict[str, Any]]:
      """
        省略多余行数
      """
        self.log.info("Creating Checkpoint...")
        self.checkpoint: Checkpoint
        if self.checkpoint_name:
            self.checkpoint = self.data_context.get_checkpoint(name=self.checkpoint_name)
        elif self.checkpoint_config:
            self.checkpoint = instantiate_class_from_config(
                config=self.checkpoint_config,
                runtime_environment={"data_context": self.data_context},
                config_defaults={"module_name": "great_expectations.checkpoint"},
            )
        else:
            self.checkpoint_name = f"{self.data_asset_name}.{self.expectation_suite_name}.chk"
            self.checkpoint_config = self.build_default_checkpoint_config()
            self.checkpoint = instantiate_class_from_config(
                config=self.checkpoint_config,
                runtime_environment={"data_context": self.data_context},
                config_defaults={"module_name": "great_expectations.checkpoint"},
            )

    def build_default_checkpoint_config(self):
        """Builds a default checkpoint with default values."""
        self.run_name = self.run_name or f"{self.task_id}_{datetime.now().strftime('%Y-%m-%d::%H:%M:%S')}"
        checkpoint_config = CheckpointConfig(
            name=self.checkpoint_name,
            config_version=1.0,
            template_name=None,
            module_name="great_expectations.checkpoint",
            class_name="Checkpoint",
            run_name_template=self.run_name,
            expectation_suite_name=self.expectation_suite_name,
            batch_request=None,
            action_list=self.build_default_action_list(),
            evaluation_parameters={},
            runtime_configuration={},
            validations=None,
            profilers=[],
            ge_cloud_id=None,
            expectation_suite_ge_cloud_id=None,
        ).to_json_dict()
        filtered_config = deep_filter_properties_iterable(properties=checkpoint_config)

        return filtered_config
```

### 运行验证

有了 Checkpoint 和 BatchRequest, 就可以运行测试了。

```python
self.log.info("Running Checkpoint...")

if self.batch_request:
    result = self.checkpoint.run(batch_request=self.batch_request)
elif self.checkpoint_kwargs:
    result = self.checkpoint.run(**self.checkpoint_kwargs)
else:
    result = self.checkpoint.run()

```

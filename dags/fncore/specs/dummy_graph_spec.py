"""
This is a dummy specification for manual testing
"""
GRAPH_SPECIFICATION = {
    "graph_name": "company_registry",
    "node_lists": [
        {
            "uuid": "64748635-4fa4-4d99-ab01-fe16096198f2",
            "tags": [
                "company"
            ],
            "metadata_columns": [
                {
                    "variable_definition": "String",
                    "safe_column_name": "_NAME",
                    "column_name": "NAME"
                },
                {
                    "variable_definition": "Categorical",
                    "safe_column_name": "_STATUS",
                    "column_name": "STATUS"
                },
                {
                    "variable_definition": "Categorical",
                    "safe_column_name": "_SSIC",
                    "column_name": "SSIC"
                },
                {
                    "variable_definition": "Price",
                    "safe_column_name": "_SHARECAP",
                    "column_name": "SHARECAP"
                }
            ],
            "node_id_column": {
                "variable_definition": "String",
                "safe_column_name": "_UEN",
                "column_name": "UEN"
            },
            "safe_table_name": "_table_of_companies",
            "table_name": "table_of_companies"
        },
        {
            "uuid": "612768e1-564e-475c-a14b-55c2e97f804e",
            "tags": [
                "person"
            ],
            "metadata_columns": [
                {
                    "variable_definition": "String",
                    "resolution_alias": "name",
                    "safe_column_name": "_NAME",
                    "column_name": "NAME"
                }
            ],
            "node_id_column": {
                "variable_definition": "String",
                "safe_column_name": "_ID",
                "column_name": "ID"
            },
            "safe_table_name": "_table_of_officers",
            "table_name": "table_of_officers"
        }
    ],
    "edge_lists": [
        {
            "uuid": "76ab36dc-fcaa-451e-9bd5-4928614e4922",
            "tags": [],
            "target_column": {
                "safe_column_name": "_ID",
                "column_name": "ID"
            },
            "metadata_columns": [
                {
                    "variable_definition": "Categorical",
                    "safe_column_name": "_POSITION",
                    "column_name": "POSITION"
                },
                {
                    "variable_definition": "String",
                    "safe_column_name": "_APPOINTED_DATE",
                    "column_name": "APPOINTED_DATE"
                },
                {
                    "variable_definition": "String",
                    "safe_column_name": "_WITHDRAWAL_DATE",
                    "column_name": "WITHDRAWAL_DATE"
                }
            ],
            "safe_table_name": "_company_directorships",
            "source_column": {
                "safe_column_name": "_UEN",
                "column_name": "UEN"
            },
            "table_name": "company_directorships"
        }
    ],
    "connection": "mssql://admin:P@ssw0rd@10.2.105.80:1433/test_url",
    "poll_frequency": {
        "definition": "0 0 * * *",
        "name": "daily_0000"
    }
}

{# dbt doesn't like us ref'ing in an operation so we fetch the info from the graph #}

{% macro upload_results(results) -%}

    {% if execute %}

        {% set datasets_to_load = ['exposures', 'seeds', 'snapshots', 'invocations', 'sources', 'tests', 'models'] %}
        {% if results != [] %}
            {# When executing, and results are available, then upload the results #}
            {% set datasets_to_load = ['model_executions', 'seed_executions', 'test_executions', 'snapshot_executions'] + datasets_to_load %}
        {% endif %}

        {# Upload each data set in turn #}
        {% for dataset in datasets_to_load %}

            {# Get the results that need to be uploaded #}
            {% set objects = dbt_artifacts.get_dataset_content(dataset) %}

            {# Upload in chunks to reduce the query size #}
            {% if dataset == 'models' %}
                {% set upload_limit = var("dbt_artifacts_upload_limit", 10) %}
            {% else %}
                {% set upload_limit = var("dbt_artifacts_upload_limit", 10) * 6 %}
            {% endif %}

            {% do log("Uploading " ~ dataset.replace("_", " ") ~ " with " ~ objects | length ~ " objects, using batch size of " ~ upload_limit, true) %}

            {# Loop through each chunk in turn #}
            {% for i in range(0, objects | length, upload_limit) -%}

                {# Get just the objects to load on this loop #}
                {% set content = dbt_artifacts.get_table_content_values(dataset, objects[i: i + upload_limit]) %}

                {# Insert the content into the metadata table #}
                {{ dbt_artifacts.insert_into_metadata_table(
                    dataset=dataset,
                    fields=dbt_artifacts.get_column_name_list(dataset),
                    content=content
                    )
                }}

            {# Loop the next 'chunk' #}
            {% endfor %}

        {# Loop the next 'dataset' #}
        {% endfor %}

    {% endif %}

{%- endmacro %}

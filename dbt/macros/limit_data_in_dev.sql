{% macro limit_data_in_dev(column_name=none, dev_days=3, strategy='window', row_limit=1000, sample_id=none, sample_pct=10) %}
{# 
    Flexible development data filtering.
    Strategies:
      1. 'window' (default): Filters by a date window. Requires column_name.
      2. 'limit': Simple row count limit.
      3. 'sample': Deterministic hash sampling. Requires sample_id (e.g., user_id).
#}

{% if target.name in ['dev', 'local', 'default'] %}
    
    {% if strategy == 'window' %}
        where {{ column_name }} >= dateadd('day', -{{ dev_days }}, current_date)
    
    {% elif strategy == 'limit' %}
        limit {{ row_limit }}
    
    {% elif strategy == 'sample' %}
        {# Use hash-based sampling for consistent joins across models #}
        where mod(abs(strtol(left(md5({{ sample_id }}::text), 15), 16)), 100) < {{ sample_pct }}
    
    {% endif %}

{% endif %}
{% endmacro %}

#!/bin/bash
echo "Setting up Elasticsearch ingest pipeline..."
# Wait for Elasticsearch to be ready
until curl -s http://elasticsearch:9200 > /dev/null; do
    echo "Waiting for Elasticsearch..."
    sleep 5
done
# Create the ingest pipeline
curl -X PUT "http://elasticsearch:9200/_ingest/pipeline/unified-logspipeline" -H 'Content-Type: application/json' -d '
{
    "description": "Pipeline for enriching unified logs",
    "processors": [
        {
            "set": {
                "field": "unified_log.enriched",
                "value": true
            }
        },
        {
            "set": {
                "field": "unified_log.enriched_at",
                "value": "{{_ingest.timestamp}}"
            }
        },
        {
            "geoip": {
                "field": "source.ip",
                "target_field": "source.geo",
                "ignore_missing": true
            }
        },
        {
            "user_agent": {
                "field": "user_agent.original",
                "target_field": "user_agent",
                "ignore_missing": true
            }
        },
        {
            "script": {
                "source": "if (ctx.http != null && ctx.http.response != null && ctx.http.response.status_code != null) { int status = ctx.http.response.status_code; if (status >= 200 && status < 300) { ctx.http.response.status_category = \"success\"; } else if (status >= 300 && status < 400) { ctx.http.response.status_category = \"redirect\"; } else if (status >= 400 && status < 500) { ctx.http.response.status_category = \"client_error\"; } else if (status >= 500) { ctx.http.response.status_category = \"server_error\"; } }",
                "if": "ctx.http != null && ctx.http.response != null && ctx.http.response.status_code != null"
            }
        },
        {
            "set": {
                "field": "event.created",
                "value": "{{_ingest.timestamp}}",
                "override": false
            }
        }
    ]
}
'
# Create index template for unified logs
curl -X PUT "http://elasticsearch:9200/_index_template/unified-logstemplate" -H 'Content-Type: application/json' -d '
{
    "index_patterns": ["unified-logs-*"],
    "template": {
        "settings": {
            "number_of_shards": 1,
            "number_of_replicas": 0,
            "index.default_pipeline": "unified-logs-pipeline"
        },
        "mappings": {
            "properties": {
                "@timestamp": { "type": "date" },
                "source.ip": { "type": "ip" },
                "source.geo": {
                    "properties": {
                        "location": { "type": "geo_point" }
                    }
                },
                "http.response.status_code": { "type": "integer" },
                "http.response.status_category": { "type": "keyword" },
                "url.path": { "type": "keyword" },
                "url.original": { "type": "keyword" },
                "http.method": { "type": "keyword" },
                "unified_log.version": { "type": "keyword" },
                "unified_log.timestamp": { "type": "date" },
                "unified_log.processed_at": { "type": "date" },
                "unified_log.enriched": { "type": "boolean" },
                "unified_log.enriched_at": { "type": "date" }
            }
        }
    }
}
'
echo "Ingest pipeline and index template setup complete."

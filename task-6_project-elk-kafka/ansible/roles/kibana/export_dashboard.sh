#!/bin/bash

curl -X POST "http://kibana.tst.local:5601/api/saved_objects/_export" \
-H "kbn-xsrf: true" \
-H "Content-Type: application/json" \
-d '{
  "objects": [
    {
      "type": "dashboard",
      "id": "b66cee29-f09a-4abd-8998-0f55dcbe74af"
    }
  ],
  "includeReferencesDeep": true,
  "excludeExportDetails": false
}' -o dashboard_export.ndjson


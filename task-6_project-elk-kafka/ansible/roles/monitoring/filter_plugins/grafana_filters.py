def grafana_dashboard_payload(dashboard_json):
    return {
        "dashboard": dashboard_json,
        "folderId": 0,
        "overwrite": True
    }

class FilterModule(object):
    def filters(self):
        return {
            'grafana_dashboard_payload': grafana_dashboard_payload
        }


# SIEM Integration Guide

ContextFort generates structured JSON logs for enterprise SIEM integration.

## Log Files

### 1. Native Proxy Events
**Location:** `~/.contextfort/logs/native-proxy-events.jsonl`
**Format:** JSON Lines (one JSON object per line)
**Use:** Native messaging proxy activity, message forwarding

### 2. Chrome Session Events
**Location:** `~/.contextfort/logs/launch.log`
**Format:** Text logs
**Use:** Chrome browser launch/termination events

### 3. Kill Switch Events
**Location:** `~/.contextfort/logs/kill-switch.log`
**Format:** Text logs
**Use:** Remote session termination events

## Event Schema

### Native Proxy Events

All events include:
```json
{
  "timestamp": "2026-01-19T15:30:00.000Z",
  "event_type": "proxy_start|message_from_extension|chrome_launched|...",
  "proxy_session_id": "proxy-1705678200-12345",
  "proxy_pid": 12345
}
```

#### Event Types

**`proxy_start`** - Proxy started
```json
{
  "event_type": "proxy_start",
  "plugin_dir": "/path/to/plugin",
  "real_native_host": "/Applications/Claude.app/Contents/Helpers/chrome-native-host"
}
```

**`chrome_launched`** - ContextFort Chrome launched
```json
{
  "event_type": "chrome_launched",
  "chrome_pid": 23456,
  "launch_script": "/path/to/launch-chrome.sh"
}
```

**`message_from_extension`** - Message received from Chrome extension
```json
{
  "event_type": "message_from_extension",
  "message_id": 1,
  "message_type": "connect",
  "message_size": 234,
  "message_preview": "{\"type\":\"connect\",\"version\":\"1.0\"}"
}
```

**`message_forwarded_to_host`** - Message sent to real Claude host
```json
{
  "event_type": "message_forwarded_to_host",
  "message_id": 1
}
```

**`message_from_host`** - Message received from Claude host
```json
{
  "event_type": "message_from_host",
  "message_id": 1,
  "message_type": "response",
  "message_size": 456,
  "message_preview": "{\"type\":\"response\",\"status\":\"ok\"}"
}
```

**`message_forwarded_to_extension`** - Message sent to extension
```json
{
  "event_type": "message_forwarded_to_extension",
  "message_id": 1
}
```

**`proxy_shutdown`** - Proxy shutting down
```json
{
  "event_type": "proxy_shutdown",
  "signal": "SIGTERM"
}
```

**`fatal_error`** - Fatal error occurred
```json
{
  "event_type": "fatal_error",
  "error": "Connection refused",
  "stack": "Error: Connection refused\n  at ..."
}
```

## SIEM Integration Examples

### Splunk

#### 1. Configure Input
**inputs.conf:**
```ini
[monitor:///Users/*/. contextfort/logs/native-proxy-events.jsonl]
sourcetype = contextfort:native:proxy
index = security

[monitor:///Users/*/.contextfort/logs/launch.log]
sourcetype = contextfort:chrome:launch
index = security

[monitor:///Users/*/.contextfort/logs/kill-switch.log]
sourcetype = contextfort:killswitch
index = security
```

#### 2. Configure Props
**props.conf:**
```ini
[contextfort:native:proxy]
INDEXED_EXTRACTIONS = json
KV_MODE = json
TIME_PREFIX = "timestamp":"
TIME_FORMAT = %Y-%m-%dT%H:%M:%S.%3QZ
TRUNCATE = 0

[contextfort:chrome:launch]
TIME_PREFIX = ^\[
TIME_FORMAT = %Y-%m-%dT%H:%M:%S
```

#### 3. Example Searches

**Messages per hour:**
```spl
index=security sourcetype="contextfort:native:proxy" event_type="message_from_extension"
| timechart count by proxy_session_id
```

**Chrome launches:**
```spl
index=security sourcetype="contextfort:native:proxy" event_type="chrome_launched"
| table timestamp proxy_session_id chrome_pid
```

**Error detection:**
```spl
index=security sourcetype="contextfort:native:proxy" event_type IN ("fatal_error", "real_host_error")
| table timestamp proxy_session_id error stack
```

### QRadar

#### 1. Log Source Configuration
1. Admin → Log Sources → Add Log Source
2. **Log Source Type:** JSON
3. **Protocol:** File Follow
4. **Log Source Identifier:** contextfort-proxy
5. **Target Directory:** `/Users/*/.contextfort/logs/`
6. **Target File Pattern:** `native-proxy-events.jsonl`

#### 2. Custom Property Configuration
Map JSON fields:
- `timestamp` → Event Time
- `event_type` → Event Category
- `proxy_session_id` → Session ID (custom)
- `proxy_pid` → Source PID

#### 3. Example AQL Queries

**All proxy events:**
```sql
SELECT
  DATEFORMAT(starttime, 'YYYY-MM-dd HH:mm:ss') as time,
  "event_type",
  "proxy_session_id",
  "message_type"
FROM events
WHERE LOGSOURCETYPENAME(logsourceid) = 'contextfort-proxy'
ORDER BY starttime DESC
LAST 24 HOURS
```

**Chrome launch events:**
```sql
SELECT *
FROM events
WHERE LOGSOURCETYPENAME(logsourceid) = 'contextfort-proxy'
  AND "event_type" = 'chrome_launched'
LAST 7 DAYS
```

### Elastic Stack (ELK)

#### 1. Filebeat Configuration
**filebeat.yml:**
```yaml
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /Users/*/.contextfort/logs/native-proxy-events.jsonl
  json.keys_under_root: true
  json.add_error_key: true
  fields:
    log_type: contextfort_proxy

output.elasticsearch:
  hosts: ["https://elasticsearch:9200"]
  index: "contextfort-proxy-%{+yyyy.MM.dd}"

setup.template.name: "contextfort-proxy"
setup.template.pattern: "contextfort-proxy-*"
```

#### 2. Kibana Queries

**Discover search:**
```
log_type:"contextfort_proxy" AND event_type:"message_from_extension"
```

**Visualization (Messages over time):**
```
Metric: Count
Bucket: Date Histogram on timestamp
Split Series: event_type
```

### Microsoft Sentinel

#### 1. Data Connector
Create Custom Logs connector:
1. Navigate to: Logs → Custom Logs
2. **Sample Log:** Upload sample native-proxy-events.jsonl
3. **Record Delimiter:** New line
4. **Collection Path:** `/Users/*/.contextfort/logs/native-proxy-events.jsonl`
5. **Log Name:** ContextFort_Proxy_CL

#### 2. KQL Queries

**All events:**
```kql
ContextFort_Proxy_CL
| extend EventData = parse_json(RawData)
| project
    TimeGenerated,
    event_type = EventData.event_type,
    proxy_session_id = EventData.proxy_session_id,
    message_type = EventData.message_type
| order by TimeGenerated desc
```

**Chrome launches in last 24h:**
```kql
ContextFort_Proxy_CL
| extend EventData = parse_json(RawData)
| where EventData.event_type == "chrome_launched"
| where TimeGenerated > ago(24h)
| summarize count() by bin(TimeGenerated, 1h)
| render timechart
```

## Alerting Examples

### Splunk Alert: Excessive Message Volume
```spl
index=security sourcetype="contextfort:native:proxy" event_type="message_from_extension"
| stats count by proxy_session_id
| where count > 1000
```
**Action:** Alert if more than 1000 messages in 5 minutes (possible data exfiltration)

### QRadar Rule: Chrome Launch Without User Activity
- **Condition:** `event_type = 'chrome_launched'` AND no recent user authentication
- **Response:** Create offense, notify SOC

### Sentinel Analytics Rule: Failed Proxy Start
```kql
ContextFort_Proxy_CL
| extend EventData = parse_json(RawData)
| where EventData.event_type == "fatal_error"
| project TimeGenerated, error = EventData.error, stack = EventData.stack
```
**Severity:** Medium
**Frequency:** 5 minutes

## Log Retention

**Recommended retention periods:**
- Native proxy events: **90 days** (compliance)
- Chrome launch logs: **30 days** (troubleshooting)
- Kill switch logs: **365 days** (audit trail)

## Log Rotation

ContextFort does not rotate logs automatically. Use system log rotation:

**logrotate (Linux/macOS):**
```
/Users/*/.contextfort/logs/*.jsonl {
    daily
    rotate 90
    compress
    delaycompress
    missingok
    notifempty
    create 0644 user user
}
```

## Compliance Mapping

| Requirement | ContextFort Log | SIEM Query |
|-------------|----------------|------------|
| SOX: Access Logging | `chrome_launched` | All Chrome sessions |
| HIPAA: Audit Trail | `message_from_extension` | All data access |
| GDPR: Data Access | `message_type` + `message_preview` | User data queries |
| PCI-DSS: Session Monitoring | All events by `proxy_session_id` | Full session audit |

## Performance Considerations

- **Log volume:** ~50-100 events per Chrome session (~10KB)
- **Disk usage:** ~1MB per day per user
- **SIEM ingestion:** Use batching for high-volume environments
- **Network:** JSON Lines format is SIEM-friendly (no multiline parsing)

## Troubleshooting

**No logs appearing?**
1. Check proxy is running: `ps aux | grep native-messaging-proxy`
2. Check log directory exists: `ls -la ~/.contextfort/logs/`
3. Check file permissions: `ls -l ~/.contextfort/logs/native-proxy-events.jsonl`

**JSON parsing errors?**
- Ensure JSON Lines format (one JSON per line, no commas between)
- Validate with: `jq '.' < native-proxy-events.jsonl`

**Missing events?**
- Check proxy stderr: `tail -f ~/.contextfort/logs/native-proxy.log`
- Verify SIEM input configuration matches file paths

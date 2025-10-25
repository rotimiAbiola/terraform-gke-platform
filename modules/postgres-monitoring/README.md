# PostgreSQL Monitoring Module

This module sets up comprehensive PostgreSQL monitoring for Google Cloud SQL instances using `postgres_exporter` and Prometheus.

## Features

✅ **Monitoring User**: Creates dedicated PostgreSQL user with minimal privileges  
✅ **Custom Metrics**: 12 custom metric queries for deep insights  
✅ **Performance Monitoring**: Tracks slow queries, long-running queries, connection pools  
✅ **Health Monitoring**: Database size, bloat, vacuum stats, cache hit ratio  
✅ **Lock Monitoring**: Tracks locks, blocking queries, waiting connections  
✅ **Index Efficiency**: Monitors index usage and identifies unused indexes  
✅ **Transaction Wraparound**: Prevents catastrophic transaction ID exhaustion  
✅ **Kubernetes Native**: Deploys postgres_exporter as a Deployment with ServiceMonitor  
✅ **Secure**: Credentials stored in Google Secret Manager and Kubernetes Secrets

## Architecture

```
┌─────────────────┐
│  Cloud SQL      │
│  PostgreSQL     │◄──────┐
└─────────────────┘       │
                          │ SQL Queries
┌─────────────────┐       │
│ postgres_       │───────┘
│ exporter        │
│ (K8s Pod)       │
└────────┬────────┘
         │ HTTP :9187/metrics
         │
┌────────▼────────┐
│  Prometheus     │
│  (ServiceMon)   │
└────────┬────────┘
         │
┌────────▼────────┐
│   Grafana       │
│  (Dashboards    │
│   & Alerts)     │
└─────────────────┘
```

## Metrics Collected

### 1. **Long-Running Queries**
- Queries running longer than 5 seconds
- Grouped by database, user, application
- **Alert Threshold**: > 10 queries for > 5 minutes

### 2. **Slow Queries** (requires pg_stat_statements extension)
- Average execution time > 1 second
- Total calls, mean/max execution time
- **Alert Threshold**: Mean execution time > 5 seconds

### 3. **Connection Pool Usage**
- Total, active, idle, idle-in-transaction connections
- Connections waiting on locks/I/O
- **Alert Threshold**: > 80% of max_connections

### 4. **Database Size & Growth**
- Database size in bytes
- Transaction stats (commits, rollbacks)
- Cache efficiency (blocks read vs hit)
- **Alert Threshold**: > 90% disk usage

### 5. **Table Bloat**
- Dead tuple percentage
- Last vacuum/analyze timestamps
- Table and index sizes
- **Alert Threshold**: > 20% dead tuples

### 6. **Index Usage**
- Index scan count (low = unused index)
- Tuples read/fetched
- Index size
- **Alert Threshold**: 0 scans for indexes > 100MB

### 7. **Locks & Blocking**
- Lock types and modes
- Waiting locks (potential deadlocks)
- **Alert Threshold**: > 10 waiting locks

### 8. **Cache Hit Ratio**
- Buffer cache hit percentage
- **Alert Threshold**: < 95% (indicates insufficient shared_buffers)

### 9. **Transaction Wraparound**
- Transaction age
- Transactions until wraparound
- **Alert Threshold**: Age > 500M (critical at 1B)

### 10. **Vacuum Statistics**
- Time since last vacuum/autovacuum
- Vacuum counts
- **Alert Threshold**: > 7 days since last vacuum

### 11. **Checkpoint Performance**
- Timed vs requested checkpoints
- Checkpoint write/sync time
- Buffer allocation
- **Alert Threshold**: Requested checkpoints > 30% of total

## Prerequisites

### 1. Enable pg_stat_statements Extension

```sql
-- Connect as postgres superuser
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';

-- After restart, create extension in target databases
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```

### 2. Grant Monitoring Privileges

The module automatically creates a monitoring user, but you need to grant it access:

```sql
-- Run this AFTER terraform creates the user
GRANT pg_monitor TO monitoring;  -- PostgreSQL 10+

-- For older PostgreSQL versions:
GRANT SELECT ON pg_stat_database TO monitoring;
GRANT SELECT ON pg_stat_user_tables TO monitoring;
GRANT SELECT ON pg_stat_user_indexes TO monitoring;
GRANT SELECT ON pg_stat_activity TO monitoring;
GRANT SELECT ON pg_locks TO monitoring;
```

## Usage

### Module Configuration

```terraform
module "postgres_monitoring" {
  source = "./modules/postgres-monitoring"

  project_id              = var.project_id
  postgres_instance_name  = module.database.instance_name
  postgres_host           = module.database.private_ip_address
  monitoring_namespace    = "monitoring"
  monitoring_username     = "monitoring"

  # Optional: Customize thresholds
  slow_query_threshold_ms = 1000  # 1 second
}
```

### Outputs

```terraform
output "postgres_monitoring" {
  value = {
    monitoring_user     = module.postgres_monitoring.monitoring_user
    exporter_service    = module.postgres_monitoring.postgres_exporter_service
    metrics_endpoint    = module.postgres_monitoring.postgres_exporter_endpoint
  }
}
```

## Grant Permissions After Deployment

After Terraform creates the monitoring user, connect to PostgreSQL and grant permissions:

```bash
# Port-forward to Cloud SQL Proxy or connect directly
gcloud sql connect k8s-platform-postgresdb --user=postgres --quiet

# In psql:
GRANT pg_monitor TO monitoring;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

# Grant access to all application databases
GRANT CONNECT ON DATABASE "iam-db" TO monitoring;
GRANT CONNECT ON DATABASE "k8s-platform-order-service" TO monitoring;
GRANT CONNECT ON DATABASE "generative-ai-db" TO monitoring;
```

## Verify Deployment

```bash
# Check postgres_exporter pod
kubectl get pods -n monitoring -l app=postgres-exporter

# Check ServiceMonitor
kubectl get servicemonitor -n monitoring postgres-exporter

# Test metrics endpoint
kubectl port-forward -n monitoring svc/postgres-exporter 9187:9187
curl http://localhost:9187/metrics | grep pg_

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090
# Open http://localhost:9090/targets and search for "postgres"
```

## Alert Rules

Add these to your Grafana alerting configuration:

### High Connection Usage
```yaml
- alert: PostgreSQLHighConnections
  expr: |
    sum(pg_stat_database_numbackends{}) / 
    pg_settings_max_connections > 0.8
  for: 5m
  annotations:
    summary: "PostgreSQL connection usage > 80%"
```

### Slow Queries
```yaml
- alert: PostgreSQLSlowQueries
  expr: pg_slow_queries_mean_exec_time > 5000  # 5 seconds
  for: 10m
  annotations:
    summary: "PostgreSQL has queries averaging > 5s"
```

### High Table Bloat
```yaml
- alert: PostgreSQLHighTableBloat
  expr: pg_table_bloat_dead_tuple_percent > 20
  for: 1h
  annotations:
    summary: "Table {{ $labels.table }} has > 20% dead tuples"
```

### Low Cache Hit Ratio
```yaml
- alert: PostgreSQLLowCacheHitRatio
  expr: pg_cache_hit_ratio_cache_hit_ratio < 95
  for: 15m
  annotations:
    summary: "Database {{ $labels.database }} cache hit ratio < 95%"
```

### Transaction Wraparound Warning
```yaml
- alert: PostgreSQLTransactionWraparoundWarning
  expr: pg_transaction_wraparound_transaction_age > 500000000
  for: 1h
  annotations:
    summary: "Database {{ $labels.database }} approaching transaction wraparound"
```

### Vacuum Needed
```yaml
- alert: PostgreSQLVacuumNeeded
  expr: pg_vacuum_stats_seconds_since_last_autovacuum > 604800  # 7 days
  for: 1h
  annotations:
    summary: "Table {{ $labels.table }} not vacuumed in 7 days"
```

## Grafana Dashboards

### Recommended Dashboards

1. **PostgreSQL Overview** (Dashboard ID: 9628)
   - Import: https://grafana.com/grafana/dashboards/9628

2. **PostgreSQL Database** (Dashboard ID: 9729)
   - Import: https://grafana.com/grafana/dashboards/9729

3. **Custom Platform Dashboard**
   - See `grafana-dashboard-postgres.json` (coming soon)

### Import Dashboard

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80

# Open http://localhost:3000
# Go to: Dashboards → Import
# Enter Dashboard ID: 9628 or 9729
# Select prometheus-stack-prometheus as data source
```

## Troubleshooting

### No Metrics Showing

```bash
# Check postgres_exporter logs
kubectl logs -n monitoring -l app=postgres-exporter

# Common issues:
# 1. Connection failed - check postgres_host and credentials
# 2. Permission denied - run GRANT pg_monitor
# 3. Extension missing - CREATE EXTENSION pg_stat_statements
```

### "relation pg_stat_statements does not exist"

```sql
-- Enable extension in each database
\c iam-db
CREATE EXTENSION pg_stat_statements;

\c k8s-platform-order-service
CREATE EXTENSION pg_stat_statements;

\c generative-ai-db
CREATE EXTENSION pg_stat_statements;
```

### ServiceMonitor not creating Prometheus target

```bash
# Check if Prometheus operator is watching the namespace
kubectl get servicemonitor -n monitoring postgres-exporter -o yaml

# Ensure labels match Prometheus selector
kubectl get prometheus -n monitoring -o yaml | grep serviceMonitorSelector
```

## Performance Tuning

Based on monitoring metrics, consider these PostgreSQL tuning recommendations:

### Low Cache Hit Ratio (< 95%)
```sql
-- Increase shared_buffers (25% of RAM recommended)
ALTER SYSTEM SET shared_buffers = '2GB';
```

### High Checkpoint Activity
```sql
-- Reduce checkpoint frequency
ALTER SYSTEM SET checkpoint_timeout = '15min';
ALTER SYSTEM SET max_wal_size = '2GB';
```

### High Table Bloat
```sql
-- Tune autovacuum
ALTER SYSTEM SET autovacuum_vacuum_scale_factor = 0.1;
ALTER SYSTEM SET autovacuum_analyze_scale_factor = 0.05;
```

### High Connection Count
```sql
-- Use connection pooling (PgBouncer recommended)
-- Or increase max_connections
ALTER SYSTEM SET max_connections = 200;
```

## Cost Considerations

- **postgres_exporter Pod**: ~100m CPU, ~128Mi RAM (~$2/month)
- **Prometheus Storage**: ~500MB for 30 days retention (~$0.10/month)
- **Monitoring User**: No additional cost
- **Total Estimated Cost**: ~$2-3/month

## Security

- ✅ Monitoring user has READ-ONLY access (pg_monitor role)
- ✅ Credentials stored in Google Secret Manager (encrypted)
- ✅ Kubernetes Secret created securely
- ✅ No superuser privileges required
- ✅ SSL/TLS enforced for database connections

## References

- [postgres_exporter](https://github.com/prometheus-community/postgres_exporter)
- [PostgreSQL Monitoring Queries](https://github.com/prometheus-community/postgres_exporter/blob/master/queries.yaml)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Google Cloud SQL Monitoring](https://cloud.google.com/sql/docs/postgres/monitoring)

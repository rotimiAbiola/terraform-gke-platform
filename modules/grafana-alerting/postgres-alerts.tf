# PostgreSQL Alerting Rules
# Monitors database health, performance, and resource usage

resource "grafana_rule_group" "postgres" {
  count = var.enable_postgres_monitoring ? 1 : 0

  name             = "Platform PostgreSQL"
  folder_uid       = grafana_folder.platform_alerts.uid
  interval_seconds = 60

  # Alert 1: High Connection Usage
  rule {
    name      = "PostgreSQL High Connection Usage"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = var.prometheus_datasource_uid
      model = jsonencode({
        expr  = "(sum(pg_stat_database_numbackends) / max(pg_settings_max_connections)) * 100"
        refId = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "reduce"
        refId      = "B"
        expression = "A"
        reducer    = "last"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "threshold"
        refId      = "C"
        expression = "B"
        conditions = [
          {
            evaluator = {
              params = [80] # 80% connection usage
              type   = "gt"
            }
          }
        ]
      })
    }

    annotations = {
      summary     = "PostgreSQL connection pool usage is critically high"
      description = <<-EOT
      Connection pool usage is at {{ $values.B.Value }}% (threshold: 80%). Risk of connection exhaustion.
      
  **Database Instance:** k8s-platform-postgresdb
      **Server:** 10.65.0.10:5432
      EOT
      runbook_url = var.runbook_url_postgres_high_connections
    }

    labels = {
      severity  = "critical"
      component = "database"
      signal    = "saturation"
    }

    for            = "5m"
    no_data_state  = "NoData"
    exec_err_state = "Error"
  }

  # Alert 2: Low Cache Hit Ratio
  rule {
    name      = "PostgreSQL Low Cache Hit Ratio"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = var.prometheus_datasource_uid
      model = jsonencode({
        expr  = "avg by (database) (pg_cache_hit_ratio_cache_hit_ratio{database!~\"template.*|postgres\"})"
        refId = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "reduce"
        refId      = "B"
        expression = "A"
        reducer    = "last"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "threshold"
        refId      = "C"
        expression = "B"
        conditions = [
          {
            evaluator = {
              params = [95] # 95% cache hit ratio
              type   = "lt"
            }
          }
        ]
      })
    }

    annotations = {
      summary     = "PostgreSQL cache hit ratio is below optimal levels"
      description = <<-EOT
      Cache hit ratio is {{ $values.B.Value }}% (threshold: <95%). Database may be disk-bound.
      
  **Database Instance:** k8s-platform-postgresdb
      **Database:** {{ $labels.database }}
      **Server:** 10.65.0.10:5432
      EOT
      runbook_url = var.runbook_url_postgres_low_cache_hit
    }

    labels = {
      severity  = "warning"
      component = "database"
      signal    = "saturation"
    }

    for            = "10m"
    no_data_state  = "NoData"
    exec_err_state = "Error"
  }

  # Alert 3: High Slow Query Count
  rule {
    name      = "PostgreSQL High Slow Query Count"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = var.prometheus_datasource_uid
      model = jsonencode({
        expr  = "rate(pg_slow_queries_calls[5m])"
        refId = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "reduce"
        refId      = "B"
        expression = "A"
        reducer    = "last"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "threshold"
        refId      = "C"
        expression = "B"
        conditions = [
          {
            evaluator = {
              params = [10] # 10 slow queries per second
              type   = "gt"
            }
          }
        ]
      })
    }

    annotations = {
      summary     = "High rate of slow PostgreSQL queries detected"
      description = <<-EOT
      Slow query rate is {{ $values.B.Value | humanize }} queries/sec (threshold: >10/sec). Performance degradation likely.
      
      **Query Details:**
      - Database Instance: {{ $labels.instance }}
      - Database: {{ $labels.database }}
      - User: {{ $labels.user }}
      - Query ID: {{ $labels.queryid }}
      - Server IP: {{ $labels.server }}
      
      To view the full query text, run:
      ```
      ./scripts/check-slow-queries.ps1
      ```
      Or query directly:
      ```sql
      SELECT query FROM pg_stat_statements WHERE queryid = {{ $labels.queryid }};
      ```
      EOT
      runbook_url = var.runbook_url_postgres_slow_queries
    }

    labels = {
      severity  = "warning"
      component = "database"
      signal    = "latency"
    }

    for            = "5m"
    no_data_state  = "NoData"
    exec_err_state = "Error"
  }

  # Alert 4: Database Deadlocks
  rule {
    name      = "PostgreSQL Deadlocks Detected"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = var.prometheus_datasource_uid
      model = jsonencode({
        expr  = "rate(pg_stat_database_deadlocks{datname!~\"template.*|postgres\"}[5m])"
        refId = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "reduce"
        refId      = "B"
        expression = "A"
        reducer    = "last"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "threshold"
        refId      = "C"
        expression = "B"
        conditions = [
          {
            evaluator = {
              params = [0] # Any deadlocks
              type   = "gt"
            }
          }
        ]
      })
    }

    annotations = {
      summary     = "PostgreSQL deadlocks detected"
      description = <<-EOT
      Deadlock rate: {{ $values.B.Value | humanize }} deadlocks/sec. Transaction conflicts occurring.
      
  **Database Instance:** k8s-platform-postgresdb
      **Database:** {{ $labels.datname }}
      **Server:** 10.65.0.10:5432
      EOT
      runbook_url = var.runbook_url_postgres_deadlocks
    }

    labels = {
      severity  = "warning"
      component = "database"
      signal    = "errors"
    }

    for            = "2m"
    no_data_state  = "NoData"
    exec_err_state = "Error"
  }

  # Alert 5: Long Running Queries
  rule {
    name      = "PostgreSQL Long Running Queries"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = var.prometheus_datasource_uid
      model = jsonencode({
        expr  = "pg_stat_activity_max_tx_duration"
        refId = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "reduce"
        refId      = "B"
        expression = "A"
        reducer    = "last"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "threshold"
        refId      = "C"
        expression = "B"
        conditions = [
          {
            evaluator = {
              params = [1] # 1 or more long queries
              type   = "gt"
            }
          }
        ]
      })
    }

    annotations = {
      summary     = "PostgreSQL has long-running queries"
      description = <<-EOT
      {{ $values.B.Value }} queries running longer than 5 minutes. May indicate blocked or runaway queries.
      
  **Database Instance:** k8s-platform-postgresdb
      **Server:** 10.65.0.10:5432
      EOT
      runbook_url = var.runbook_url_postgres_long_queries
    }

    labels = {
      severity  = "warning"
      component = "database"
      signal    = "latency"
    }

    for            = "5m"
    no_data_state  = "NoData"
    exec_err_state = "Error"
  }

  # Alert 6: Database Down
  rule {
    name      = "PostgreSQL Database Down"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 60
        to   = 0
      }
      datasource_uid = var.prometheus_datasource_uid
      model = jsonencode({
        expr  = "pg_up"
        refId = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 60
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "reduce"
        refId      = "B"
        expression = "A"
        reducer    = "last"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 60
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "threshold"
        refId      = "C"
        expression = "B"
        conditions = [
          {
            evaluator = {
              params = [1] # pg_up should be 1
              type   = "lt"
            }
          }
        ]
      })
    }

    annotations = {
      summary     = "PostgreSQL database is down or unreachable"
      description = <<-EOT
      Cannot connect to PostgreSQL database. All database operations will fail.
      
  **Database Instance:** k8s-platform-postgresdb
      **Server:** 10.65.0.10:5432
      EOT
      runbook_url = var.runbook_url_postgres_down
    }

    labels = {
      severity  = "critical"
      component = "database"
      signal    = "traffic"
    }

    for            = "1m"
    no_data_state  = "Alerting"
    exec_err_state = "Error"
  }

  # Alert 7: Transaction Wraparound Risk
  rule {
    name      = "PostgreSQL Transaction Wraparound Risk"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = var.prometheus_datasource_uid
      model = jsonencode({
        expr  = "pg_transaction_wraparound_transaction_age"
        refId = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "reduce"
        refId      = "B"
        expression = "A"
        reducer    = "max"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        type       = "threshold"
        refId      = "C"
        expression = "B"
        conditions = [
          {
            evaluator = {
              params = [1000000000] # 1 billion transaction age
              type   = "gt"
            }
          }
        ]
      })
    }

    annotations = {
      summary     = "PostgreSQL at risk of transaction ID wraparound"
      description = <<-EOT
      Transaction age is {{ $values.B.Value | humanize }}. Critical: run VACUUM FREEZE immediately.
      
  **Database Instance:** k8s-platform-postgresdb
      **Server:** 10.65.0.10:5432
      EOT
      runbook_url = var.runbook_url_postgres_wraparound
    }

    labels = {
      severity  = "critical"
      component = "database"
      signal    = "saturation"
    }

    for            = "10m"
    no_data_state  = "NoData"
    exec_err_state = "Error"
  }
}

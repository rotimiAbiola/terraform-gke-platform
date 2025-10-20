terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.34.0"
    }
  }
}

locals {
  database_flags = [
    {
      name  = "log_checkpoints"
      value = "on"
    },
    {
      name  = "log_connections"
      value = "on"
    },
    {
      name  = "log_disconnections"
      value = "on"
    },
    {
      name  = "log_lock_waits"
      value = "on"
    },
    {
      name  = "log_min_error_statement"
      value = "error"
    },
    {
      name  = "log_min_messages"
      value = "warning"
    },
    {
      name  = "log_temp_files"
      value = "0"
    },
    {
      name  = "log_statement"
      value = "ddl"
    },
    {
      name  = "pg_stat_statements.max"
      value = "10000"
    },
    {
      name  = "pg_stat_statements.track"
      value = "all"
    }
  ]
}

# Random password for postgres user
resource "random_password" "postgres_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Random passwords for each user
resource "random_password" "user_passwords" {
  for_each = { for user in var.users : user.name => user }

  length           = 24
  special          = true
  override_special = "-_+.,"
  upper            = true
  lower            = true
  numeric          = true
}

# Cloud SQL PostgreSQL instance
resource "google_sql_database_instance" "postgres" {
  name             = var.instance_name
  database_version = var.database_version
  region           = var.region
  project          = var.project_id

  settings {
    tier              = var.tier
    edition           = "ENTERPRISE"
    availability_type = var.availability_type
    disk_size         = var.disk_size
    disk_type         = "PD_SSD"

    # Automatic backups
    backup_configuration {
      enabled                        = var.enable_backup
      location                       = var.backup_location
      point_in_time_recovery_enabled = var.enable_point_in_time_recovery
      start_time                     = "02:00" # 2 AM UTC
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
      }
    }

    deletion_protection_enabled = var.deletion_protection_enabled
    disk_autoresize             = var.disk_autoresize

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }

    user_labels = {
      environment = "production"
    }

    # Database flags for security and performance
    dynamic "database_flags" {
      for_each = local.database_flags
      content {
        name  = database_flags.value.name
        value = database_flags.value.value
      }
    }

    ip_configuration {
      ipv4_enabled    = var.ipv4_enabled
      private_network = var.enable_private_ip ? var.private_network : null

      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.value
        }
      }
    }

    maintenance_window {
      day          = 7 # Sunday
      hour         = 3 # 3 AM UTC
      update_track = "stable"
    }
  }

  depends_on = [
    var.network_id
  ]

  deletion_protection = true

  lifecycle {
    ignore_changes = [
      settings[0].disk_size
    ]
  }
}

# Create databases dynamically from the list
resource "google_sql_database" "databases" {
  for_each = { for db in var.databases : db.name => db }

  name      = each.value.name
  instance  = google_sql_database_instance.postgres.name
  charset   = each.value.charset
  collation = each.value.collation
  project   = var.project_id
}

# PostgreSQL admin user
resource "google_sql_user" "postgres" {
  name     = "postgres"
  instance = google_sql_database_instance.postgres.name
  password = random_password.postgres_password.result
  project  = var.project_id
}

# Create users dynamically from the list
resource "google_sql_user" "users" {
  for_each = { for user in var.users : user.name => user }

  name     = each.value.name
  instance = google_sql_database_instance.postgres.name
  password = random_password.user_passwords[each.key].result
  project  = var.project_id
}


# Store password in Secret Manager for secure access for Postgres user
resource "google_secret_manager_secret" "postgres_password" {
  secret_id = "${var.instance_name}-postgres-password"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "postgres_password" {
  secret      = google_secret_manager_secret.postgres_password.id
  secret_data = random_password.postgres_password.result
}

# Store passwords in Secret Manager for each user
resource "google_secret_manager_secret" "user_passwords" {
  for_each = { for user in var.users : user.name => user }

  secret_id = "${var.instance_name}-${each.value.name}-password"
  project   = var.project_id

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "user_passwords" {
  for_each = { for user in var.users : user.name => user }

  secret      = google_secret_manager_secret.user_passwords[each.key].id
  secret_data = random_password.user_passwords[each.key].result
}

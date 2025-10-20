output "instance_name" {
  description = "The name of the PostgreSQL instance"
  value       = google_sql_database_instance.postgres.name
}

output "connection_name" {
  description = "The connection name of the instance (project:region:name)"
  value       = google_sql_database_instance.postgres.connection_name
}

output "private_ip_address" {
  description = "The private IP address of the PostgreSQL instance"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "database_names" {
  description = "Map of database names created"
  value       = { for k, db in google_sql_database.databases : k => db.name }
}

output "user_names" {
  description = "Map of database user names created"
  value       = { for k, user in google_sql_user.users : k => user.name }
}

output "secret_name" {
  description = "The name of the Secret Manager secret containing the postgres admin password"
  value       = google_secret_manager_secret.postgres_password.name
}

output "user_secret_ids" {
  description = "Map of Secret Manager secret IDs for each user's password"
  value       = { for k, secret in google_secret_manager_secret.user_passwords : k => secret.secret_id }
}

output "user_passwords" {
  description = "Map of randomly generated passwords for each user"
  value       = { for k, pwd in random_password.user_passwords : k => pwd.result }
  sensitive   = true
}

output "postgres_admin_password" {
  description = "The randomly generated password for the postgres admin user"
  value       = random_password.postgres_password.result
  sensitive   = true
}
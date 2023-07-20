output "external_secrets_system_name" {
  description = "The name of the external secrets system"
  value       = helm_release.external_secrets_system.name
}

output "jaeger_system_namespace" {
  description = "The namespace of the external secrets system"
  value       = helm_release.external_secrets_system.namespace
}

output "jaeger_system_version" {
  description = "The version of the external secrets system"
  value       = helm_release.external_secrets_system.version
}

output "jaeger_system_chart" {
  description = "The chart of the external secrets system"
  value       = helm_release.external_secrets_system.chart
}

output "repository" {
  description = "The repository of the external secrets system"
  value       = helm_release.external_secrets_system.repository
}

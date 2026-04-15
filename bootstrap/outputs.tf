output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}

output "github_actions_role_arn" {
  description = "Add this as AWS_ROLE_ARN secret in your GitHub repository settings"
  value       = aws_iam_role.github_actions.arn
}

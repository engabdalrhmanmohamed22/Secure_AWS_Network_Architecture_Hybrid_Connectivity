output "cloudfront_domain" { value = aws_cloudfront_distribution.site.domain_name }
output "site_bucket" { value = aws_s3_bucket.site.bucket }
output "flowlog_bucket" { value = aws_s3_bucket.flow.bucket }
output "athena_workgroup" { value = aws_athena_workgroup.p4.name }
output "flowlog_log_group" { value = aws_cloudwatch_log_group.flow.name }
output "s3_endpoint_id" { value = aws_vpc_endpoint.s3.id }
output "interface_endpoint_ids" { value = { for k, v in aws_vpc_endpoint.interface : k => v.id } }

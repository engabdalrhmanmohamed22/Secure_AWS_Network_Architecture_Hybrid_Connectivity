#!/usr/bin/env bash
# Week 1: بيطلّع توثيق SG/NACL/الـ deployment تلقائياً في ملف Markdown
# الاستخدام: VPC_ID=vpc-xxxx AWS_PROFILE=depi-team-1 ./scripts_document_rules.sh > sg-nacl-documentation.md
set -euo pipefail
: "${VPC_ID:?set VPC_ID}"
echo "# SG / NACL Rules Documentation - $VPC_ID"; echo "_Generated: $(date -u +%F\ %T) UTC_"; echo
echo "## Security Groups"
aws ec2 describe-security-groups --filters Name=vpc-id,Values="$VPC_ID" --output json | jq -r '
 .SecurityGroups[] | "### \(.GroupName) (\(.GroupId))\n\(.Description)\n\n**Inbound**\n\n| Proto | Port | Source | Description |\n|---|---|---|---|" ,
 (.IpPermissions[] | . as $p | ((.IpRanges[]|.CidrIp),(.UserIdGroupPairs[]|.GroupId)) as $src | "| \($p.IpProtocol) | \($p.FromPort // "all")-\($p.ToPort // "all") | \($src) | |"),
 "\n**Outbound**\n\n| Proto | Port | Destination |\n|---|---|---|",
 (.IpPermissionsEgress[] | . as $p | ((.IpRanges[]|.CidrIp),(.UserIdGroupPairs[]|.GroupId)) as $d | "| \($p.IpProtocol) | \($p.FromPort // "all")-\($p.ToPort // "all") | \($d) |"), ""'
echo "## Network ACLs"
aws ec2 describe-network-acls --filters Name=vpc-id,Values="$VPC_ID" --output json | jq -r '
 .NetworkAcls[] | "### \(.NetworkAclId) - subnets: \([.Associations[].SubnetId]|join(", "))\n\n| Rule# | Dir | Action | Proto | Ports | CIDR |\n|---|---|---|---|---|---|",
 (.Entries | sort_by(.Egress, .RuleNumber)[] | "| \(.RuleNumber) | \(if .Egress then "out" else "in" end) | \(.RuleAction) | \(.Protocol) | \(.PortRange.From // "all")-\(.PortRange.To // "all") | \(.CidrBlock // .Ipv6CidrBlock) |"), ""'
echo "## Deployed resources (EC2 / ALB / RDS)"
aws ec2 describe-instances --filters Name=vpc-id,Values="$VPC_ID" --query 'Reservations[].Instances[].[InstanceId,InstanceType,PrivateIpAddress,SubnetId,State.Name]' --output table
aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC_ID'].[LoadBalancerName,Scheme,DNSName]" --output table
aws rds describe-db-instances --query "DBInstances[?DBSubnetGroup.VpcId=='$VPC_ID'].[DBInstanceIdentifier,Engine,PubliclyAccessible,StorageEncrypted]" --output table

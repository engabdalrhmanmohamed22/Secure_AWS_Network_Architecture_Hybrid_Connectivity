# Person 4 - Edge, Private Endpoints & Monitoring

| Week | المطلوب | الملفات |
|---|---|---|
| 1 | توثيق الـ deployment وقواعد SG/NACL | `scripts_document_rules.sh` (بيولّد التوثيق تلقائياً من الحساب) |
| 2 | VPC Endpoints + PrivateLink | `endpoints.tf` |
| 3 | CloudFront + S3 lab + edge architecture | `cloudfront.tf` |
| 4 | Flow Logs, Traffic Mirroring, CloudWatch, Athena, IR runbook | `monitoring.tf`, `IR_RUNBOOK.md` |

## التشغيل
```bash
cp terraform.tfvars.example terraform.tfvars   # الـ VPC/subnets بتتلقى تلقائياً من الـ CIDR (10.0.0.0/16)، وشغّل بعد ما Person 1 يعمل apply
terraform init && terraform plan && terraform apply
```

## Test steps (ادخل بيها screenshots في التقرير)
**Week 2 - Endpoints**
1. من EC2 خاص عبر SSM: `aws s3 ls` ← شغال من غير NAT (راجع route table فيها `pl-xxxx` للـ S3 prefix list).
2. `nslookup ssm.us-east-1.amazonaws.com` ← لازم يرجّع private IP (10.x).
3. PrivateLink: `curl http://<DNS-of-consumer-endpoint>` ← يرجّع الصفحة.

**Week 3 - CloudFront**
1. `curl -I https://$(terraform output -raw cloudfront_domain)` ← 200 + header `strict-transport-security`.
2. `curl -I http://...` ← 301 redirect لـ https.
3. `curl -I https://<bucket>.s3.amazonaws.com/index.html` ← 403 (البكت مش public).
4. بعد ما Person 2 يربط الـ WAF: ابعت request مشبوه وتأكد من الـ block.

**Week 4 - Monitoring**
1. ولّد traffic مرفوض: `nmap -Pn -p 1-100 <private-ip>` من instance تاني، أو `nc -zv <ip> 22`.
2. استنى ~5 دقايق ← شوف الـ log group `/depi/p4/vpc-flow-logs` والـ alarm.
3. Athena: شغّل `00-create-vpc-flow-logs-table` الأول، وبعدين queries 01 → 06 من Saved queries في workgroup `p4-network-analysis`.
4. Traffic Mirroring: فعّل `enable_traffic_mirroring` وعلى الـ collector شغّل `sudo tcpdump -i any port 4789 -n` (VXLAN).
5. تمرين IR: اتبع `IR_RUNBOOK.md` على instance تجريبي.

## Edge architecture
```
User → CloudFront (HTTPS only, TLS1.2+, security headers, [WAF - Person 2])
        └─ OAC (SigV4) → S3 private bucket (Block Public Access, SSE)
Private EC2 → Gateway endpoint (S3) / Interface endpoints (SSM, Logs) / PrivateLink (NLB)
VPC → Flow Logs → S3 → Athena     |  → CloudWatch Logs → Metric Filters → Alarms → SNS
ENI → Traffic Mirroring (VXLAN 4789) → Collector
```
## ملاحظات
- Traffic Mirroring بيشتغل بس على Nitro instances.
- الـ filter في الـ Athena table بيفترض الفورمات الافتراضي للـ flow logs.
- Interface endpoints وNLB والـ NAT بيتحاسبوا بالساعة → اعمل `terraform destroy` بعد التسليم.

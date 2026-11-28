# Compromised EC2 Instance - IR Runbook (Person 4)

**Severity:** High | **Owner:** Network Security / IR | **Scope:** أي EC2 في الـ VPC

## 0. Detection (إيه اللي بينبهنا)
- CloudWatch alarm `p4-ssh-rdp-rejected-spike` أو `p4-rejected-traffic-spike`
- Athena queries `03-port-scan-detection`, `05-possible-exfiltration`
- Traffic Mirroring على الـ ENI المشتبه فيه (Suricata/tcpdump على الـ collector)

## 1. Triage (5 دقايق)
```bash
INSTANCE=i-xxxx
aws ec2 describe-instances --instance-ids $INSTANCE \
  --query 'Reservations[].Instances[].[PrivateIpAddress,NetworkInterfaces[].NetworkInterfaceId,SecurityGroups[].GroupId,IamInstanceProfile.Arn]'
```
سجّل: الوقت، مين اكتشف، ليه (alarm/query)، الـ ENI والـ IP.

## 2. Contain - عزل بالـ Security Group (بدون ما نقفل الجهاز)
1. أنشئ SG عزل **بدون أي rules** (inbound/outbound):
```bash
ISO_SG=$(aws ec2 create-security-group --group-name ir-isolation --description "IR isolation" --vpc-id $VPC_ID --query GroupId --output text)
aws ec2 revoke-security-group-egress --group-id $ISO_SG --ip-permissions '[{"IpProtocol":"-1","IpRanges":[{"CidrIp":"0.0.0.0/0"}]}]'
```
2. احفظ الـ SGs القديمة (للتوثيق) ثم بدّل:
```bash
aws ec2 describe-instances --instance-ids $INSTANCE --query 'Reservations[].Instances[].SecurityGroups' > evidence/original-sgs.json
aws ec2 modify-instance-attribute --instance-id $INSTANCE --groups $ISO_SG
```
3. ضيف tag: `aws ec2 create-tags --resources $INSTANCE --tags Key=IR,Value=isolated`
4. اسحب الـ IAM role: انقل الـ instance profile لـ role بـ `Deny *` أو اعمل `aws ec2 disassociate-iam-instance-profile`.
> ملاحظة: الـ connections المتأسسة قبل التغيير بتفضل شغالة (connection tracking) → لو لازم قطعها فوراً استخدم NACL deny على الـ IP الخاص بالجهاز في الـ subnet.

## 3. Preserve Evidence (قبل الإيقاف)
```bash
mkdir -p evidence && cd evidence
# 3.1 Snapshot لكل الـ volumes
for V in $(aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$INSTANCE --query 'Volumes[].VolumeId' --output text); do
  aws ec2 create-snapshot --volume-id $V --description "IR $INSTANCE $(date -u +%FT%TZ)" \
    --tag-specifications 'ResourceType=snapshot,Tags=[{Key=IR,Value=evidence},{Key=Instance,Value='$INSTANCE'}]'
done
# 3.2 Metadata + console output
aws ec2 describe-instances --instance-ids $INSTANCE > instance-metadata.json
aws ec2 get-console-output --instance-id $INSTANCE --latest > console-output.txt
# 3.3 Flow logs الخاصة بالـ ENI (Athena query 06) + CloudTrail
aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=$INSTANCE > cloudtrail.json
# 3.4 Hash للأدلة
sha256sum * > SHA256SUMS.txt
```
- لو في memory acquisition: اعملها قبل الإيقاف (عن طريق SSM + LiME) وبعدين خزّنها في S3 bucket مقفول.
- **Chain of custody:** سجّل مين نسخ إيه ومتى (جدول تحت).

## 4. Eradicate & Recover
1. شغّل instance جديد من AMI نضيف (مش من الجهاز المصاب).
2. اعمل rotate لأي secrets/keys كانت على الجهاز.
3. اربط snapshot بـ instance تحليل معزول (forensic VPC/subnet) للفحص.
4. بعد التحليل: terminate الجهاز المصاب، وامسح SG العزل لو مش محتاجه.

## 5. Post-incident
- Root cause + timeline.
- تحسينات: tighten SG/NACL، GuardDuty، تحديث الـ detection queries.
- حدّث الـ runbook.

## Evidence log
| Time (UTC) | Item | Collected by | Location | SHA256 |
|---|---|---|---|---|
| | | | | |

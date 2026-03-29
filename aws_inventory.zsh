#!/usr/bin/env zsh

set -euo pipefail

PROFILE="default"
REGION="eu-north-1"
OUTFILE="aws-active-resources-$(date +%Y%m%d-%H%M%S).txt"

echo "AWS active resource inventory" > "$OUTFILE"
echo "Profile: $PROFILE" >> "$OUTFILE"
echo "Region: $REGION" >> "$OUTFILE"
echo "Generated: $(date)" >> "$OUTFILE"
echo >> "$OUTFILE"

ACCOUNT_ID=$(aws sts get-caller-identity \
  --profile "$PROFILE" \
  --query Account \
  --output text)

echo "Account: $ACCOUNT_ID" >> "$OUTFILE"
echo >> "$OUTFILE"

{
  echo "=================================================="
  echo "REGION: $REGION"
  echo "=================================================="

  echo "--- EC2 instances (non-terminated) ---"
  aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name,Name:Tags[?Key==`Name`]|[0].Value}' \
    --output table || true

  echo "--- EBS volumes ---"
  aws ec2 describe-volumes \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'Volumes[?State==`in-use` || State==`available`].{Id:VolumeId,State:State,Size:Size}' \
    --output table || true

  echo "--- Elastic IPs ---"
  aws ec2 describe-addresses \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output table || true

  echo "--- NAT Gateways ---"
  aws ec2 describe-nat-gateways \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'NatGateways[?State!=`deleted`].{Id:NatGatewayId,State:State}' \
    --output table || true

  echo "--- Load Balancers ---"
  aws elbv2 describe-load-balancers \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output table || true

  echo "--- RDS instances ---"
  aws rds describe-db-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output table || true

  echo "--- Lambda functions ---"
  aws lambda list-functions \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output table || true

  echo "--- DynamoDB tables ---"
  aws dynamodb list-tables \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output table || true

  echo "--- SQS queues ---"
  aws sqs list-queues \
    --profile "$PROFILE" \
    --region "$REGION" \
    --output table || true

  echo "--- SNS topics ---"
  aws sns list-topics \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'Topics[].TopicArn' \
    --output table || true

  echo "--- CloudWatch log groups ---"
  aws logs describe-log-groups \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'logGroups[].logGroupName' \
    --output table || true

  echo
} >> "$OUTFILE"

# Global resources
{
  echo "=================================================="
  echo "GLOBAL RESOURCES"
  echo "=================================================="

  echo "--- S3 buckets ---"
  aws s3api list-buckets \
    --profile "$PROFILE" \
    --query 'Buckets[].Name' \
    --output table || true

  echo "--- IAM roles ---"
  aws iam list-roles \
    --profile "$PROFILE" \
    --query 'Roles[].RoleName' \
    --output table || true

  echo "--- CloudFront distributions ---"
  aws cloudfront list-distributions \
    --profile "$PROFILE" \
    --query 'DistributionList.Items[].Id' \
    --output table || true
} >> "$OUTFILE"

echo "✅ Inventory written to $OUTFILE"
#!/usr/bin/env zsh

set -euo pipefail

PROFILE="default"
REGION="eu-north-1"

log() {
  echo "[$(date '+%H:%M:%S')] $*"
}

confirm() {
  local reply
  read "reply?$1 (y/n): "
  [[ "$reply" == "y" || "$reply" == "Y" ]]
}

final_confirmation() {
  local confirm_text
  echo
  echo "⚠️  FINAL WARNING ⚠️"
  echo "This will DELETE selected AWS resources permanently."
  read "confirm_text?Type 'DELETE' to continue: "
  [[ "$confirm_text" == "DELETE" ]]
}

run_cmd() {
  echo "👉 $*"
  eval "$@"
}

# Returns 0 if array has at least one non-empty item
has_items() {
  (( $# > 0 )) && [[ -n "${1:-}" ]]
}

log "AWS Cleanup Tool"
echo "Profile: $PROFILE"
echo "Region: $REGION"
echo

DELETE_EC2=false
DELETE_EBS=false
DELETE_EIP=false
DELETE_NAT=false
DELETE_LB=false
DELETE_RDS=false
DELETE_EFS=false
DELETE_S3=false

confirm "Delete EC2 instances?" && DELETE_EC2=true
confirm "Delete unattached EBS volumes?" && DELETE_EBS=true
confirm "Release unused Elastic IPs?" && DELETE_EIP=true
confirm "Delete NAT Gateways?" && DELETE_NAT=true
confirm "Delete Load Balancers?" && DELETE_LB=true
confirm "Delete RDS instances & clusters? (⚠️ destructive)" && DELETE_RDS=true
confirm "Delete EFS file systems? (⚠️ destructive)" && DELETE_EFS=true
confirm "Delete ALL S3 buckets? (⚠️ VERY destructive)" && DELETE_S3=true

echo
log "Summary:"
echo "EC2=$DELETE_EC2 | EBS=$DELETE_EBS | EIP=$DELETE_EIP | NAT=$DELETE_NAT"
echo "LB=$DELETE_LB | RDS=$DELETE_RDS | EFS=$DELETE_EFS | S3=$DELETE_S3"

final_confirmation || {
  log "Aborted"
  exit 1
}

echo
log "Starting cleanup..."

# =========================
# EC2
# =========================
if $DELETE_EC2; then
  log "Checking EC2 instances..."
  EC2_IDS=("${(@f)$(aws ec2 describe-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text | tr '\t' '\n' | sed '/^[[:space:]]*$/d')}")

  if has_items "${EC2_IDS[@]}"; then
    log "Deleting EC2 instances:"
    printf '  %s\n' "${EC2_IDS[@]}"
    run_cmd "aws ec2 terminate-instances --profile $PROFILE --region $REGION --instance-ids ${(j: :)EC2_IDS}"
  else
    log "No EC2 instances found"
  fi
fi

# =========================
# EBS
# =========================
if $DELETE_EBS; then
  log "Checking unattached EBS volumes..."
  EBS_IDS=("${(@f)$(aws ec2 describe-volumes \
    --profile "$PROFILE" \
    --region "$REGION" \
    --filters "Name=status,Values=available" \
    --query 'Volumes[].VolumeId' \
    --output text | tr '\t' '\n' | sed '/^[[:space:]]*$/d')}")

  if has_items "${EBS_IDS[@]}"; then
    log "Deleting unattached EBS volumes:"
    printf '  %s\n' "${EBS_IDS[@]}"
    for id in "${EBS_IDS[@]}"; do
      run_cmd "aws ec2 delete-volume --profile $PROFILE --region $REGION --volume-id $id"
    done
  else
    log "No unattached EBS volumes found"
  fi
fi

# =========================
# Elastic IPs
# =========================
if $DELETE_EIP; then
  log "Checking unused Elastic IPs..."
  EIP_ALLOC_IDS=("${(@f)$(aws ec2 describe-addresses \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'Addresses[?AssociationId==null].AllocationId' \
    --output text | tr '\t' '\n' | sed '/^[[:space:]]*$/d')}")

  if has_items "${EIP_ALLOC_IDS[@]}"; then
    log "Releasing unused Elastic IPs:"
    printf '  %s\n' "${EIP_ALLOC_IDS[@]}"
    for id in "${EIP_ALLOC_IDS[@]}"; do
      run_cmd "aws ec2 release-address --profile $PROFILE --region $REGION --allocation-id $id"
    done
  else
    log "No unused Elastic IPs found"
  fi
fi

# =========================
# NAT Gateways
# =========================
if $DELETE_NAT; then
  log "Checking NAT Gateways..."
  NAT_IDS=("${(@f)$(aws ec2 describe-nat-gateways \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'NatGateways[?State!=`deleted`].NatGatewayId' \
    --output text | tr '\t' '\n' | sed '/^[[:space:]]*$/d')}")

  if has_items "${NAT_IDS[@]}"; then
    log "Deleting NAT Gateways:"
    printf '  %s\n' "${NAT_IDS[@]}"
    for id in "${NAT_IDS[@]}"; do
      run_cmd "aws ec2 delete-nat-gateway --profile $PROFILE --region $REGION --nat-gateway-id $id"
    done
  else
    log "No NAT Gateways found"
  fi
fi

# =========================
# Load Balancers
# =========================
if $DELETE_LB; then
  log "Checking Load Balancers..."
  LB_ARNS=("${(@f)$(aws elbv2 describe-load-balancers \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'LoadBalancers[].LoadBalancerArn' \
    --output text | tr '\t' '\n' | sed '/^[[:space:]]*$/d')}")

  if has_items "${LB_ARNS[@]}"; then
    log "Deleting Load Balancers:"
    printf '  %s\n' "${LB_ARNS[@]}"
    for arn in "${LB_ARNS[@]}"; do
      run_cmd "aws elbv2 delete-load-balancer --profile $PROFILE --region $REGION --load-balancer-arn '$arn'"
    done
  else
    log "No Load Balancers found"
  fi
fi

# =========================
# RDS
# =========================
if $DELETE_RDS; then
  log "Checking RDS DB instances..."
  RDS_INSTANCE_IDS=("${(@f)$(aws rds describe-db-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'DBInstances[].DBInstanceIdentifier' \
    --output text | tr '\t' '\n' | sed '/^[[:space:]]*$/d')}")

  if has_items "${RDS_INSTANCE_IDS[@]}"; then
    log "Deleting RDS DB instances:"
    printf '  %s\n' "${RDS_INSTANCE_IDS[@]}"
    for id in "${RDS_INSTANCE_IDS[@]}"; do
      run_cmd "aws rds delete-db-instance --profile $PROFILE --region $REGION --db-instance-identifier $id --skip-final-snapshot --delete-automated-backups"
    done
  else
    log "No RDS DB instances found"
  fi

  log "Checking RDS DB clusters..."
  RDS_CLUSTER_IDS=("${(@f)$(aws rds describe-db-clusters \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'DBClusters[].DBClusterIdentifier' \
    --output text | tr '\t' '\n' | sed '/^[[:space:]]*$/d')}")

  if has_items "${RDS_CLUSTER_IDS[@]}"; then
    log "Deleting RDS DB clusters:"
    printf '  %s\n' "${RDS_CLUSTER_IDS[@]}"
    for id in "${RDS_CLUSTER_IDS[@]}"; do
      run_cmd "aws rds delete-db-cluster --profile $PROFILE --region $REGION --db-cluster-identifier $id --skip-final-snapshot"
    done
  else
    log "No RDS DB clusters found"
  fi
fi

# =========================
# EFS
# =========================
if $DELETE_EFS; then
  log "Checking EFS file systems..."
  EFS_IDS=("${(@f)$(aws efs describe-file-systems \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'FileSystems[].FileSystemId' \
    --output text | tr '\t' '\n' | sed '/^[[:space:]]*$/d')}")

  if has_items "${EFS_IDS[@]}"; then
    log "Deleting EFS file systems:"
    printf '  %s\n' "${EFS_IDS[@]}"
    for fs in "${EFS_IDS[@]}"; do
      log "Checking mount targets for file system $fs..."
      MT_IDS=("${(@f)$(aws efs describe-mount-targets \
        --profile "$PROFILE" \
        --region "$REGION" \
        --file-system-id "$fs" \
        --query 'MountTargets[].MountTargetId' \
        --output text | tr '\t' '\n' | sed '/^[[:space:]]*$/d')}")

      if has_items "${MT_IDS[@]}"; then
        log "Deleting mount targets for $fs:"
        printf '  %s\n' "${MT_IDS[@]}"
        for mt in "${MT_IDS[@]}"; do
          run_cmd "aws efs delete-mount-target --profile $PROFILE --region $REGION --mount-target-id $mt"
        done
      else
        log "No mount targets found for $fs"
      fi

      run_cmd "aws efs delete-file-system --profile $PROFILE --region $REGION --file-system-id $fs"
    done
  else
    log "No EFS file systems found"
  fi
fi

# =========================
# S3
# =========================
if $DELETE_S3; then
  log "Checking S3 buckets..."
  S3_BUCKETS=("${(@f)$(aws s3api list-buckets \
    --profile "$PROFILE" \
    --query 'Buckets[].Name' \
    --output text | tr '\t' '\n' | sed '/^[[:space:]]*$/d')}")

  if has_items "${S3_BUCKETS[@]}"; then
    log "Deleting S3 buckets:"
    printf '  %s\n' "${S3_BUCKETS[@]}"
    for bucket in "${S3_BUCKETS[@]}"; do
      run_cmd "aws s3 rb s3://$bucket --force --profile $PROFILE"
    done
  else
    log "No S3 buckets found"
  fi
fi

echo
log "✅ Cleanup completed"
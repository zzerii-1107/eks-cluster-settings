
#!/bin/bash

account_id="0123456789"
region_code="ap-northeast-2"
eks_cluster_name="application-eks-cluster"
aws_vault_id=$1

role_name="application-eks-cluster-lb-controller-role"
policy_arn="arn:aws:iam::0123456789:policy/AWSLoadBalancerControllerIAMPolicy"



if [ -z $aws_vault_id ]; then
  echo "need aws-vault id"
  exit
else
  temp=$(aws-vault list | grep $aws_vault_id | awk '{print $1}')
  if [[ $aws_vault_id != $temp ]]; then
    echo "please ensure aws-vault id"
    exit 1
  fi
fi

oidc_provider_id=$(
aws-vault exec ${aws_vault_id} --no-session -- aws eks describe-cluster \
  --name ${eks_cluster_name} \
  --query "cluster.identity.oidc.issuer" \
  --output text | grep https://oidc.eks.${region_code}.amazonaws.com/id/ | cut -d/ -f5-
)

cat <<EOF > load-balancer-role-trust-policy.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${account_id}:oidc-provider/oidc.eks.${region_code}.amazonaws.com/id/${oidc_provider_id}"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.${region_code}.amazonaws.com/id/${oidc_provider_id}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller",
                    "oidc.eks.${region_code}.amazonaws.com/id/${oidc_provider_id}:aud": "sts.amazonaws.com"
                }
            }
        }
    ]
}
EOF

aws-vault exec $aws_vault_id --no-session -- eksctl utils \
	associate-iam-oidc-provider \
    --region $region_code \
    --cluster $eks_cluster_name \
    --approve

aws-vault exec $aws_vault_id --no-session -- aws iam create-role \
  --role-name $role_name \
  --assume-role-policy-document file://"load-balancer-role-trust-policy.json"

aws-vault exec $aws_vault_id --no-session -- aws iam attach-role-policy \
  --policy-arn $policy_arn \
  --role-name $role_name

#!/bin/bash

declare arr
profile_list=$(aws-vault list --profiles | grep ^service- | sort)
default_region="ap-northeast-2"

echo -n "hosted zone id를 입력하세요: "
read -r hosted_zone_id

echo -n "vpc id를 입력하세요: "
read -r vpc_id

echo -n "vpc region을 입력하세요(default: ap-northeast-2): "
read -r vpc_region

echo -n "hosted zone을 소유한 profile을 선택하세요: "
echo
cnt=1
for i in $profile_list; do
  echo "${cnt}. $i"
  arr[$(($cnt-1))]=$i
  cnt=$(($cnt+1))
done
read -r profile_num_1

echo -n "vpc를 소유한 profile을 선택하세요: "
echo
cnt=1
for i in $profile_list; do
  echo "${cnt}. $i"
  arr[$(($cnt-1))]=$i
  cnt=$(($cnt+1))
done
read -r profile_num_2

vpc_region="${vpc_region:-$default_region}"

echo "================================================="
echo "hosted zone id: $hosted_zone_id"
echo "vpc id: $vpc_id"
echo "vpc region: ${vpc_region:-$default_region}"
echo "hosted zone을 소유한 profile: ${arr[$(($profile_num_1-1))]}"
echo "vpc을 소유한 profile: ${arr[$(($profile_num_2-1))]}"
echo "================================================="
echo
echo -n "위의 정보가 맞습니까?(y/n) "
read yn
if [[ $yn == "y" ]];then
  aws-vault exec ${arr[$(($profile_num_1-1))]} --no-session -- aws route53 create-vpc-association-authorization --hosted-zone-id $hosted_zone_id --vpc VPCRegion=$vpc_region,VPCId=$vpc_id
  aws-vault exec ${arr[$(($profile_num_2-1))]} --no-session -- aws route53 associate-vpc-with-hosted-zone --hosted-zone-id $hosted_zone_id --vpc VPCRegion=$vpc_region,VPCId=$vpc_id
else
  echo "종료합니다."
  exit 0
fi
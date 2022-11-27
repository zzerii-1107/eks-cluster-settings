# kube-cluster-settings-yaml

이 repository는 클러스터 별 OICD, aws-loadbalancer-controller 설정 등, 클러스터 설정 업무를 위한 yaml파일을 저장하는 저장소 입니다.

해당 repository의 문서는 언제든지 수정되고 변경될 수 있습니다. (특히 prod의 경우 값 입력이 바르지 않습니다.)

## 목차


[초기 Settings](#초기-settings)

---

[실행하기](#실행하기)

[  1. Identity providers 생성 및 oicd 인증](#1-identity-providers-생성-및-oicd-인증)

[  2. service accouont 생성](#2-service-accouont-생성)

[  3. aws-load-balancer-controller 배포](#3-aws-load-balancer-controller-배포)

---
[deploy Settings](#deploy-settings)

[  4. namespace 생성](#4-namespace-생성)

[  5. api 배포](#5-api-배포)

[  6. ingress 배포](#6-ingress-배포)

---
[Ingress 배포 및 도메인 설정](#ingress-배포-및-도메인-설정)

[A. EXTERNAL INGRESS](#a-external-ingress)

[  1. external ingress 배포](#1-external-ingress-배포)

[  2. 도메인 등록하기](#2-도메인-등록하기)

[  3. ACM 생성하기](#3-acm-생성하기)

[  4. ACM CNAME 도메인 등록하기](#4-acm-cname-도메인-등록하기)

[  5. ingress 수정하기](#5-ingress-수정하기)

[B. INTERNAL INGRESS](#b-internal-ingress)

[  1. internal ingress 배포](#1-internal-ingress-배포)

[  2. VPC ASSOCIATED](#2-vpc-associated)

[  3. local domain 등록](#3-local-domain-등록)

---

[연결 Test 하기](#연결-test-하기)

---
[삭제하기](#삭제하기)

[Ingress가 제대로 설정되지 않아 삭제해야 하는데 지워지지 않는 경우](#추가)

---

## 접속하기
(모든 클러스터는 해당 작업이 되어있습니다.)
초기 접속 시, iac-role이 eks를 생성하기 때문에 admin.mz 와같은 user는 클러스터에 접속할 수 없습니다.
이를 위해서는 config map 수정을 해줘야합니다.

`kube-system` namespace에 `configMaps` 의 `aws-auth` 를 수정해줍니다.

```
kubectl edit cm -n kube-system aws-auth
```

해당 yaml 파일에서
```
apiVersion: v1
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::1234567890:role/example-api-nodegroup-role
      username: system:node:{{EC2PrivateDNSName}}

:
kind: ConfigMap
metadata:
  :
  :

```

다음과 같이 mapUsers을  수정해주시면 됩니다.

```
apiVersion: v1
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::12345566:role/example-api-nodegroup-role
      username: system:node:{{EC2PrivateDNSName}}
  mapUsers
    - userarn: arn:aws:iam::12345566:user/lin
    username: admin
    groups:
      - system:masters
    - userarn: arn:aws:iam::12345566:user/chae
    username: admin
    groups:
      - system:masters
      :
      :
kind: ConfigMap
metadata:
  :
  :

```



## 초기 Settings

작업하고자 하는 클러스터에 접속 후
Terminal에서 작업하는 클러스터에 해당되는 디렉토리로 이동합니다.

`cd ~/kube-cluster-settings-yaml/example/example-cluster`

각각의 디렉토리는 다음과 같은 구조로 이루어져 있으며 해당 클러스터에 맞게 작성되어 있습니다(수정 중.)

파일 및 디렉토리 앞에 붙은 시퀀스 순서대로 실행하시면 되며, 4,5,6번은 test용도로 작성된 파일이기 때문에 언제든지 수정,삭제 될 수 있습니다.

```
1-oicd.sh
2-aws-load-balancer-controller-service-account.yaml
3-aws-load-balancer-controller/
4-kcl-api.yaml
5-ingress-internal.yaml
6-centos-deployment.yaml
```

## 실행하기

### 1. Identity providers 생성 및 oicd 인증
`1-oicd.sh [vault_profile]`

[vault_profile] 작업하는 클러스터의 계정에 해당하는 vault profile을 적어주시면 됩니다.

Identity providers 생성 부터 role-policy attach 까지의 작업을 수행합니다.

### 2. service accouont 생성

`kubectl apply -f 2-aws-load-balancer-controller-service-account.yaml`

aws-load-balancer 생성을 위한 service accouont 를 생성하는 yaml 입니다.

`-f` 옵션은 파일을 사용하여 kubectl 명령어를 사용하겠다는 옵션입니다.

해당 파일을 보시면 annotation에 oicd.sh 에서 생성한  `example-cluster-lb-controller-role` 이 할당되어 있습니다.

해당 role 에는 작업하는 클러스터의 상단의 명령어로 만드는 service account가 신뢰정책에 포함되어있으며, 정책으로 CreateServiceLinkedRole로 LB 생성 권한이 있는 것을 보실 수 있습니다.

### 3. aws-load-balancer-controller 배포

```
helm template aws-load-balancer-controller . --namespace kube-system --set clusterName=<클러스터 이름> --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller --set region=ap-northeast-2 --set vpcId=<VPC ID> | kubectl apply -f -
  ```

local에 있는 helm chart를 이용하여 aws-load-balancer-controller를 생성하는 명령어 입니다.

`-n` 옵션으로 kube-system 이라는 namespace에 kubernetes 리소스를 배포할 수 있습니다.

`./3-aws-load-balancer-controller` 의 내부의 value 파일에 cluster name에 작업하는 cluster name을 입력하고

저희는 앞서서 service account 를 생성하였기 때문에 `create: false` , 그리고  name에 service account 의 이름을 넣습니다.

이 repo에는 모든 작업이 되어 있습니다.


**** 해당 값을 설정해주지 않으면 default로 `.kube/config` 파일의 정보를 읽어 해당 클러스터의 정보가 자동으로 입력됩니다.


### ============== 여기까지 aws-load-balancer-controller 를 사용하여 ingress를 띄울 준비가 완료되었습니다. ==============

## deploy Settings

### 4. namespace 생성

먼저, 생성 전에 중복되는 namespace가 있는지 확인합니다.

`kubectl get ns`

```
NAME              STATUS   AGE
default           Active   77d
kcl-web          Active   16h
kube-node-lease   Active   77d
kube-public       Active   77d
kube-system       Active   77d
```
namespace의 목록이 보입니다. 

Lens에서는 Namespaces 텝에서 확인하실 수 있습니다.



`kubectl create ns [namespaces 이름]`

작업을 위한 namespace를 생성합니다.

ns는 namespace의 줄임말입니다. ns 부분을 namespace라고 사용하셔도 무방합니다.

namespace 이름의 경우 클러스터와 용도에 따라 이름을 다르게 설정해야하기 때문에 **담당자와 사전에 이야기를 나눈 후** 결정하여 생성하시면 될 것 같습니다.


### 5. api 배포

`4-kcl-api.yaml`

해당 파일은 deployment와 service 를 생성하는 yaml입니다.

deployment와 service에 대해서는 인터넷에 자료가 아주 많으니 여기서 설명은 생략하도록 하겠습니다.

현재 대부분의 파일은 ㅇㅇㅇㅇ의 이미지를 가져와 배포해서 test용도로 사용하도록 설정되어있습니다.

하지만, 클러스터마다 올라가는 이미지가 다르기 때문에 **담당하시는 분의 API가 ECR에 push** 됐는지 확인 후

**해당 이미지 정보와 이미지 버전 정보를 담당자 분께 받거나 확인 하셔서** 문서를 수정하셔야 합니다.

수정하셔야 하는 부분들은 `<꺽쇠 괄호>` 와 주석으로 설명 및 표시해 두겠습니다. **괄호까지 없애시고 수정**하셔서 사용하시면 됩니다.

```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <example-api>        # 배포할 deployment의 이름을 작성합니다.
  namespace: <example-namespaces>   # deployment와 deployment를 통해 배포될 replicaset, pod가 생성될 ns 이름을 작성합니다.
spec:
  replicas: 2                       # 배포할 Pod 개수를 지정해줍니다. 저는 일단 2개로 진행했습니다. 
  selector:                         # deployment가 관리할 pod를 찾는 법을 정의 하는 곳입니다.
    matchLabels:
      app: <example-api>       # pod Label을 정의해줍니다. 정확히는 template의 labels를 적어줍니다.
  template:
    metadata:
      labels:
        app: <example-api>     # selector는 template.metadata.labels.app 을 보고 pod를 찾습니다.
    spec:
      dnsPolicy: Default
      containers:
      - image: <1234567.dkr.ecr.ap-northeast-2.amazonaws.com/qwer:1234>  # pod를 만들 이미지를 정의합니다.
        name: <example-api>     # 생성될 pod 이름을 정의해줍니다.
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: SPRING_PROFILES_ACTIVE         # 이 부분은 SPRING BOOT 에서 사용하는 Profile 환경변수 입니다
          value: prod                          # 사용하는 환경에 맞게 변경합니다(dev, test, prod)
---
apiVersion: v1
kind: Service
metadata:
  name: <example-svc>           # service 이름을 작성합니다.
  namespace: <example-namespaces>    # service가 생성될 ns 이름을 작성합니다.
  annotations:
    alb.ingress.kubernetes.io/healthcheck-path: "/aws/health"        # alb health check 경로입니다. aws alb annotation 관련 문서 참조
spec:
  ports:
  - port: 8080
    name: http
    protocol: TCP
    targetPort: 8080
  selector:
    app: <example-api>    # service 가 연결될 pod를 정의합니다.
  type: NodePort                # type에 관해서는 여러 type이 있는데 꼭 찾아보시길 바랍니다. 
                                # 저희는 앞단에 ingress로 alb를 붙여 사용하기 때문에 NodePort 방식을 사용합니다

```

[service type 관련 참고 번역글](https://blog.leocat.kr/notes/2019/08/22/translation-kubernetes-nodeport-vs-loadbalancer-vs-ingress)


`kubectl apply -f 4-kcl-api.yaml`

배포는 위의 명령어로 실행하시면 됩니다.

실행 후 Lens나 `kubetl get pods -n <example-namespaces>`pod가 정상적으로 올라오시는지 확인하시면 됩니다.


### 6. ingress 배포

ingress의 경우 internal 로 띄울지 external로 띄울지에 따라 설정이 다르므로 밑에서 나누어 설명드리겠습니다.

**\*\*\* 도메인 설정 관련 내용이 포함되어 있어, 설명 숙지 도중에 계정 정보에 혼돈이 오지 않도록 꼭! 주의하시길 바랍니다**

# Ingress 배포 및 도메인 설정

## A. EXTERNAL INGRESS

### 1. external ingress 배포

**\*\*\*(문서 이름이 일괄로 internal로 되어 있는 점은 양해 부탁드립니다..^^;**
**혼돈이 오실까 싶어 설명도 5-ingress-interal.yaml 로 진행합니다..사용하실 때 혼동 없이 파일 이름도 변경하시고 annotation 확인하시며 사용하시면 감사드립니다.)**

업무 진행 시, 두번의 파일 수정이 필요함으로 혼동이 없으시길 바랍니다.

먼저 가장 기본 setting 의 ingress를 올려줍니다.

aws-load-balancer-controller에 의해 생성되는 lb의 경우 ingress의 annotations를 참조하여 lb를 생성하기 때문에 annotation 작성이 중요합니다.

수정하셔야 하는 부분들은 `<꺽쇠 괄호>` 와 주석으로 설명 및 표시해 두겠습니다. **괄호까지 없애시고 수정**하셔서 사용하시면 됩니다.


`5-ingress-internal.yaml`
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: "ingress-<example-api>"        # 생성될 ingress의 이름입니다.
  namespace: <example-namespaces>           # ingress가 생성될 namespace를 정의합니다.
  annotations:
    alb.ingress.kubernetes.io/load-balancer-attributes: routing.http.drop_invalid_header_fields.enabled=true,deletion_protection.enabled=true
    alb.ingress.kubernetes.io/scheme: internet-facing      # internet-facing 으로 external alb로 설정합니다.
    alb.ingress.kubernetes.io/security-groups: <example-alb-security-groups>    # 미리 생성해둔 alb sg를 적습니다.
    alb.ingress.kubernetes.io/subnets: subnet-1234abcde, subnet-qwer1234 # external의 경우 igw가 붙어있는 alb대역의 subnet을 적습니다
                                                                          # (alb 대역 32bit 변경 작업이 됐는지 확인 하여 진행)
    alb.ingress.kubernetes.io/target-type: ip
    kubernetes.io/ingress.class: alb
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: "<example-svc>"  # ingress는 service를 바라보기 때문에 ingress가 바라보는 service를 적어줍니다.
                port:
                  number: 8080

```

`kubectl apply -f 5-ingress-internal.yaml`

명령을 통해 ingress가 잘 올라오는지 확인합니다. (잘 만들어지지 않아서 삭제해야하는 경우 문서 하단을 참고하십시오.)

Lens의 Network/Ingress 의 LoadBalancers에 AWS LB의 DNS Name이 바로 나오면 성공입니다.

`kubectl get ingress -n api`

명령어로 조회 할 경우

```
NAME                                CLASS  HOSTS  ADDRESS                                                               PORTS     AGE
ingress-example-internal-api   <none>   *    abcd-k8s-api-ingressd-123aa-123.ap-northeast-2.elb.amazonaws.com   80      4m24s
```

위와 같이 ADDRESS가 조회되면 성공입니다.

### 2. 도메인 등록하기

**작업계정: `kcl-root`<=도메인 작업 계정**

만들어진 LB의 DNS Name을 복사합니다.(콘솔에서 하셔도 되고 명령어로 나온 ADDRESS나 Lens에서 보이는 Load-Balancer Ingress Points의 Hostname을 복사하셔도 값은 같습니다.)

사용하는 도메인을 복사합니다.

`kcl-root` 계정의 route53에 등록되어있는 도메인을 선택 후  `CNAME` Record를 등록해줍니다.

Sheet에 있는 **도메인을 Record name**으로 적고 **Value에 생성된 LB의 DNS name**을 적어줍니다.

`TTL을 60초`로 설정하여 빠른 설정이 가능하도록 합니다


### 3. ACM 생성하기

**작업계정: `작업하는 클러스터에 해당하는 계정의 seoul 리전`**

작업하는 클러스터에 해당하는 계정의 서울리전에 ACM을 만들어 줍니다.

ACM 생성 시, 입력하는 도메인에는 방금 전 도메인 등록 시 입력했던 `도메인`을 입력해줍니다.

참고로 저는 주로 tag에  `{ Name : example-acm }` 을 달아주며 작업을 진행했습니다.

생성을 하고 ACM은 `Pending` 상태인데요, 만든 ACM을 클릭하여 `CNAME name` `CNAME value` 를 복사합니다.


### 4. ACM CNAME 도메인 등록하기

**작업계정: `kcl-root`**

위에서 했던 도메인 작업과 마찬가지로,

`kcl-root` 계정의 route53에 등록되어있는 도메인을 선택 후  `CNAME` Record를 등록해줍니다.

방금 ACM에서 복사해둔 `CNAME name` `CNAME value`  등록해 줄겁니다.

**CNAME name 을 Record name**으로 적고 **Value에 CNAME value**를 적어줍니다.

TTL은 마찬가지로 60으로 해두고 몇 분 정도 기다리면 ACM이 `Issued`상태로 사용할 수 있도록 변경된것을 확인 가능합니다.

`작업하는 클러스터에 해당하는 계정의 seoul 리전` 의 계정에서 완성된 ACM의 arn 값을 복사해둡니다.


### 5. ingress 수정하기

ingress를 수정해 배포한 lb가 인증서를 통해 https 통신을 하도록 annotation을 추가해줍니다.

수정하셔야 하는 부분들은 `<꺽쇠 괄호>` 와 주석으로 설명 및 표시해 두겠습니다. **괄호까지 없애시고 수정**하셔서 사용하시면 됩니다.


`5-ingress-internal.yaml`

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: "ingress-<example-api>"        # 생성될 ingress의 이름입니다.
  namespace: <example-namespaces>           # ingress가 생성될 namespace를 정의합니다.
  annotations:
    alb.ingress.kubernetes.io/load-balancer-attributes: routing.http.drop_invalid_header_fields.enabled=true,deletion_protection.enabled=true
    alb.ingress.kubernetes.io/scheme: internet-facing      # internet-facing 으로 external alb로 설정합니다.
    alb.ingress.kubernetes.io/security-groups: <example-alb-security-groups>    # 미리 생성해둔 alb sg를 적습니다.
    alb.ingress.kubernetes.io/subnets: subnet-1234abcde, subnet-qwer1234 # external의 경우 igw가 붙어있는 alb대역의 subnet을 적습니다
                                                                          # (alb 대역 32bit 변경 작업이 됐는지 확인 하여 진행)
    alb.ingress.kubernetes.io/target-type: ip
    kubernetes.io/ingress.class: alb
    #========================================추가 된 부분========================================#
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-northeast-2:1234:certificate/12-abc-123   # 복사한 ACM의 arn을 입력합니다.
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}, {"HTTPS":443}]'    # listener port 를 정의합니다.
    alb.ingress.kubernetes.io/ssl-redirect: '443'    # redirect port 를 정의 합니다.
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: "<example-svc>"  # ingress는 service를 바라보기 때문에 ingress가 바라보는 service를 적어줍니다.
                port:
                  number: 8080

```

`kubectl apply -f 5-ingress-internal.yaml` 

명령어를 실행시켜 ingress를 수정시켜줍니다.
잘 적용되었는지 확인 해 줍니다.



## B. INTERNAL INGRESS

### 1. internal ingress 배포

먼저 가장 기본 setting 의 ingress를 올려줍니다.

aws-load-balancer-controller에 의해 생성되는 lb의 경우 ingress의 annotations를 참조하여 lb를 생성하기 때문에 annotation 작성이 중요합니다.

수정하셔야 하는 부분들은 `<꺽쇠 괄호>` 와 주석으로 설명 및 표시해 두겠습니다. **괄호까지 없애시고 수정**하셔서 사용하시면 됩니다.


`5-ingress-internal.yaml`
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: "ingress-<example-api>"        # 생성될 ingress의 이름입니다.
  namespace: <example-namespaces>           # ingress가 생성될 namespace를 정의합니다.
  annotations:
    alb.ingress.kubernetes.io/load-balancer-attributes: routing.http.drop_invalid_header_fields.enabled=true,deletion_protection.enabled=true
    alb.ingress.kubernetes.io/scheme: internal      # internal 으로 internal alb로 설정합니다.
    alb.ingress.kubernetes.io/security-groups: <example-alb-security-groups>    # 미리 생성해둔 alb sg를 적습니다.
    alb.ingress.kubernetes.io/subnets: subnet-1234abcde, subnet-qwer1234 # internal의 경우 eks대역의 subnet을 적습니다
                                                                    # (alb 대역 32bit 변경 작업이 됐는지 확인 하여 진행)
    alb.ingress.kubernetes.io/target-type: ip
    kubernetes.io/ingress.class: alb
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: "<example-svc>"  # ingress는 service를 바라보기 때문에 ingress가 바라보는 service를 적어줍니다.
                port:
                  number: 8080

```

`kubectl apply -f 5-ingress-internal.yaml`

명령을 통해 ingress가 잘 올라오는지 확인합니다. (잘 만들어지지 않아서 삭제해야하는 경우 문서 하단을 참고하십시오.)

Lens의 Network/Ingress 의 LoadBalancers에 AWS LB의 DNS Name이 바로 나오면 성공입니다.

`kubectl get ingress -n api`

명령어로 조회 할 경우

```
NAME                                CLASS  HOSTS  ADDRESS                                                               PORTS     AGE
ingress-example-internal-api   <none>   *    internal-k8s-api-ingressd-123aa-123.ap-northeast-2.elb.amazonaws.com   80      4m24s
```

위와 같이 ADDRESS가 조회되면 성공입니다.


### 2. VPC ASSOCIATED

**작업계정: `kcl-root`** , 개인 터미널

internal 도메인의 경우 사전 작업이 필요합니다.

등록할 VPC 를 Associated 해주어야 하는데 해당 작업을 쉽게 해주는 스크립트를 상기님께서 만들어 놓으셔서

k8s/bsg_tools  repository 의  `associate-vpc-with-hosted-zone.sh` 파일에서

```
profile_list=$(aws-vault list --profiles | grep ^kis- | sort)
```

이 부분을 본인의 상황에 맞게 커스텀하여 사용하시면 간편하게 등록하실 수 있습니다! (상기님 감사합니다!)

작업하는 클러스터와 lb가 있는 VPC의 id 와 `kcl-root` 의 해당 도메인의 `Hosted zone ID` 를 가져와 입력하여 등록하여 Associated 해줍니다.


### 3. local domain 등록

**작업계정: `kcl-root`**

만들어진 LB의 DNS Name을 복사합니다.(콘솔에서 하셔도 되고 명령어로 나온 ADDRESS나 Lens에서 보이는 Load-Balancer Ingress Points의 Hostname을 복사하셔도 값은 같습니다.)

`AWS Enterprise architecture & Schedule` 문서의 `VPC별 App 및 도메인` Sheet 를 참고하시어 도메인을 복사합니다.

`kcl-root` 계정의 route53에 등록되어있는 도메인을 선택 후  `CNAME` Record를 등록해줍니다.

Sheet에 있는 **도메인을 Record name**으로 적고 **Value에 생성된 LB의 DNS name**을 적어줍니다.

`TTL을 60초`로 설정하여 빠른 설정이 가능하도록 합니다


## 연결 Test 하기

제대로 구축했는지 확인해봅니다.

telnet이 설치 되어 있는 CentOS 이미지로 Pod를 하나 올려, 해당 Pod 내부에서 telnet을 통한 port 조회가 되는지 확인합니다.

어디서 어떤 port를 확인 해야 하는 지는 **slack에 있는 구성도**를 참고하시길 바랍니다.

먼저 CentOS deployment를 하나만 띄웁니다.

위에서도 deployment가 나왔으므로 주석은 달지 않겠습니다.

namespaces의 경우에는 일단 default로 해 두었지만, 따로 test_mzc나 kcl_test 와 같이 따로 만들어 사용하셔도 됩니다..

수정하셔야 하는 부분들은 `<꺽쇠 괄호>` 와 주석으로 설명 및 표시해 두겠습니다. **괄호까지 없애시고 수정**하셔서 사용하시면 됩니다.

```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <example-api-centos>
  namespace : <default>
spec:
  replicas: 1
  selector:
    matchLabels:
      app: <example-api-centos>
  template:
    metadata:
      labels:
        app: <example-api-centos>
    spec:
      containers:
      - image: 0123456789.dkr.ecr.ap-northeast-2.amazonaws.com/centos:latest
        command: ["/bin/sh", "-c", "sleep 86400"]
        name: <example-api-centos>
        imagePullPolicy: Always
      dnsPolicy: Default

```

해당 Pod 내부로 접속합니다. 

명령어로는

`kubectl exec -it <Pod이름> /bin/bash`

라고 입력하면 해당 Pod 내부에서 bash shell로 명령어 질의를 할 수 있습니다.

  `-i` 옵션은  `--stdin` 으로 STDIN 표준 입출력을 사용하겠다. 라는 의미이고 

  `-t` `--tty` 로 STDIN에서 terminal을 사용하겠다. 라는 의미로 /bin/bash를 지정해줍니다.

`Lens`에서는 Pod를 클릭하면 나오는 Pod 상세 정보의 상단바 아이콘의 두번째 아이콘을 보면 `터미널 모양의 아이콘`이 있는데,

그 아이콘을 클릭해주면 Pod로 접속하는 터미널이 열리게 됩니다.

이제 준비가 되었습니다!

telnet 명령어로 질의를 해서 포트 확인을 해보면 됩니다!

### 삭제하기

삭제는

`kubectl delete -f 5-ingress-internal.yaml`

`kubectl delete -f 4-kcl-api.yaml`

다음과 같은 명령어로 해주시면 됩니다.


**\*\*\* namespace를 지워야 하는 경우가 있다면 아무것도 올라가 있지 않은지 신중하게 확인 후 삭제 하시길 바랍니다.**


### 추가

*Ingress가 제대로 설정되지 않아 삭제해야 하는데 지워지지 않는 경우*

`kubectl patch [ingress 이름] -n [namespace 이름] -p '{"metadata":{"finalizers":[]}}' --type=merge`

해당 명령어 수행 후 삭제를 해보시길 바랍니다.

lb를 생성하는 ingress의 경우 aws의 리소스가 삭제되지 않을경우 지워지지 않도록 `finalizers(종료자)` 설정이 되어있습니다.

위의 명령어는 해당 설정을 지워주는 명령어 입니다.


**참고) ingress의 finalizers 설정이 되어있는 모습

```
finalizers:
  - ingress.k8s.aws/resources
```


6번 파일의 경우 centos deployment인데 test용도로 추후 수정해서 사용 예정입니다.

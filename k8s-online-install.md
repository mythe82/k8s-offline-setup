# k8s kubespray install (non-air-gapped)

## 1. infra 구성
### 1.1. VM 준비
GCP GCE 2대 생성하여 VM 구성
* controller-1
  - 머신 유형 e2-medium (vCPU 2개, 메모리 4GB)
  - 200GB 표준 영구 디스크
  - 이미지 ubuntu-2204-jammy-v20250508

* worker-1
  - 머신 유형 e2-medium (vCPU 2개, 메모리 4GB)
  - 100GB 표준 영구 디스크
  - 이미지 ubuntu-2204-jammy-v20250508

 * GCP VPC 생성
Cloud Shell 터미널에서 명령어 실행
```Cloud Shell
mythe82@cloudshell:~ (malee-457606)$ gcloud compute networks create kubernetes-the-kubespray-way --subnet-mode custom
Created [https://www.googleapis.com/compute/v1/projects/malee-457606/global/networks/kubernetes-the-kubespray-way].
NAME: kubernetes-the-kubespray-way
SUBNET_MODE: CUSTOM
BGP_ROUTING_MODE: REGIONAL
IPV4_RANGE: 
GATEWAY_IPV4: 
INTERNAL_IPV6_RANGE: 
```

* GCP VPC subnet 생성
```Cloud Shell
mythe82@cloudshell:~ (malee-457606)$ gcloud compute networks subnets create kubernetes \
  --network kubernetes-the-kubespray-way \
  --range 10.240.0.0/24
  --region asia-east1
Did you mean region [asia-east1] for subnetwork: [kubernetes] (Y/n)?  y

Created [https://www.googleapis.com/compute/v1/projects/malee-457606/regions/asia-east1/subnetworks/kubernetes].
NAME: kubernetes
REGION: asia-east1
NETWORK: kubernetes-the-kubespray-way
RANGE: 10.240.0.0/24
STACK_TYPE: IPV4_ONLY
IPV6_ACCESS_TYPE: 
INTERNAL_IPV6_PREFIX: 
EXTERNAL_IPV6_PREFIX: 
```

* GCP 네트워크 방화벽 규칙 생성
```Cloud Shell
# 모든 프로토콜에서 내부 통신을 허용
mythe82@cloudshell:~ (malee-457606)$ gcloud compute firewall-rules create kubernetes-the-kubespray-way-allow-internal \
  --allow tcp,udp,icmp,ipip \
  --network kubernetes-the-kubespray-way \
  --source-ranges 10.240.0.0/24

Creating firewall...working..Created [https://www.googleapis.com/compute/v1/projects/malee-457606/global/firewalls/kubernetes-the-kubespray-way-allow-internal].
Creating firewall...done.                                                      
NAME: kubernetes-the-kubespray-way-allow-internal
NETWORK: kubernetes-the-kubespray-way
DIRECTION: INGRESS
PRIORITY: 1000
ALLOW: tcp,udp,icmp,ipip
DENY: 
DISABLED: False
```

```Cloud Shell
# 외부 SSH, ICMP 및 HTTPS를 허용
gcloud compute firewall-rules create kubernetes-the-kubespray-way-allow-external \
  --allow tcp:80,tcp:6443,tcp:443,tcp:22,icmp \
  --network kubernetes-the-kubespray-way \
  --source-ranges 0.0.0.0/0

Creating firewall...working..Created [https://www.googleapis.com/compute/v1/projects/malee-457606/global/firewalls/kubernetes-the-kubespray-way-allow-external].
Creating firewall...done.                                                      
NAME: kubernetes-the-kubespray-way-allow-external
NETWORK: kubernetes-the-kubespray-way
DIRECTION: INGRESS
PRIORITY: 1000
ALLOW: tcp:80,tcp:6443,tcp:443,tcp:22,icmp
DENY: 
DISABLED: False
```

* GCE VM 생성
```Cloud Shell
# master node
mythe82@cloudshell:~ (malee-457606)$ for i in 1; do
  gcloud compute instances create controller-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20250508 \
    --machine-type e2-medium \
    --private-network-ip 10.240.0.1${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-kubespray-way,controller \
    --zone=asia-east1-b
done
```

```Cloud Shell
# worker node
mythe82@cloudshell:~ (malee-457606)$ for i in 1; do
  gcloud compute instances create worker-${i} \
    --async \
    --boot-disk-size 100GB \
    --can-ip-forward \
    --image projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20250508 \
    --machine-type e2-medium \
    --private-network-ip 10.240.0.2${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-kubespray-way,controller \
    --zone=asia-east1-b
done
```

```Cloud Shell
# 생성 VM 확인
mythe82@cloudshell:~ (malee-457606)$ gcloud compute instances list --filter="tags.items=kubernetes-the-kubespray-way"
NAME: controller-1
ZONE: asia-east1-b
MACHINE_TYPE: e2-medium
PREEMPTIBLE: 
INTERNAL_IP: 10.240.0.11
EXTERNAL_IP: 35.194.185.196
STATUS: RUNNING

NAME: worker-1
ZONE: asia-east1-b
MACHINE_TYPE: e2-medium
PREEMPTIBLE: 
INTERNAL_IP: 10.240.0.21
EXTERNAL_IP: 34.80.42.10
STATUS: RUNNING
```

### 1.2. OS PKG 구성 및 설정
* node hosts 설정
```bash
mythe82@controller-1:~$ sudo vi /etc/hosts
10.240.0.11 controller-1 ct01
10.240.0.21 worker-1 wk01
```

* 원격 명령을 위해 자동 login 설정 - SSH key 교환
```bash
mythe82@controller-1:~$ ssh-keygen -t rsa -b 2048
[enter]
[enter]
[enter]
```
GCP 메타데이터에 SSH 키 추가 GCP의 SSH 키 관리는 메타데이터에서 이루어집니다. 사전에 SSH 키를 GCP 메타데이터에 추가하여 인스턴스 재부팅 후에도 유지되도록 설정합니다.
1. **GCP 콘솔에서 이동**:
   - GCP 프로젝트 > **Compute Engine** > **VM 인스턴스**로 이동합니다.
2. **해당 인스턴스 선택**:
   - SSH 키를 추가할 인스턴스를 선택합니다.
3. **편집(Edit) 버튼 클릭**:
   - 상단의 **편집(Edit)** 버튼을 클릭합니다.
4. **SSH 키 추가**:
   - **SSH 키** 섹션에서 공개 키(`id_rsa.pub`)를 추가합니다.
   - 아래 명령을 사용하여 공개 키를 확인하고 복사합니다:
     ```bash
     cat ~/.ssh/id_rsa.pub
     ```
5. **저장**:
   - 변경 사항을 저장합니다.

```bash
mythe82@controller-1:~$ ssh-copy-id ct01
[yes]
mythe82@controller-1:~$ ssh-copy-id wk01
[yes]
```

### 1.3. install docker - skip하고 해보기
```bash
# 우분투 시스템 패키지 업데이트
mythe82@controller-1:~$ sudo uname -a
Linux controller-1 6.8.0-1029-gcp #31~22.04.1-Ubuntu SMP Mon Apr 21 06:39:59 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux

mythe82@controller-1:~$ sudo apt-get update
mythe82@controller-1:~$ sudo uname -a
Linux controller-1 6.8.0-1029-gcp #31~22.04.1-Ubuntu SMP Mon Apr 21 06:39:59 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux

# 필요한 패키지 설치
mythe82@controller-1:~$ sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common

# Docker의 공식 GPG키를 추가
mythe82@controller-1:~$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Docker의 공식 apt 저장소를 추가
mythe82@controller-1:~$ sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
mythe82@controller-1:~$ sudo apt-get update

# Docker 설치
mythe82@controller-1:~$ sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Docker 설치 확인
mythe82@controller-1:~$ sudo systemctl status docker
mythe82@controller-1:~$ docker --version
Docker version 28.1.1, build 4eba377

mythe82@controller-1:~$ sudo usermod -aG docker $USER
mythe82@controller-1:~$ newgrp docker
```

## 2. install ansible
```bash
mythe82@controller-1:~$ cd
mythe82@controller-1:~$ sudo apt install -y python3.10-venv build-essential python3-dev
mythe82@controller-1:~$ python3 -m venv kubespray-venv
mythe82@controller-1:~$ source ~/kubespray-venv/bin/activate
(kubespray-venv) mythe82@controller-1:~$ git clone https://github.com/kubernetes-sigs/kubespray.git
(kubespray-venv) mythe82@controller-1:~$ cd kubespray
(kubespray-venv) mythe82@controller-1:~/kubespray$ pip install -U -r requirements.txt
```

## 3. install kubernetes cluster
```bash
(kubespray-venv) mythe82@controller-1:~/kubespray$ cp -rp ~/kubespray/inventory/sample ~/kubespray/inventory/mycluster
(kubespray-venv) mythe82@controller-1:~/kubespray$ vi ~/kubespray/inventory/mycluster/inventory.ini 
[all]
controller-1 ansible_host=controller-1  ip=10.240.0.11
worker-1 ansible_host=worker-1  ip=10.240.0.21

[kube_control_plane]
controller-1

[etcd]
controller-1

[kube_node]
worker-1

[calico_rr]

[k8s_cluster:children]
kube_control_plane
kube_node
calico_rr

(kubespray-venv) mythe82@controller-1:~/kubespray$ ansible-playbook -i ~/kubespray/inventory/mycluster/inventory.ini -u mythe82 -b -v --private-key=~/.ssh/id_rsa ~/kubespray/cluster.yml
(kubespray-venv) mythe82@controller-1:~/kubespray$ sudo chown -R mythe82:mythe82 /etc/kubernetes/admin.conf
(kubespray-venv) mythe82@controller-1:~/kubespray$ cp /etc/kubernetes/admin.conf kubespray-do.conf
(kubespray-venv) mythe82@controller-1:~/kubespray$ export KUBECONFIG=$PWD/kubespray-do.conf
(kubespray-venv) mythe82@controller-1:~/kubespray$ kubectl get nodes
NAME           STATUS   ROLES           AGE   VERSION
controller-1   Ready    control-plane   22m   v1.32.5
worker-1       Ready    <none>          21m   v1.32.5


```





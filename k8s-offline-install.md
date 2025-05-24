# k8s-offline-setup

## 1. 온라인 환경에서 필요한 이미지 및 파일 수집
### 1.1. 컨테이너 이미지 리스트 생성
Kubespray 루트 디렉터리에서 아래 스크립트를 실행해 필요한 이미지 리스트와 파일 리스트를 생성합니다.

```bash
mythe82@k8s-controller-1:~$ source ~/kubespray-venv/bin/activate
(kubespray-venv) mythe82@k8s-controller-1:~$ cd kubespray/contrib/offline/
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray/contrib/offline$ ./generate_list.sh -i inventory/mycluster/inventory.ini
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray/contrib/offline$ cd temp/
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray/contrib/offline/temp$ ls
files.list  files.list.template  images.list  images.list.template
```

### 1.2. 이미지 수집
이미지 리스트 파일을 기반으로 오프라인 이미지를 다운로드합니다.

```bash
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray/contrib/offline/temp$ IMAGES_FROM_FILE=temp/images.list
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray/contrib/offline/temp$ cd ..
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray/contrib/offline$ ./manage-offline-container-images.sh create
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray/contrib/offline$ ls -ltr
total 546652
-rwxrwxr-x 1 mythe82 mythe82      1406 May 22 06:41 manage-offline-files.sh
-rwxrwxr-x 1 mythe82 mythe82      7625 May 22 06:41 manage-offline-container-images.sh
-rw-rw-r-- 1 mythe82 mythe82       575 May 22 06:41 generate_list.yml
-rwxrwxr-x 1 mythe82 mythe82      1329 May 22 06:41 generate_list.sh
-rw-rw-r-- 1 mythe82 mythe82        44 May 22 06:41 docker-daemon.json
-rw-rw-r-- 1 mythe82 mythe82      2912 May 22 06:41 README.md
-rwxrwxr-x 1 mythe82 mythe82      2469 May 22 06:41 upload2artifactory.py
-rw-rw-r-- 1 mythe82 mythe82       189 May 22 06:41 registries.conf
-rw-rw-r-- 1 mythe82 mythe82      1186 May 22 06:41 nginx.conf
drwxrwxr-x 2 mythe82 mythe82      4096 May 22 08:17 temp
-rw-rw-r-- 1 mythe82 mythe82 559721189 May 22 08:27 container-images.tar.gz
```

## 2. 오프라인용 파일 수집
파일 리스트에 따라 오프라인 설치에 필요한 파일을 다운로드하고, nginx 컨테이너로 파일 서버를 만듭니다.

```bash
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray/contrib/offline$ ./manage-offline-files.sh
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray/contrib/offline$ ls -ltr
total 1448628
-rwxrwxr-x 1 mythe82 mythe82      1406 May 22 06:41 manage-offline-files.sh
-rwxrwxr-x 1 mythe82 mythe82      7625 May 22 06:41 manage-offline-container-images.sh
-rw-rw-r-- 1 mythe82 mythe82       575 May 22 06:41 generate_list.yml
-rwxrwxr-x 1 mythe82 mythe82      1329 May 22 06:41 generate_list.sh
-rw-rw-r-- 1 mythe82 mythe82        44 May 22 06:41 docker-daemon.json
-rw-rw-r-- 1 mythe82 mythe82      2912 May 22 06:41 README.md
-rwxrwxr-x 1 mythe82 mythe82      2469 May 22 06:41 upload2artifactory.py
-rw-rw-r-- 1 mythe82 mythe82       189 May 22 06:41 registries.conf
-rw-rw-r-- 1 mythe82 mythe82      1186 May 22 06:41 nginx.conf
drwxrwxr-x 2 mythe82 mythe82      4096 May 22 08:17 temp
-rw-rw-r-- 1 mythe82 mythe82 559721189 May 22 08:27 container-images.tar.gz
drwxrwxr-x 6 mythe82 mythe82      4096 May 22 08:37 offline-files
-rw-rw-r-- 1 mythe82 mythe82 923613797 May 22 08:38 offline-files.tar.gz
```

## 3. infra 구성
### 3.1. VM 준비
GCP GCE 2대 생성하여 VM 구성
* k8s-controller-1
  - 머신 유형 e2-medium (vCPU 2개, 메모리 4GB)
  - 200GB 표준 영구 디스크
  - 이미지 ubuntu-2204-jammy-v20250508

* k8s-worker-1
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
  --range 10.178.0.0/24 \
  --region asia-northeast3

Created [https://www.googleapis.com/compute/v1/projects/malee-457606/regions/asia-northeast3/subnetworks/kubernetes].
NAME: kubernetes
REGION: asia-northeast3
NETWORK: kubernetes-the-kubespray-way
RANGE: 10.178.0.0/24
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
  --source-ranges 10.178.0.0/24

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
mythe82@cloudshell:~ (malee-457606)$ gcloud compute firewall-rules create kubernetes-the-kubespray-way-allow-external \
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
  gcloud compute instances create k8s-controller-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20250508 \
    --machine-type e2-standard-2 \
    --private-network-ip 10.178.0.1${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-kubespray-way,controller \
    --zone=asia-northeast3-a
done
```

```Cloud Shell
# worker node
mythe82@cloudshell:~ (malee-457606)$ for i in 1; do
  gcloud compute instances create k8s-worker-${i} \
    --async \
    --boot-disk-size 100GB \
    --can-ip-forward \
    --image projects/ubuntu-os-cloud/global/images/ubuntu-2204-jammy-v20250508 \
    --machine-type e2-medium \
    --private-network-ip 10.178.0.2${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-kubespray-way,controller \
    --zone=asia-northeast3-a
done
```

```Cloud Shell
# 생성 VM 확인
mythe82@cloudshell:~ (malee-457606)$ gcloud compute instances list --filter="tags.items=kubernetes-the-kubespray-way"
NAME: k8s-controller-1
ZONE: asia-northeast3-a
MACHINE_TYPE: e2-standard-2
PREEMPTIBLE: 
INTERNAL_IP: 10.178.0.11
EXTERNAL_IP: 34.22.106.218
STATUS: RUNNING

NAME: k8s-worker-1
ZONE: asia-northeast3-a
MACHINE_TYPE: e2-medium
PREEMPTIBLE: 
INTERNAL_IP: 10.178.0.21
EXTERNAL_IP: 34.64.70.51
STATUS: RUNNING
```

## 4. 오프라인 환경으로 데이터 이동
위 단계에서 생성된 이미지와 파일(예: temp 디렉터리 전체, 다운로드된 이미지 tar 파일 등)을 오프라인 환경으로 복사합니다.
```bash
mythe82@k8s-controller-1:~$ ls -ltr
-rw-rw-r--  1 mythe82 mythe82 2437876671 May 22 12:32 kubespray-offline.tar.gz

mythe82@k8s-controller-1:~$ tar xvfz kubespray-offline.tar.gz
mythe82@k8s-controller-1:~$ ls -ltr
drwxrwxr-x 18 mythe82 mythe82       4096 May 22 12:24 kubespray
-rw-rw-r--  1 mythe82 mythe82 2437876671 May 22 12:32 kubespray-offline.tar.gz
```

## 5. OS PKG 구성 및 설정
* node hosts 설정
```bash
mythe82@k8s-controller-1:~$ sudo vi /etc/hosts
10.178.0.11 k8s-controller-1 ct01
10.178.0.21 k8s-worker-1 wk01
```

* 원격 명령을 위해 자동 login 설정 - SSH key 교환
```bash
mythe82@k8s-controller-1:~$ ssh-keygen -t rsa -b 2048
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
mythe82@k8s-controller-1:~$ ssh-copy-id ct01
[yes]
mythe82@k8s-controller-1:~$ ssh-copy-id wk01
[yes]
```

* swapoff (모든 노드 실행)
```bash
mythe82@k8s-controller-1:~$ swapoff -a
mythe82@k8s-controller-1:~$ sudo sed -i.bak -r 's/(.+swap.+)/#\1/' /etc/fstab

mythe82@k8s-worker-1:~$ swapoff -a
mythe82@k8s-worker-1:~$ sudo sed -i.bak -r 's/(.+swap.+)/#\1/' /etc/fstab
```

* 네트워크 패킷 라우팅, 보안 정책 iptables 적용 (모든 노드 실행)
```bash
mythe82@k8s-controller-1:~$ echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
mythe82@k8s-controller-1:~$ sudo modprobe br_netfilter

mythe82@k8s-worker-1:~$ echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
mythe82@k8s-worker-1:~$ sudo modprobe br_netfilter
```

* install NFS - 오프라인 파일 준비 방법 보완
```bash
# ct01 노드 실행
mythe82@k8s-controller-1:~$ sudo apt-get install -y nfs-server nfs-common 

# wk01 노드 실행
mythe82@k8s-worker-1:~$ sudo apt-get install -y nfs-common
```

* install docker - 오프라인 파일 준비 방법 보완
```bash
# Docker의 공식 GPG키를 추가
mythe82@controller-1:~$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Docker의 공식 apt 저장소를 추가
mythe82@controller-1:~$ sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Docker 설치
mythe82@controller-1:~$ sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Docker 설치 확인
mythe82@controller-1:~$ sudo systemctl status docker
mythe82@controller-1:~$ docker --version
Docker version 28.1.1, build 4eba377
```

## 5. 오프라인 환경에서 레지스트리 및 파일 서버 구성
### 5.1. 로컬 레지스트리에 이미지 등록
오프라인 환경에서 이미지 파일을 레지스트리에 등록합니다.
```bash
./contrib/offline/manage-offline-container-images.sh register
```
필요하다면 환경변수로 DESTINATION_REGISTRY, REGISTRY_PORT 등을 설정할 수 있습니다.

### 5.2. 파일 서버 실행
오프라인 환경에서 nginx 파일 서버가 실행 중인지 확인합니다. 필요하다면 위의 manage-offline-files.sh 스크립트로 다시 실행합니다.

## 6. install ansible - 오프라인 파일 준비 방법 보완
```bash
mythe82@k8s-controller-1:~$ cd
mythe82@k8s-controller-1:~$ sudo apt update
mythe82@k8s-controller-1:~$ sudo apt install -y python3-venv
mythe82@k8s-controller-1:~$ python3 -m venv kubespray-venv
mythe82@k8s-controller-1:~$ source ~/kubespray-venv/bin/activate
(kubespray-venv) mythe82@k8s-controller-1:~$ cd kubespray
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray$ pip install -U -r requirements.txt
```

## 6. Kubespray로 오프라인 설치 진행
오프라인 환경에서 Kubespray 인벤토리와 설정에 맞게 클러스터 설치를 진행합니다.

필요한 이미지와 파일은 모두 오프라인 환경 내의 로컬 레지스트리와 파일 서버에서 참조됩니다.

### 6.1. install kubernetes cluster
```bash
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray$ vi ~/kubespray/inventory/mycluster/inventory.ini 
[all]
k8s-controller-1 ansible_host=k8s-controller-1  ip=10.178.0.11
k8s-worker-1 ansible_host=k8s-worker-1  ip=10.178.0.21

[kube_control_plane]
k8s-controller-1

[etcd]
k8s-controller-1

[kube_node]
k8s-worker-1

[calico_rr]

[k8s_cluster:children]
kube_control_plane
kube_node
calico_rr

(kubespray-venv) mythe82@k8s-controller-1:~/kubespray$ ansible-playbook -i ~/kubespray/inventory/mycluster/inventory.ini -u mythe82 -b -v --private-key=~/.ssh/id_rsa ~/kubespray/cluster.yml
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray$ ansible all -i ~/kubespray/inventory/mycluster/inventory.ini -u mythe82 -b -a "crictl images"

(kubespray-venv) mythe82@k8s-controller-1:~/kubespray$ sudo chown -R mythe82:mythe82 /etc/kubernetes/admin.conf
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray$ cp /etc/kubernetes/admin.conf kubespray-do.conf
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray$ vi ~/.profile
export KUBECONFIG=$HOME/kubespray/kubespray-do.conf

# alias kubectl to k 
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray$ echo 'alias k=kubectl' >> ~/.bashrc
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray$ echo "alias ka='kubectl apply -f'" >> ~/.bashrc
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray$ echo 'complete -F __start_kubectl k' >> ~/.bashrc
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray$ . ~/.profile 

(kubespray-venv) mythe82@k8s-controller-1:~/kubespray$ kubectl get nodes
NAME               STATUS   ROLES           AGE     VERSION
k8s-controller-1   Ready    control-plane   5m21s   v1.32.5
k8s-worker-1       Ready    <none>          4m31s   v1.32.5
```

### 6.2. deployment test
```bash
(kubespray-venv) mythe82@k8s-controller-1:~$ vi nginx-test.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080

(kubespray-venv) mythe82@k8s-controller-1:~$ kubectl apply -f nginx-test.yaml
(kubespray-venv) mythe82@k8s-controller-1:~$ k get po
NAME                              READY   STATUS    RESTARTS   AGE
nginx-deployment-96b9d695-fn45s   1/1     Running   0          3m48s

(kubespray-venv) mythe82@k8s-controller-1:~$ k get svc nginx-service 
NAME            TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
nginx-service   NodePort   10.233.1.159   <none>        80:30080/TCP   4m5s
```





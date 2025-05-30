# k8s kubespray install (non-air-gapped)

## 1. infra 구성
### 1.1. VM 준비
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

### 1.2. OS PKG 구성 및 설정
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

* install NFS
```bash
# ct01 노드 실행
mythe82@k8s-controller-1:~$ sudo apt-get install -y nfs-server nfs-common rpcbind portmap

# 공유할 directory 생성
mythe82@k8s-controller-1:~$ sudo mkdir -p /mnt/k8s-nfs
mythe82@k8s-controller-1:~$ sudo chmod -R 777 /mnt/k8s-nfs
mythe82@k8s-controller-1:~$ sudo chown -R 1001.1001 /mnt/k8s-nfs

# 공유할 디렉터리 경로와 현재 사용하고 있는 서버 인스턴스의 서브넷 범위를 지정
mythe82@k8s-controller-1:~$ echo '/mnt/k8s-nfs 10.178.0.0/24(rw,sync,no_root_squash,no_subtree_check)' | sudo tee -a /etc/exports
/mnt/k8s-nfs 10.178.0.0/24(rw,sync,no_root_squash,no_subtree_check)

# 설정을 적용하고 서비스를 재시작
mythe82@k8s-controller-1:~$ sudo exportfs -ra
mythe82@k8s-controller-1:~$ sudo systemctl restart nfs-server

# wk01 노드 실행
mythe82@k8s-worker-1:~$ sudo apt-get install -y nfs-common
mythe82@k8s-worker-1:~$ showmount -e 10.178.0.11
Export list for 10.178.0.11:
/mnt/k8s-nfs 10.178.0.0/24
```

## 2. install ansible
```bash
mythe82@k8s-controller-1:~$ cd
mythe82@k8s-controller-1:~$ sudo apt update
mythe82@k8s-controller-1:~$ sudo apt install python3-venv
mythe82@k8s-controller-1:~$ python3 -m venv kubespray-venv
mythe82@k8s-controller-1:~$ source ~/kubespray-venv/bin/activate
(kubespray-venv) mythe82@k8s-controller-1:~$ git clone https://github.com/kubernetes-sigs/kubespray.git
(kubespray-venv) mythe82@k8s-controller-1:~$ cd kubespray
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray$ pip install -U -r requirements.txt
```

## 3. install kubernetes cluster
```bash
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray$ cp -rp ~/kubespray/inventory/sample ~/kubespray/inventory/mycluster
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

## 4. deployment test
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

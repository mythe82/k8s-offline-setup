# k8s kubespray install (non-air-gapped)

## 1. infra 구성
### 1.1. VM 준비
GCP GCE 2대 생성하여 VM 구성
* k8s-ctp01
  - 머신 유형 e2-medium (vCPU 2개, 메모리 4GB)
  - 200GB 표준 영구 디스크
  - 이미지 ubuntu-2204-jammy-v20250508

* k8s-wkn01
  - 머신 유형 e2-medium (vCPU 2개, 메모리 4GB)
  - 100GB 표준 영구 디스크
  - 이미지 ubuntu-2204-jammy-v20250508

### 1.2. OS PKG 구성 및 설정
* node hosts 설정
```bash
mythe82@k8s-ctp01:~$ sudo vi /etc/hosts
10.142.0.6 k8s-ctp01 cp01
10.142.0.7 k8s-wkn01 wk01
```

* 원격 명령을 위해 자동 login 설정 - SSH key 교환
```bash
mythe82@k8s-ctp01:~$ ssh-keygen -t rsa -b 2048
Generating public/private rsa key pair.
Enter file in which to save the key (/home/mythe82/.ssh/id_rsa): 
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /home/mythe82/.ssh/id_rsa
Your public key has been saved in /home/mythe82/.ssh/id_rsa.pub
The key fingerprint is:
SHA256:VkNo1oFOstjDcPOky/VMFFFjCqAbJhDS12PKrWG4c4I mythe82@k8s-ctp01
The key's randomart image is:
+---[RSA 2048]----+
|+o   ....+==+    |
|... o.B Booo .   |
|  .++X & .+      |
|  .o*oB +...     |
| . o.+ +S+       |
|E + o o.  o      |
|   +             |
|                 |
|                 |
+----[SHA256]-----+


```

* GCP 메타데이터에 SSH 키 추가 GCP의 SSH 키 관리는 메타데이터에서 이루어집니다. SSH 키를 GCP 메타데이터에 추가하여 인스턴스 재부팅 후에도 유지되도록 설정합니다.
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

### 1.3. docker install
```bash
# 우분투 시스템 패키지 업데이트
mythe82@k8s-ctp01:~$ sudo apt-get update

# 필요한 패키지 설치
mythe82@k8s-ctp01:~$ sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common

# Docker의 공식 GPG키를 추가
mythe82@k8s-ctp01:~$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Docker의 공식 apt 저장소를 추가
mythe82@k8s-ctp01:~$ sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
mythe82@k8s-ctp01:~$ sudo apt-get update

# Docker 설치
mythe82@k8s-ctp01:~$ sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Docker 설치 확인
mythe82@k8s-ctp01:~$ sudo systemctl status docker
mythe82@k8s-ctp01:~$ docker --version
Docker version 28.1.1, build 4eba377

mythe82@k8s-ctp01:~$ sudo usermod -aG docker $USER
mythe82@k8s-ctp01:~$ newgrp docker
```

## 2. kubespray install
```bash
root@87301a6af9e8:~# pwd
/root

root@mal-k8s-prx:~# git clone https://github.com/kubernetes-sigs/kubespray.git
root@mal-k8s-prx:~# ssh-keygen -t rsa
root@mal-k8s-prx:~# docker run --rm -it --mount type=bind,source="$(pwd)"/kubespray/inventory/sample,dst=/inventory   --mount type=bind,source="${HOME}"/.ssh/id_rsa,dst=/root/.ssh/id_rsa   quay.io/kubespray/kubespray:v2.27.0 bash
root@0188f0719dd4:/kubespray# ansible-playbook -i /kubespray/inventory/sample/inventory.ini --private-key /root/.ssh/id_rsa cluster.yml

```

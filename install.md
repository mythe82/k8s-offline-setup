# k8s kubespray install (non-air-gapped)

## 1. infra 구성

### 1.1. VM 준비
GCP GCE 2대 생성하여 VM 구성
* k8s-ctp01
  - 머신 유형 e2-medium (vCPU 2개, 메모리 4GB)
  - 200GB 표준 영구 디스크
  - 이미지 ubuntu-2204-jammy-v20250508


- docker install
```bash
# 우분투 시스템 패키지 업데이트
sudo apt-get update

# 필요한 패키지 설치
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common

# Docker의 공식 GPG키를 추가
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Docker의 공식 apt 저장소를 추가
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# 시스템 패키지 업데이트
sudo apt-get update

# Docker 설치
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Docker 설치 확인
sudo systemctl status docker
```

- node간 SSH key 교환

## 2. kubespray install
```bash
root@87301a6af9e8:~# pwd
/root

root@mal-k8s-prx:~# git clone https://github.com/kubernetes-sigs/kubespray.git
root@mal-k8s-prx:~# ssh-keygen -t rsa
root@mal-k8s-prx:~# docker run --rm -it --mount type=bind,source="$(pwd)"/kubespray/inventory/sample,dst=/inventory   --mount type=bind,source="${HOME}"/.ssh/id_rsa,dst=/root/.ssh/id_rsa   quay.io/kubespray/kubespray:v2.27.0 bash
root@0188f0719dd4:/kubespray# ansible-playbook -i /kubespray/inventory/sample/inventory.ini --private-key /root/.ssh/id_rsa cluster.yml

```

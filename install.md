# k8s install

## 사전 준비
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
---
## node간 SSH key 교환
---
## 2. kubespray clone
```bash
https://github.com/kubernetes-sigs/kubespray.git
```

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
============================================= 여기부터 다시~~~~

## 3. 오프라인 환경으로 데이터 이동
위 단계에서 생성된 이미지와 파일(예: temp 디렉터리 전체, 다운로드된 이미지 tar 파일 등)을 오프라인 환경으로 복사합니다.

## 4. 오프라인 환경에서 레지스트리 및 파일 서버 구성
### 4.1. 로컬 레지스트리에 이미지 등록
오프라인 환경에서 이미지 파일을 레지스트리에 등록합니다.

```bash
./contrib/offline/manage-offline-container-images.sh register
```

필요하다면 환경변수로 DESTINATION_REGISTRY, REGISTRY_PORT 등을 설정할 수 있습니다.

### 4.2. 파일 서버 실행
오프라인 환경에서 nginx 파일 서버가 실행 중인지 확인합니다. 필요하다면 위의 manage-offline-files.sh 스크립트로 다시 실행합니다.

## 5. Kubespray로 오프라인 설치 진행
오프라인 환경에서 Kubespray 인벤토리와 설정에 맞게 클러스터 설치를 진행합니다.

필요한 이미지와 파일은 모두 오프라인 환경 내의 로컬 레지스트리와 파일 서버에서 참조됩니다.






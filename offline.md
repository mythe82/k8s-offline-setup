# k8s-offline-setup

## 1. 온라인 환경에서 필요한 이미지 및 파일 수집
### (1) 컨테이너 이미지 리스트 생성
Kubespray 루트 디렉터리에서 아래 스크립트를 실행해 필요한 이미지 리스트와 파일 리스트를 생성합니다.

```bash
mythe82@k8s-controller-1:~$ source ~/kubespray-venv/bin/activate
(kubespray-venv) mythe82@k8s-controller-1:~$ cd kubespray/contrib/offline/
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray/contrib/offline$ ./generate_list.sh -i inventory/mycluster/inventory.ini
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray/contrib/offline$ cd temp/
(kubespray-venv) mythe82@k8s-controller-1:~/kubespray/contrib/offline/temp$ ls
files.list  files.list.template  images.list  images.list.template

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

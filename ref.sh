- k8s_env_build.sh

#!/usr/bin/env bash

# avoid 'dpkg-reconfigure: unable to re-open stdin: No file or directory'
export DEBIAN_FRONTEND=noninteractive

# swapoff -a to disable swapping
swapoff -a
# sed to comment the swap partition in /etc/fstab (Rmv blank)
sed -i.bak -r 's/(.+swap.+)/#\1/' /etc/fstab

# add kubernetes repo 
curl \
  -fsSL https://pkgs.k8s.io/core:/stable:/v$2/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo \
  "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v$2/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

# add docker-ce repo with containerd
curl -fsSL \
  https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

# packets traversing the bridge are processed by iptables for filtering
echo 1 > /proc/sys/net/ipv4/ip_forward
# enable br_filter for iptables 
modprobe br_netfilter

# local small dns & vagrant cannot parse and delivery shell code.
echo "127.0.0.1 localhost" > /etc/hosts # localhost name will use by calico-node
echo "192.168.56.10 cp-k8s" >> /etc/hosts
for (( i=1; i<=$1; i++  )); do echo "192.168.56.1$i w$i-k8s" >> /etc/hosts; done

===============================

- k8s_pkg_cfg.sh

#!/usr/bin/env bash

# avoid 'dpkg-reconfigure: unable to re-open stdin: No file or directory'
export DEBIAN_FRONTEND=noninteractive

# update package list 
apt-get update 

# install NFS 
if [ $3 = 'CP' ]; then
  apt-get install nfs-server nfs-common -y 
elif [ $3 = 'W' ]; then
  apt-get install nfs-common -y 
fi

# install kubernetes
# both kubelet and kubectl will install by dependency
# but aim to latest version. so fixed version by manually
apt-get install -y kubelet=$1 kubectl=$1 kubeadm=$1 containerd.io=$2

# containerd configure to default and cgroup managed by systemd 
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# avoid WARN&ERRO(default endpoints) when crictl run  
cat <<EOF > /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
EOF

# ready to install for k8s 
systemctl restart containerd ; systemctl enable containerd
systemctl enable --now kubelet

- controlplane_node.sh

#!/usr/bin/env bash

# init kubernetes (w/ containerd)
kubeadm init --token 65z741.dd70q5p4d17ch3cv --token-ttl 0 \
             --pod-network-cidr=172.16.0.0/16 --apiserver-advertise-address=192.168.56.10 \
             --cri-socket=unix:///run/containerd/containerd.sock

# config for control plane node only 
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# CNI raw address & config for kubernetes's network 
CNI_ADDR="https://raw.githubusercontent.com/sysnet4admin/IaC/main/k8s/CNI"
kubectl apply -f $CNI_ADDR/172.16_net_calico_v3.26.0.yaml

# kubectl completion on bash-completion dir
kubectl completion bash >/etc/bash_completion.d/kubectl

# alias kubectl to k 
echo 'alias k=kubectl' >> ~/.bashrc
echo "alias ka='kubectl apply -f'" >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc

# git clone k8s-code
git clone https://github.com/sysnet4admin/_Lecture_k8s_starter.kit.git
mv /home/vagrant/_Lecture_k8s_starter.kit $HOME
find $HOME/_Lecture_k8s_starter.kit -regex ".*\.\(sh\)" -exec chmod 700 {} \;

# make rerepo-k8s-starter.kit and put permission
cat <<EOF > /usr/local/bin/rerepo-k8s-starter.kit
#!/usr/bin/env bash
rm -rf $HOME/_Lecture_k8s_starter.kit
git clone https://github.com/sysnet4admin/_Lecture_k8s_starter.kit.git $HOME/_Lecture_k8s_starter.kit
find $HOME/_Lecture_k8s_starter.kit -regex ".*\.\(sh\)" -exec chmod 700 {} \;
EOF
chmod 700 /usr/local/bin/rerepo-k8s-starter.kit

# extended k8s certifications all
git clone https://github.com/yuyicai/update-kube-cert.git /tmp/update-kube-cert
chmod 755 /tmp/update-kube-cert/update-kubeadm-cert.sh
/tmp/update-kube-cert/update-kubeadm-cert.sh all --cri containerd
rm -rf /tmp/update-kube-cert
echo "Wait 30 seconds for restarting the Control-Plane Node..." ; sleep 30


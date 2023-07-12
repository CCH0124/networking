#!/bin/bash

echo ">>> INIT MASTER NODE"


sudo kubeadm init \
  --skip-phases=addon/kube-proxy \
  --apiserver-advertise-address=$MASTER_NODE_IP \
  --pod-network-cidr=$K8S_POD_NETWORK_CIDR \
  --cri-socket=unix:///var/run/crio/crio.sock \
  --v=5

echo ">>> CONFIGURE KUBECTL"

sudo mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


echo ">>> FIX KUBELET NODE IP"

echo "Environment=\"KUBELET_EXTRA_ARGS=--node-ip=$MASTER_NODE_IP\"" | sudo tee -a /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

echo "Install helm"

curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

echo "Install cilium"

helm repo add cilium https://helm.cilium.io/

helm install cilium cilium/cilium --version 1.13.4 --namespace kube-system


echo ">>> GET WORKER JOIN COMMAND "

sudo kubeadm token create --print-join-command > /home/vagrant/init-worker.sh
sudo chmod +x /home/vagrant/init-worker.sh

sudo sed -i "/^[^#]*PasswordAuthentication[[:space:]]no/c\PasswordAuthentication yes" /etc/ssh/sshd_config
sudo systemctl restart sshd.service

#!/bin/bash
set -e -x -u
export DEBIAN_FRONTEND=noninteractive

echo "SYSTEM UPDATE & UPGRADE"

sudo apt update
sudo apt -y upgrade

echo "ADD KUBERNETES REPOS"

sudo mkdir -p /etc/apt/keyrings

sudo apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update

echo ">>> INSTALL KUBE-* TOOLS"

sudo apt-get install -y kubelet=$VERSION kubeadm=$VERSION kubectl=$VERSION 
sudo apt-mark hold kubelet kubeadm kubectl

echo ">>> KERNEL MODULES"

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/kubernetes.conf
overlay
br_netfilter
EOF

sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

echo ">>> INSTALL CRI-O"

export OS=xUbuntu_20.04
export CRI_VERSION=1.26

echo "deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb [signed-by=/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRI_VERSION/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRI_VERSION.list

# Creating directory /usr/share/keyrings
mkdir -p /usr/share/keyrings

# Downloading GPG key for CRI-O repository
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-archive-keyring.gpg
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRI_VERSION/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/libcontainers-crio-archive-keyring.gpg

sudo apt update

sudo apt install cri-o cri-o-runc -y


sudo sed -i 's/10.85.0.0/10.244.0.0/g' /etc/cni/net.d/100-crio-bridge.conflist

sudo systemctl daemon-reload
sudo systemctl restart crio
sudo systemctl enable crio

echo ">>> DISABLE SWAP"

sudo sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
sudo swapoff -a

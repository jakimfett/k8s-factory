apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v${kubernetes_version}
networking:
  podSubnet: ${pod_cidr}
  serviceSubnet: ${service_cidr}
controlPlaneEndpoint: ${server_ip}:6443

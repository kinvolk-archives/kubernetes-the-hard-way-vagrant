# Kubernetes The Hard Way (Vagrant)

Vagrant configuration and scripts for a Kubernetes setup, the hard way.

The setup follows https://github.com/kelseyhightower/kubernetes-the-hard-way
with the following exceptions:

* `cri-o` is used as a container runtime, not `cri-containerd`
* The `pod-cidr` is `10.2${i}.0.0/16`, routes are provisioned from
  `scripts/vagrant-setup-routes.bash` automatically
* For `crio`, an explicit `--stream-address` must be set, as the address
  of the default interface isn't routable (see e.g. [`config/worker-0-crio.service`](config/worker-0-crio.service))
* `192.168.199.40` is the IP of the loadbalancer (haproxy) for HA controllers

Please note that KTHW is a project to learn Kubernetes from bottom up
and is not per se a guide to build clusters for production use!

## Requirements Host

* Vagrant (with VirtualBox)
* Minimum of 7x 512MB of free RAM
* `cfssl`, `cfssljson` and `kubectl` (`scripts/install-tools` can be
  used to download and install the binaries to `/usr/local/bin`)

## Setup

### Manually

To learn Kubernetes from the bottom up, it's recommended to go through
KTHW manually. `vagrant up` gives you three controller and three worker
nodes to do that.

The `pod-cidr` is `10.2${i}.0.0/16`, for which the Vagrant nodes have
configured routes (see `route -n`).

The following KTHW parts can/should be skipped:

* Everything in regard to the frontend loadbalancer
* Pod network rules are automatically setup via Vagrant

The scripts in `scripts/` loosely match the setup steps in KTHW by
Hightower and can be used as reference and/or to save typing. See
`scripts/setup` also.

### Single script

```
vagrant destroy -f   # remove previous setup
./scripts/setup      # takes about 5 minutes or more
[...]
```

If everything looks good, continue with ["Using the cluster"](#using-the-cluster)

### Multiple scripts

Remove previously created certificates, tools kubeconfig files:

```
./scripts/distclean
```

Download required tools and files:

```
./scripts/download-tools
```

Start the virtual machines (optionally, go drink a coffee or tee):

```
vagrant up
[...]
vagrant status

Current machine states:

controller-0              running (virtualbox)
controller-1              running (virtualbox)
controller-2              running (virtualbox)
worker-0                  running (virtualbox)
worker-1                  running (virtualbox)
worker-2                  running (virtualbox)
```

Generate the required certificates:

```
./scripts/generate-certs
```

Generate the kubeconfig files (as those include copies of the previously
generated certificates):

```
./scripts/generate-kubeconfig-kube-proxy
./scripts/generate-kubeconfig-worker
```

Setup etcd on the controller nodes and verify it has started:

```
./scripts/setup-etcd
[...]
vagrant ssh controller-0
ETCDCTL_API=3 etcdctl member list

6c500a9f4f9113de, started, controller-0, https://192.168.199.10:2380, https://192.168.199.10:2379
e206d150eae73959, started, controller-2, https://192.168.199.12:2380, https://192.168.199.12:2379
e7e775a3da74a469, started, controller-1, https://192.168.199.11:2380, https://192.168.199.11:2379
```

Setup the controller services and verify they are up and running:

```
./scripts/setup-controller-services
[...]
for c in controller-0 controller-1 controller-2; do vagrant ssh $c -- kubectl get componentstatuses; done

NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-1               Healthy   {"health": "true"}
etcd-2               Healthy   {"health": "true"}
etcd-0               Healthy   {"health": "true"}
[...]
```

Create `ClusterRole`'s for kubelet API auth:

```
./scripts/setup-kubelet-api-cluster-role
```

Setup the worker binaries, services and configuration:

```
./scripts/setup-worker-services
[...]
vagrant ssh controller-0
kubectl get nodes

NAME       STATUS    AGE       VERSION
worker-0   Ready     1m        v1.9.2
worker-1   Ready     55s       v1.9.2
worker-2   Ready     12s       v1.9.2
```

Configure a `kubernetes-the-hard-way` context on your host, set it as
default and verify everything is ok:

```
./scripts/configure-kubectl-on-host

kubectl get componentstatuses
[...]
kubectl get nodes
[...]
```

## Using the cluster

### Setup DNS add-on

Deploy the `coredns` cluster add-on and verify it's working:

```
kubectl create -f ./manifests/coredns.yaml
[...]
kubectl get pods -l k8s-app=kube-dns -n kube-system
[...]
kubectl run busybox --image=busybox:1.28 --command -- sleep 3600
[...]
POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")
kubectl exec -ti $POD_NAME -- nslookup kubernetes
```

### Smoke tests

```
kubectl create -f ./manifests/nginx.yaml
deployment "nginx" created
service "nginx" created

NODE_PORT=$(kubectl get svc nginx --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
for i in {0..2}; do curl -sS 192.168.199.2${i}:${NODE_PORT} | awk '/<h1>/{gsub("<[/]*h1>", ""); print $0}'; done
Welcome to nginx!
Welcome to nginx!
Welcome to nginx!
```

### Connect to services from host

`10.32.0.0/24` is the IP range for services. In order to connect to a service
from the host, one of the worker nodes (with `kube-proxy`) must be used as a
gateway. Example:


```
# On Linux
sudo route add -net 10.32.0.0/24 gw 192.168.199.22

# On macOS
sudo route -n add -net 10.32.0.0/24 192.168.199.22
```

### Use [Traefik](https://traefik.io/) loadbalancer

```
./scripts/setup-traefik
[...]
curl 192.168.199.30
404 page not found
```

To test traefik is actually doing its job, you can create an ingress rule
for the nginx service that you created above:

```
kubectl apply -f ./manifests/nginx-ingress.yaml
echo "192.168.199.30 nginx.kthw" | sudo tee -a /etc/hosts
curl nginx.kthw
<!DOCTYPE html>
[...]
```

## Contributing

Contributions are welcome: KTHW Vagrant is meant to be a learning
project and testbed for aspiring Kubernetes operators and CKAs
([Certified Kubernetes Administrator](https://www.cncf.io/certification/cka/)).

If you want to contribute code or updates, look for the label
[good first issue](https://github.com/kinvolk/kubernetes-the-hard-way-vagrant/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22).

## Pitfalls

### Error loading config file "/var/log": read /var/log: is a directory

On OSX, `KUBECONFIG` apparently needs to be set explicitly. `~/.kube/config`
is a good place and the default on Linux.

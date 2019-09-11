# Linux Node Selector Adder

The goal of this project is to end failures of Linux apps due to being scheduled on a windows worker node.

The scheduler in Kubernetes does not know what OS your application is. It is incumbent on the developer to restrict their apps to Linux or Windows nodes. 

## More Context

There are a few problems that exist with this restriction. The best practices on how to restrict an app to a Linux or Windows worker node may change. And many Linux developers do not test with or consider the windows ecosystem.  As such most applications require either patches (as their configuration is buried in code) or manual configuration to restrict it to Linux nodes. Since there is a lot of useful software that exhibits these problems it means that either when a Windows node is added to the cluster Linux apps start failing, or people are hesitant to add this software to mixed mode clusters because it is hard. We will fix all this by seamlessly auto patching incorrect configuration. 

### Don't windows apps require fixes

Currently no, all windows apps were written with knowledge of Linux and restrict themselves.

# Status

Currently this code was accomplished in a hackathon. There are numerous known deficiencies, and a few unknown ones.


## TODO

* create helm chart to deploy app
* auto setup certificates for webhook
* renew certificates for webhook before they expire
* push image for mutating webhook
* multiarch image
* mutate replicas, jobs, daemonsets, ... such that when scheduling the pod the hook doesn't need to get invoked
* option to delete existing pods in cluster that fail checks such that mutator will get invoked when rescheduled and clean up existing broken apps


# Kubernetes Mutating Admission Webhook for lcow injection

Forked from mutating admission webhook info at https://github.com/morvencao/kube-mutating-webhook-tutorial

## Prerequisites

Kubernetes 1.9.0 or above with the `admissionregistration.k8s.io/v1beta1` API enabled. Verify that by the following command:
```
kubectl api-versions | grep admissionregistration.k8s.io/v1beta1
```
The result should be:
```
admissionregistration.k8s.io/v1beta1
```

In addition, the `MutatingAdmissionWebhook` and `ValidatingAdmissionWebhook` admission controllers should be added and listed in the correct order in the admission-control flag of kube-apiserver.

**This code currently uses the node selector `beta.kubernetes.io/os` in 1.18 this needs to change to `kubernetes.io/os` (available since 1.14)**

## Build

1. Setup dep

   The repo uses [dep](https://github.com/golang/dep) as the dependency management tool for its Go codebase. Install `dep` by the following command:
```
go get -u github.com/golang/dep/cmd/dep
```

2. Build and push docker image
   
```
./build
```

## Deploy

1. Create a signed cert/key pair and store it in a Kubernetes `secret` that will be consumed lcow deployment
```
kubectl apply -f ./deployment/namespace.yaml
./deployment/webhook-create-signed-cert.sh \
    --service lcow-injector-webhook-svc \
    --secret lcow-injector-webhook-certs \
    --namespace injector
```

2. Patch the `MutatingWebhookConfiguration` by set `caBundle` with correct value from Kubernetes cluster
```
cat deployment/mutatingwebhook.yaml | \
    deployment/webhook-patch-ca-bundle.sh > \
    deployment/mutatingwebhook-ca-bundle.yaml
```

3. Deploy resources
```
kubectl apply -f deployment/deployment.yaml
kubectl apply -f deployment/service.yaml
kubectl apply -f deployment/mutatingwebhook-ca-bundle.yaml
```

4. Delete resources
```
kubectl delete -f deployment/deployment.yaml
kubectl delete -f deployment/service.yaml
kubectl delete -f deployment/mutatingwebhook-ca-bundle.yaml
kubectl delete -f deployment/namespace.yaml
```

## Verify

1. The webhook should be running
```
[root@mstnode ~]# kubectl get pods
NAME                                                  READY     STATUS    RESTARTS   AGE
lcow-injector-webhook-deployment-bbb689d69-882dd   1/1       Running   0          5m
[root@mstnode ~]# kubectl get deployment
NAME                                  DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
lcow-injector-webhook-deployment   1         1         1            1           5m
```
# *** inside node ***
kubectl get nodes -o wide

kubectl get all -n kube-system

kubectl get all

curl -H "Host:app1.com" 192.168.56.110
curl -H "Host:app2.com" 192.168.56.110
curl -H "Host:app3.com" 192.168.56.110

curl 192.168.56.110

#*** app2 and it's 3 replicas ***

kubectl get deployment app2

kubectl get pods -l app=app2 -o wide

#verify that the Service points to all 3 pods
kubectl get svc

#list of 3 ips of app2 pods pointing to app2 service expected
kubectl get endpointslice -l kubernetes.io/service-name=app2
#readable description of app2 service
kubectl describe svc app2

for i in $(seq 1 100); do curl -s http://app2:8080/; done

#delete one pod
kubectl delete pod <one-app2-pod>
#verify that it was replaced 
kubectl get pods -l app=app2 -w
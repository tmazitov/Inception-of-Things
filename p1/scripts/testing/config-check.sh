# *** inside server node ***
vagrant ssh tmazitovS

#two nodes must be presented:
kubectl get nodes -o wide

#active status expected
sudo systemctl status k3s


# *** inside worker node ***
vagrant ssh nmagdanoSW

#k3s network must be shown as eth1
ip a 

#ping server
ping -c 3 192.168.56.110

#active status expected
sudo systemctl status k3s-agent

#kubernetes api port 6443 must be reachable from worker
nc -zv 192.168.56.110 6443

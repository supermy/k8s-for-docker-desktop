k8s-all:
	kubectl get all -o wide

k8s-install:
	brew install docker
	brew install kubectl

k8s-info:
	kubectl cluster-info
	kubectl get nodes

k8s-dashboard-config:
	kubectl apply -f kubernetes-dashboard.yaml
	kubectl get pod -n kubernetes-dashboard
	kubectl apply -f kube-system-default.yaml

TOKEN=$(shell kubectl -n kube-system describe secret default| awk '$$1=="token:"{print $$2}');
k8s-dashboard:
	@kubectl config set-credentials docker-desktop --token="${TOKEN}"
	kubectl proxy  &
	@echo ${TOKEN}
	open "http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"

k8s-test:
	-kubectl run redis --image=redis  -o yaml --dry-run=client >cmdgen/redis-pod.yaml
	-kubectl create deployment redis-deployment --image=redis -o yaml --dry-run=client >cmdgen/redis-deploy.yaml
	-kubectl run redis --image=redis
	-kubectl create deployment redis-deployment --image=redis
	# kubectl exec -it redis bash
	sleep 8s
	-kubectl get all -o wide
	-kubectl port-forward deployment/redis-deployment  6379:6379 &
	sleep 3s
	-redis-cli set a 123
	-redis-cli get a
	#删除自动自动重建
	-kubectl delete pod redis
	-kubectl delete deployment redis-deployment
	-kubectl get all -o wide


k8s-ingress-install:
	# edit images.properties 对应k8s版本
	sh load_images.sh
	kubectl apply -f ingress-nginx-controller-1.7.1.yaml
	kubectl get all -n ingress-nginx 

k8s-ingress-config:
	kubectl exec -it -n ingress-nginx ingress-nginx-controller-789f495cbf-44d25 bash
	cat /etc/nginx/nginx.conf

k8s-ingress-test1:
	-kubectl create deployment demo --image=httpd --port=80
	-kubectl create deployment demo --image=httpd --port=80 -o yaml --dry-run=client >cmdgen/demo-deploy.yaml
	-kubectl expose deployment demo #用命令生成service
	-kubectl expose deployment demo  -o yaml --dry-run=client >cmdgen/demo-deploy-expose.yaml
	-kubectl create ingress demo-localhost --class=nginx  --rule="demo.localdev.me/*=demo:80"
	-kubectl create ingress demo-localhost --class=nginx  --rule="demo.localdev.me/*=demo:80" -o yaml --dry-run=client >cmdgen/demo-ingress-localhost.yaml
	-kubectl describe ingress demo-localhost
	sleep 10s
	-kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80 &
	-curl -H "Host: demo.localdev.me" http://127.0.0.1:8080/
	kubectl get service ingress-nginx-controller --namespace=ingress-nginx
	kubectl create ingress demo --class=nginx --rule="www.demo.io/=demo:80,tls=tls-secret"
	kubectl create ingress demo --class=nginx --rule="www.demo.io/=demo:80,tls=tls-secret"   -o yaml --dry-run=client >cmdgen/demo-ingress.yaml
	-kubectl describe ingress demo
	sleep 5s
	# http-redirect-code = 301 （使用301 进行强制跳转）
	curl -k -H "Host: www.demo.io" https://127.0.0.1/

k8s-ingress-test1-clean:
	-kubectl delete deployment demo
	-kubectl delete service demo
	-kubectl delete ingress demo-localhost
	-kubectl delete ingress demo
	-kubectl get all -o wide

k8s-ingress-test21:
	-kubectl create deployment apple --image=hashicorp/http-echo --port=5678  -o yaml --dry-run=client >sample/apple-deploy.yaml
	#add  args:       - "-text=apple"
	-kubectl expose deployment apple -o yaml --dry-run=client >sample/apple-svc.yaml
	-kubectl apply -f sample/apple-deploy.yaml
	-kubectl apply -f sample/apple-svc.yaml
	kubectl get all -o wide
	kubectl port-forward service/apple  5678:5678
	curl http://127.0.0.1:5678/
	kubectl describe deployment apple
	kubectl delete deployment apple
	kubectl delete service apple

k8s-ingress-test22:
	-kubectl create -f sample/apple.yaml
	-kubectl create -f sample/banana.yaml
	-kubectl create -f sample/ingress.yaml
	kubectl port-forward pod/apple-app  5678:5678
	curl http://127.0.0.1:5678/
	kubectl port-forward service/apple-service  5678:5678
	kubectl port-forward service/banana-service  5678:5678
	curl http://127.0.0.1:5678/
	kubectl get ingress -o wide
	curl -H "Host: ingress-test.my" http://127.0.0.1/
	kubectl delete -f sample/apple.yaml
	kubectl delete -f sample/banana.yaml
	kubectl delete -f sample/ingress.yaml

k8s-ssl:
	openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout cert/tls.key -out cert/tls.crt -subj "/C=CN/ST=BJ/L=BeiJing/O=myk8s/OU=System/CN=myk8s/emailAddress=ca@test.com"
	kubectl create secret tls tls-secret --key cert/tls.key --cert cert/tls.crt

# 第一个参数是NFS共享目录的路径；
# 第二个参数是允许共享目录的 网段，这里设置的是本书中的Kubernetes集群机器网段，也可以设置 为“*”以表示不限制。
# 最后小括号中的参数为权限设置，rw表示允 许读写访问，sync表示所有数据在请求时写入共享目录，insecure 表示NFS通过1024以上的端口进行发送，no_root_squash表示root 用户对根目录具有完全的管理访问权限，no_subtree_check表示 不检查父目录的权限。
k8s-nfs:
	# sudo echo "/Users/moyong/project/k8s/data -alldirs -maproot=root:wheel -network 192.168.0.0 -mask 255.255.255.0">/etc/exports
	# /Users/moyong/project/k8s/data
	# *(rw,sync,insecure,no_subtree_check,no_root_squash)
	# nfs.server.mount.require_resv_port = 0 /etc/nfs.conf k8s中使用添加参数
	chmod 777 /Users/moyong/project/k8s/data
	nfsd checkexports
	sudo nfsd disable
	sudo nfsd enable
	sudo nfsd stop
	sudo nfsd start
	sudo nfsd status
	showmount -e localhost
	showmount -e 192.168.0.107
	mount -t nfs -o nolock,nfsvers=3,vers=3 localhost:/Users/moyong/project/k8s/data mnt/data/
	helm upgrade -i nfs stable/nfs-client-provisioner --set nfs.server=192.168.0.107 --set nfs.path=/Users/moyong/project/k8s/data

# K8S支持的卷类型很多，主要分为分布式文件系统、ConfigMap和本地文件系统这几种，其中本地文件系统支持：hostPath和local（
# Local持久卷基本具备了hostPath的绑定本地文件系统目录的能力和方便性，同时自动具备调度到指定节点的能力，并且可以对持久卷进行管理。
# 唯一的问题在于，我们还需要手工去对应的节点创建对应的目录和删除对应的目录，这需要结合我们的应用系统来进行统一的设计和管理。
# 总得来说，对于状态应用程序的部署来说，Local持久卷能够提供分布式存储无法提供的高性能，同时具备了一定的调度的灵活性，是一个不错的选择。

# PV：PV描述的是持久化存储卷，主要定义的是一个持久化存储在宿主机上的目录，比如一个NFS的挂载目录。
# PVC：PVC描述的是Pod所希望使用的持久化存储的属性，比如，Volume存储的大小、可读写权限等等。
k8s-vol-local:
	-kubectl delete pod task-pv-pod
	-kubectl delete pvc task-pv-claim
	-kubectl delete pv task-pv-volume
	kubectl apply -f sample/pv-volume.yaml
	kubectl apply -f sample/pv-claim.yaml
	sleep 5s
	kubectl get pv task-pv-volume
	kubectl get pvc task-pv-claim
	kubectl apply -f sample/pv-pod.yaml
	kubectl get pod task-pv-pod
	# kubectl exec -it task-pv-pod -- /bin/bash
	kubectl port-forward pod/task-pv-pod  8088:80 &
	curl 127.0.0.1:8088/
	kubectl apply -f sample/nfs-pod.yaml

k8s-vol:
	kubectl delete -f volume/pvc-nfs-deploy.yaml
	kubectl delete -f volume/pvc-nfs.yaml
	# kubectl create configmap my-config --from-file=data/conf.txt
	kubectl create -f volume/pvc-nfs.yaml
	kubectl create -f volume/pvc-nfs-deploy.yaml
	kubectl get pv
	kubectl get pvc
	make
	kubectl port-forward service/nfs-pvc 8080:80 &
	curl 127.0.0.1:8080

k8s-vol1:
	rpcinfo -p #查看需要开放的端口
	showmount -e 192.168.0.107
	showmount -e localhost

	kubectl apply -f volume/exampledeployfornfs.yaml
	kubectl get pod -o wide
	kubectl delete -f volume/exampledeployfornfs.yaml




	


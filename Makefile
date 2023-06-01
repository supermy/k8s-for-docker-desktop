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
	kubectl create ingress demo --class=nginx --rule www.demo.io/=demo:80
	kubectl create ingress demo --class=nginx --rule www.demo.io/=demo:80   -o yaml --dry-run=client >cmdgen/demo-ingress.yaml
	-kubectl describe ingress demo
	sleep 5s
	curl -H "Host: www.demo.io" http://127.0.0.1/

k8s-ingress-test1-clean:
	-kubectl delete deployment demo
	-kubectl delete service demo
	-kubectl delete ingress demo-localhost
	-kubectl delete ingress demo
	-kubectl get all -o wide

k8s-ingress-test2:
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

k8s-ingress-test88:
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



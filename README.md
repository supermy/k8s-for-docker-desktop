# Docker Desktop for Mac/Windows 开启 Kubernetes


说明: 

最佳实践：
    k8s 支持 ssl 集群 负载均衡；
    k8s volume 绑定 nfs ,解决性能瓶颈与数据共享；
    k8s=nginx.conf 配置的domain语言；

* 需安装 Docker Desktop 的 Mac 或者 Windows 版本，如果没有请下载[下载 Docker CE最新版本](https://store.docker.com/search?type=edition&offering=community)
* 如果需要测试其他版本，请查看 Docker Desktop版本，Docker -> About Docker Desktop
  ![about](images/about.png)

注：如果发现K8s版本与您的环境不一致，可以修改```images.properties```文件指明所需镜像版本，欢迎Pull Request。


### 开启 Kubernetes

为 Docker daemon 配置镜像加速，参考[阿里云镜像服务](https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors) 或中科大镜像加速地址```https://docker.mirrors.ustc.edu.cn```

![mirror](images/mirror.png)

可选操作: 为 Kubernetes 配置 CPU 和 内存资源，建议分配 4GB 或更多内存。 

![resource](images/resource.png)

从阿里云镜像服务下载 Kubernetes 所需要的镜像

在 Mac 上执行如下脚本

```bash
./load_images.sh
```


开启 Kubernetes，并等待 Kubernetes 开始运行
![k8s](images/k8s.png)

**TIPS**：

在Mac上:

如果在Kubernetes部署的过程中出现问题，可以通过docker desktop应用日志获得实时日志信息：

```bash
pred='process matches ".*(ocker|vpnkit).*"
  || (process in {"taskgated-helper", "launchservicesd", "kernel"} && eventMessage contains[c] "docker")'
/usr/bin/log stream --style syslog --level=debug --color=always --predicate "$pred"
```

**问题诊断**：

如果看到 Kubernetes一直在启动状态，请参考 

* [Issue 3769(comment)](https://github.com/docker/for-win/issues/3769#issuecomment-486046718) 或 [Issue 3649(comment)](https://github.com/docker/for-mac/issues/3649#issuecomment-497441158)
  * 在macOS上面，执行 ```rm -fr '~/Library/Group\ Containers/group.com.docker/pki'```
* [Issue 1962(comment)](https://github.com/docker/for-win/issues/1962#issuecomment-431091114)

### 配置 Kubernetes


可选操作: 切换Kubernetes运行上下文至 docker-desktop (之前版本的 context 为 docker-for-desktop)


```shell
kubectl config use-context docker-desktop
```

验证 Kubernetes 集群状态

```shell
kubectl cluster-info
kubectl get nodes
```

### 配置 Kubernetes 控制台

#### 部署 Kubernetes dashboard

```shell
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl apply -f kubernetes-dashboard.yaml
```

检查 kubernetes-dashboard 应用状态

```shell
kubectl get pod -n kubernetes-dashboard
```

开启 API Server 访问代理

```shell
kubectl proxy
```

通过如下 URL 访问 Kubernetes dashboard

http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

#### 配置控制台访问令牌

授权`kube-system`默认服务账号

```shell
kubectl apply -f kube-system-default.yaml
```

对于Mac环境

```shell
TOKEN=$(kubectl -n kube-system describe secret default| awk '$1=="token:"{print $2}')
kubectl config set-credentials docker-desktop --token="${TOKEN}"
echo $TOKEN
```

#### 登录dashboard的时候

![resource](images/k8s_credentials.png)

选择 **令牌** 

输入上文控制台输出的内容

或者选择 **Kubeconfig** 文件,路径如下：

```
Mac: $HOME/.kube/config
```

点击登陆，进入Kubernetes Dashboard

### 配置 Ingress
https://kubernetes.github.io/ingress-nginx/deploy/#quick-start


说明：如果测试 Istio，不需要安装 Ingress


#### 安装 Ingress

[源地址安装说明](https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/index.md)
```
- 若安装脚本无法安装，可以跳转到该地址查看最新操作
```

安装

```shell
没改成 NodePort 方式，（否则 controller 会一直 Pending  1.6.4

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.1/deploy/static/provider/cloud/deploy.yaml
kubectl apply -f ingress-nginx-controller-1.7.1.yaml
```

验证

```shell
kubectl get all -n ingress-nginx
NAME                                       READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-kfjv5       0/1     Completed   0          9s
ingress-nginx-admission-patch-bgpkm        0/1     Completed   0          9s
ingress-nginx-controller-d468dc74f-nttpr   0/1     Running     0          9s


#查看生成的openresty配置文件
kubectl exec -it -n ingress-nginx ingress-nginx-controller-d468dc74f-nttpr bash
cat /etc/nginx/nginx.conf


kubectl get all -n ingress-nginx 
bogon:k8s moyong$ kubectl get all -n ingress-nginx 
NAME                                            READY   STATUS      RESTARTS   AGE
pod/ingress-nginx-admission-create-c26dt        0/1     Completed   0          10m
pod/ingress-nginx-admission-patch-pl6wc         0/1     Completed   0          10m
pod/ingress-nginx-controller-789f495cbf-rjh7j   1/1     Running     0          10m

NAME                                         TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
service/ingress-nginx-controller             LoadBalancer   10.105.195.29    localhost     80:32609/TCP,443:31792/TCP   10m
service/ingress-nginx-controller-admission   ClusterIP      10.102.103.239   <none>        443/TCP                      10m

NAME                                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ingress-nginx-controller   1/1     1            1           10m

NAME                                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/ingress-nginx-controller-789f495cbf   1         1         1       10m

NAME                                       COMPLETIONS   DURATION   AGE
job.batch/ingress-nginx-admission-create   1/1           6s         10m
job.batch/ingress-nginx-admission-patch    1/1           5s         10m


```

```

kubectl get svc -o wide
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE   SELECTOR
apple-service   ClusterIP   10.101.99.129   <none>        5678/TCP   32m   app=apple
demo            ClusterIP   10.99.140.87    <none>        80/TCP     27m   app=demo
kubernetes      ClusterIP   10.96.0.1       <none>        443/TCP    69m   <none>

```

#### 测试示例应用

```
kubectl run redis --image=redis
kubectl exec -it redis bash
kubectl create deployment redis-deployment --image=redis
kubectl delete pod redis redis-deployment-866c4c6cf9-8z8k5
redis已经消失了，但是redis-deployment-866c4c6cf9-zskkb换了个名字又出现了！
```

部署测试应用，详情参见[社区文章](https://matthewpalmer.net/kubernetes-app-developer/articles/kubernetes-ingress-guide-nginx-example.html)

本地测试¶
让我们创建一个简单的网络服务器和相关服务：

```
kubectl create deployment demo --image=httpd --port=80
kubectl expose deployment demo #用命令生成service
```
然后创建一个入口资源。以下示例使用映射到localhost的主机：
```
kubectl create ingress demo-localhost --class=nginx \
  --rule="demo.localdev.me/*=demo:80"
```

现在，将本地端口转发到入口控制器：
```
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80
```
此时，如果您访问http://demo.localdev.me:8080/，您应该会看到一个HTML页面，告诉您“它有效！”。

```
kubectl get ingress 
NAME             CLASS   HOSTS              ADDRESS   PORTS   AGE
demo-localhost   nginx   demo.localdev.me             80      20m

kubectl describe ingress demo-localhost


        upstream upstream_balancer {
                server 0.0.0.1; # placeholder

                balancer_by_lua_block {
                        balancer.balance()
                }

                keepalive 32;

        }
        在 nginx 配置中确实添加了 一个 server 条目，但该条目中没有具体指出后端的容器地址，而是指向了一个叫 upstream_balancer 的地址，这个 balancer 其实是由 Lua 动态提供路由的。既然没有实际的容器后端在配置文件中进行配置，自然地，服务中容器数量的增减变化也就不必修改 nginx 配置文件了，这就是免 reload 的关键！简单推测，Lua 模块所做的就是维持一个服务到容器的映射关系，动态地提供负载均衡路由。

```

```
1，通过指定pod实现端口转发

kubectl port-forward pods/pod-name 443:443 -n ingress-nginx

2，通过指定service实现端口转发

kubectl port-forward svc/service-name 6379:6379

3，通过指定deployment实现端口转发

kubectl port-forward deployment/deployment-name 6379:6379


```


```shell FIXME
kubectl create -f sample/apple.yaml
kubectl create -f sample/banana.yaml
kubectl create -f sample/ingress.yaml

```

测试示例应用

```bash
kubectl port-forward service/apple-service    5678:5678

$ curl -kL http://localhost/apple
apple
$ curl -kL http://localhost/banana
banana
```

删除示例应用

```shell
kubectl delete -f sample/apple.yaml
kubectl delete -f sample/banana.yaml
kubectl delete -f sample/ingress.yaml
```

#### 删除 Ingress


```shell
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.1/deploy/static/provider/cloud/deploy.yaml
kubectl delete -f ingress-nginx-controller-1.7.1.yaml
```



### 安装 Helm  TODO

可以根据文档安装 helm v3 https://helm.sh/docs/intro/install/
在国内由于helm的cdn节点使用的是谷歌云所以可能访问不到，可以参考已存在的官方issue： https://github.com/helm/helm/issues/7028

#### 在 Mac OS 上安装

##### 通过 brew 安装

```shell
# Use homebrew on Mac
brew install helm

# Add helm repo
helm repo add stable http://mirror.azure.cn/kubernetes/charts/
# Update charts repo
helm repo update

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

#安装ingress-nginx
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.7.1/deploy/static/provider/cloud/deploy.yaml
```


#### 测试 Helm (可选)

安装 Wordpress

```shell
helm install wordpress stable/wordpress
```

查看 wordpress 发布状态

```shell
helm status wordpress
```

卸载 wordpress 发布

```shell
helm uninstall wordpress
```

### 配置 Istio

异构集群的互操作性是通过 Kubernetes 实现的。Istio 将容器化和虚拟机负载整合到单个控制平面中，以统一集群内的流量、安全性和可观测性。但是，随着集群数量、网络环境和用户权限变得越来越复杂，需要在 Istio 的控制平面之上构建另一个管理平面（例如 Tetrate 服务桥）进行混合云管理。

说明：Istio Ingress Gateway和Ingress缺省的端口冲突，请移除Ingress并进行下面测试

可以根据文档安装 Istio https://istio.io/docs/setup/getting-started/

#### 下载 Istio 1.5.0

```bash
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.5.0 sh -
cd istio-1.5.0
export PATH=$PWD/bin:$PATH
```

在Windows上，您可以手工下载Istio安装包，或者把```getLatestIstio.ps1```拷贝到你希望下载 Istio 的目录，并执行 - 说明：根据社区提供的[安装脚本](https://gist.github.com/kameshsampath/796060a806da15b39aa9569c8f8e6bcf)修改而来

```powershell
.\getLatestIstio.ps1
```

#### 安装 Istio

```shell
istioctl manifest apply --set profile=demo
```

#### 检查 Istio 状态

```shell
kubectl get pods -n istio-system
```

#### 为 ```default``` 名空间开启自动 sidecar 注入

```shell
kubectl label namespace default istio-injection=enabled
kubectl get namespace -L istio-injection
```

#### 安装 Book Info 示例

请参考 https://istio.io/docs/examples/bookinfo/

```shell
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
```

查看示例应用资源

```shell
kubectl get svc,pod
```

确认示例应用在运行中

```shell
kubectl exec -it $(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}') -c ratings -- curl productpage:9080/productpage | grep -o "<title>.*</title>"
```

创建 Ingress Gateway

```shell
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

查看 Gateway 配置

```shell
kubectl get gateway
```

确认示例应用可以访问

```shell
export GATEWAY_URL=localhost:80
curl -s http://${GATEWAY_URL}/productpage | grep -o "<title>.*</title>"
```

可以通过浏览器访问

http://localhost/productpage

#### 删除实例应用

```shell
samples/bookinfo/platform/kube/cleanup.sh
```

### 卸载 Istio

```shell
istioctl manifest generate --set profile=demo | kubectl delete -f -
```



#!/bin/bash

# /********************************************************/
# JENKINS: jnlp-slave agent kubernetes
# /********************************************************/

# Source: https://www.youtube.com/watch?v=-saC-Y7Zwqc
# Other : https://hub.docker.com/r/jenkins/jnlp-slave/
# Name  : Create Your First CI/CD Pipeline on Kubernetes With Jenkins

JENKINS: Manage Jenkins -> Configure Clouds

kubernetes Name: kubernetes
kubernetes Namespace: kubernetes
Credentials: none  (test connection)
Jenkins Tunnel:  
      kubectl get svc jenkins-jnlp -n jenkins | awk '{print $3":"$5}' | sed -e 's|/TCP||g'
      CLUSTER-IP:PORT(S)
      10.111.250.180:50000

Create Pod/template with below from YAML:

jenkins-pod           : "slave"
jenkins/label         : "jnlp-slave"
JENKINS_TUNNEL        : "xxx.xxx.xxx.xxx:50000" (kubectl get svc -n jenkins ClusterIP)
JENKINS_AGENT_WORKDIR : "/home/jenkins/agent"
JENKINS_URL           : "http://xxx.xxx.xxx.xxx:30000/"
image                 : "jenkins/jnlp-slave"
imagePullPolicy       : "Always"
name                  : "jnlp"
tty                   : true
workingDir            : "/home/jenkins/agent"
hostNetwork           : false


# /********************************************************/
GIT JENKINS INTEGRATION - CREATE BUILD - HELLOWORLD
# /********************************************************/
# source: https://www.youtube.com/watch?v=bGqS0f4Utn4
# name  : Jenkins Beginner Tutorial 8 - Jenkins integration with GIT (SCM)

New Item : Freesytle Project

Source Code Management  : Git
Repository URL          : https://github.com/karlring-devops/HelloWorld.git
Credentials             : Add -> Jenkins 
Username                : git.user.name
Password                : git.user.password
Credentials             : git.user.name/******
Branch Specifier (blank for 'any') : **
Build (Execute Shell)   : 

cd /var/jenkins_home/workspace/HelloWorld
javac Hello.java
java Hello




# /*********************************************************************/
# --- DEPLOY JENKINS                                                 ---/
# /*********************************************************************/

# Source: https://raw.githubusercontent.com/kubernetes/dashboard/v2.3.1/aio/deploy/recommended.yaml

# sudo kubectl delete -n kube-system deployment jenkins
#sudo kubectl create namespace jenkins

kubectl create namespace jenkins
#kubectl create serviceaccount jenkins --namespace=jenkins

# /**********************************************/
# JENKINS INSTALL/SETUP - JENKINS ON KUBERNETES
# /**********************************************/

main(){
  delit
  cr8namespace
  cr8sa
  cr8role
  cr8rolebinding
  cr8deploy
  cr8service
  #cr8agent
}

delit(){
  kubectl delete -n jenkins pod $(kubectl get pods -n jenkins | tail -1 | awk '{print $1}')
  kubectl delete -n jenkins replicaset $(kubectl get rs -n jenkins | tail -1 | awk '{print $1}')
  kubectl delete -n jenkins service jenkins
  kubectl delete -n jenkins service jenkins-jnlp
  kubectl delete -n jenkins secret $(kubectl get secret -n jenkins | tail -1 | awk '{print $1}')
  kubectl delete -n jenkins role jenkins-admin-sa-role
  kubectl delete -n jenkins serviceaccount jenkins-admin-sa
  kubectl delete -n jenkins deployment jenkins
  kubectl delete namespace jenkins
}


cr8namespace(){
  sudo kubectl create namespace jenkins
}

cr8sa(){
  sudo kubectl create serviceaccount jenkins-admin-sa -n jenkins
  #sudo kubectl create clusterrolebinding jenkins-admin-sa --clusterrole=cluster-admin --serviceaccount=jenkins:jenkins-admin-sa -n jenkins
}

cr8role(){
{
cat <<EOF
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: jenkins
  name: jenkins-admin-sa-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
EOF
} > jenkins-role.yml
kubectl apply -f jenkins-role.yml
}

cr8rolebinding(){
{
cat <<EOF
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: jenkin-admin-sa-role-binding
  namespace: jenkins
subjects:
- kind: ServiceAccount
  name: jenkins-admin-sa
  namespace: jenkins
  apiGroup: ""
roleRef:
  kind: Role
  name: jenkins-admin-sa-role
  apiGroup: ""  
EOF
} > jenkins-role-bind.yml
kubectl apply -f jenkins-role-bind.yml
}

mkdir ~/.kube
cd ~/.kube
#view jenkins.yaml

cr8deploy(){

#  ServiceAccount : https://stackoverflow.com/questions/44505461/how-to-configure-a-non-default-serviceaccount-on-a-deployment
{
cat <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      serviceAccountName: jenkins-admin-sa
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        ports:
          - name: http-port
            containerPort: 8080
          - name: jnlp-port
            containerPort: 50000
        volumeMounts:
          - name: jenkins-vol
            mountPath: /var/jenkins_vol
      volumes:
        - name: jenkins-vol
          emptyDir: {}
EOF
} > jenkins.yml

CWD=`pwd`
sudo kubectl create -f ${CWD}/jenkins.yml --namespace jenkins
}

#view jenkins-service.yaml

cr8service(){
{
cat <<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins
spec:
  serviceAccountName: jenkins-admin-sa
  type: NodePort
  ports:
    - port: 8080
      targetPort: 8080
      nodePort: 30000
  selector:
    app: jenkins

---
apiVersion: v1
kind: Service
metadata:
  name: jenkins-jnlp
spec:
  type: ClusterIP
  ports:
    - port: 50000
      targetPort: 50000
  selector:
    app: jenkins
EOF
} > jenkins-service.yml

CWD=`pwd`
sudo kubectl create -f  ${CWD}/jenkins-service.yml --namespace jenkins --validate=false
}

jcheckit(){
  kubectl auth can-i list pods --namespace jenkins --as jenkins-admin-sa
  kubectl get serviceaccounts -n jenkins
  kubectl get roles -n jenkins -o wide
  kubectl get rolebindings -n jenkins
  kubectl get serviceaccounts/jenkins-admin-sa -o yaml -n jenkins
  kubectl cluster-info
}

jgetlogin(){
MasterIp=$(
    sudo kubectl get nodes -o wide | grep master | awk '{ print $6 }'
    )

NodePort=$(
    sudo kubectl get services --namespace jenkins \
        | grep 'NodePort' \
        | awk '{print $5}' \
        | sed -e 's|\/|:|g' \
        | awk -F':' '{print $2}' 
    )

K8S_SERVICE_NAME=$(
                  sudo kubectl get pods -n jenkins \
                          | grep jenkins \
                          | head -1 \
                          | awk '{print $1}'
                  )
InitialAdminPassword=$(sudo kubectl exec ${K8S_SERVICE_NAME} -n jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword)

cat <<EOF
/**************************************/
/** Jenkins Login Details:           **/
/--------------------------------------/

http://${MasterIp}:${NodePort}

InitialAdminPassword:

${InitialAdminPassword}

EOF
}


cr8agent(){

    JENKINS_AGENT_HOME=/home/jenkins/agent

    wget http://192.168.7.2:30000/jnlpJars/agent.jar
    sudo mkdir -p 
    sudo chmod -R 777 /home/jenkins/agent
    cd 
    java -jar agent.jar -jnlpUrl http://192.168.7.2:30000/computer/jnlp-21t8p/jenkins-agent.jnlp -secret 20af0b762aca2e1618c75b6411faceb036540354ca97122d754448c0553a4374 -workDir "/home/jenkins/agent" &

}

K8S_SERVICE_NAME=$(
                  sudo kubectl get pods -n jenkins \
                          | grep jenkins \
                          | head -1 \
                          | awk '{print $1}'
                  )
kubectl exec --stdin --tty ${K8S_SERVICE_NAME} -n jenkins -- /bin/bash

kbash(){

K8S_SERVICE_NAME=$(
                  sudo kubectl get pods -n ${1} \
                          | grep ${2} \
                          | head -1 \
                          | awk '{print $1}'
                  )
  # kubectl exec --stdin --tty ${K8S_SERVICE_NAME} -n ${1} -- /bin/bash
  kubectl exec -it --stdin --tty ${K8S_SERVICE_NAME} -n ${1} -- /bin/bash
}

# kstat(){ watch kubectl get pods,svc,nodes,rc,pv,pvc -o wide --all-namespaces ; }

kstat(){ watch kubectl get pods,svc,nodes,rc,rs,pv,pvc --all-namespaces ; }

PodName=$(kubectl get pods -n ${NameSpace} | grep ${NameSpace} | awk '{print $1}')
ContainerID=$(kubectl describe pod ${PodName} -n jenkins | egrep 'Container' | grep ID | awk '{print $3}')

kbashNodeRoot kube1
K8S_CONTAINER_ID=$(docker container ls | grep jenkins | grep -v pause | awk '{print $1}')
docker exec -it -u root ${K8S_CONTAINER_ID} /bin/bash


nsenter-node.sh

#!/bin/sh
set -x

kbashnode(){
    # //Source: https://alexei-led.github.io/post/k8s_node_shell/
    node=${1}
    nodeName=$(kubectl get node ${node} -o template --template='{{index .metadata.labels "kubernetes.io/hostname"}}') 
    nodeSelector='"nodeSelector": { "kubernetes.io/hostname": "'${nodeName:?}'" },'
    podName=${USER}-nsenter-${node}

    kubectl run ${podName:?} --restart=Never -it --rm --image overriden --overrides '
    {
      "spec": {
        "hostPID": true,
        "hostNetwork": true,
        '"${nodeSelector?}"'
        "tolerations": [{
            "operator": "Exists"
        }],
        "containers": [
          {
            "name": "nsenter",
            "image": "alexeiled/nsenter:2.34",
            "command": [
              "/nsenter", "--all", "--target=1", "--", "su", "-"
            ],
            "stdin": true,
            "tty": true,
            "securityContext": {
              "privileged": true
            }
          }
        ]
      }
    }' --attach "$@"
}

kbashnode kube2

PodName=$(docker container ls | grep jenkins | grep -v pause | awk '{print $12}' | cut -d_ -f3)
ContainerID=$(docker container ls | grep jenkins | grep -v pause | awk '{print $1}')
echo $ContainerID 
# 2eed871e42e0

docker exec -it -u root "${ContainerID}" /bin/bash
  apt install maven


kbashcmd(){
  # Source: https://medium.com/@nnilesh7756/copy-directories-and-files-to-and-from-kubernetes-container-pod-19612fa74660
  NameSpace=${1}
  BashCommand="${2}"
  kubectl exec -it --namespace=${NameSpace} $(kubectl get pods -n ${NameSpace} | grep ${NameSpace} | awk '{print $1}') -- bash -c "${BashCommand}"
}

kbashcmd jenkins "mkdir /var/jenkins_home_restore"

kjbackup(){
  
    LOCAL_ARCHIVE_DIR=~/uga/data/backup/jenkins
       K8S_NAME_SPACE=${1} 
  JENKINS_BACKUP_FILE=${2}
         K8S_POD_NAME=$(kubectl get pods -n ${K8S_NAME_SPACE} | grep ${K8S_NAME_SPACE} | awk '{print $1}')
   JENKINS_REMOTE_DIR=/tmp/data/backup/jenkins

    kubectl cp ${K8S_NAME_SPACE}/${K8S_POD_NAME}:${JENKINS_REMOTE_DIR}/${JENKINS_BACKUP_FILE} ${LOCAL_ARCHIVE_DIR}/${JENKINS_BACKUP_FILE}
    echo && pwd && echo && ls -alhtr ${LOCAL_ARCHIVE_DIR}
}

kjbackup jenkins backup_20210805_0830.tar.gz

kjrestore(){
 
    LOCAL_ARCHIVE_DIR=~/uga/data/backup/jenkins
       K8S_NAME_SPACE=${1} 
  JENKINS_BACKUP_FILE=${2}
         K8S_POD_NAME=$(kubectl get pods -n ${K8S_NAME_SPACE} | grep ${K8S_NAME_SPACE} | awk '{print $1}')
   JENKINS_REMOTE_DIR=/tmp/data/backup/jenkins

    kubectl cp ${LOCAL_ARCHIVE_DIR}/${JENKINS_BACKUP_FILE} ${K8S_NAME_SPACE}/${K8S_POD_NAME}:${JENKINS_REMOTE_DIR}/${JENKINS_BACKUP_FILE}
    echo && pwd && echo 
    kubectl exec -it --namespace=${K8S_NAME_SPACE} ${K8S_POD_NAME} -- bash -c "ls -alhtr ${JENKINS_REMOTE_DIR}"  
}



kjrestore jenkins backup_20210801_0329.tar.gz 

backup_20210805_0830.tar.gz
/tmp/data/backup/jenkins/backup_20210805_0830.tar.gz

kjbackup backup_20210801_0329.tar.gz

kbash jenkins jenkins-6fb74d87f6-hcvr2
 mkdir -p /tmp/data/backup/jenkins
 chmod -R 777 /tmp/data/backup/jenkins
 exit

FILE=backup_20210801_0329.tar.gz
FILE_LOCAL=~/uga/data/backup/jenkins/${FILE}
FILE_REMOTE=/tmp/data/backup/jenkins/${FILE}

kubectl cp ${FILE_LOCAL} jenkins/jenkins-6fb74d87f6-hcvr2:${FILE_REMOTE}

kubectl exec -it --namespace=tools mongo-pod -- bash -c "mongo"


# /********************************************************/
# KREW INSTALL
# /********************************************************/
# SOURCE: https://krew.sigs.k8s.io/docs/user-guide/setup/install/

(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.tar.gz" &&
  tar zxvf krew.tar.gz &&
  KREW=./krew-"${OS}_${ARCH}" &&
  "$KREW" install krew
)

echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' | tee -a ~/.bashrc

kubectl krew install exec-as
kubectl krew install prompt

kubectl exec-as -u root pod-69bfb5ffc7-kc2bs

kubectl exec-as -u root jenkins-5c6c476487-5qdvx

510 402 8545

# /********************************************************/
# JENKINS: jnlp-slave agent kubernetes
# /********************************************************/

# Source: https://www.youtube.com/watch?v=-saC-Y7Zwqc
# Other : https://hub.docker.com/r/jenkins/jnlp-slave/
# Name  : Create Your First CI/CD Pipeline on Kubernetes With Jenkins

Create Pod/template with below from YAML:

jenkins-pod           : "slave"
jenkins/label         : "jnlp-slave"
JENKINS_TUNNEL        : "10.97.133.149:50000" (kubectl get svc -n jenkins ClusterIP)
JENKINS_AGENT_WORKDIR : "/home/jenkins/agent"
JENKINS_URL           : "http://192.168.7.2:30000/"
image                 : "jenkins/jnlp-slave"
imagePullPolicy       : "Always"
name                  : "jnlp"
tty                   : true
workingDir            : "/home/jenkins/agent"
hostNetwork           : false

# /-----------------------/
# Console Output
# /-----------------------/
# Started by user jenkins
# Running as SYSTEM
# Agent jnlp-tqvq8 is provisioned from template jnlp
# ---
# apiVersion: "v1"
# kind: "Pod"
# metadata:
#   labels:
#     jenkins-pod: "slave"
#     jenkins/label-digest: "bb74484d3d8cfdd5465f289d1fe175836bf9e531"
#     jenkins/label: "jnlp-slave"
#   name: "jnlp-tqvq8"
# spec:
#   containers:
#   - env:
#     - name: "JENKINS_SECRET"
#       value: "********"
#     - name: "JENKINS_TUNNEL"
#       value: "10.97.133.149:50000"
#     - name: "JENKINS_AGENT_NAME"
#       value: "jnlp-tqvq8"
#     - name: "JENKINS_NAME"
#       value: "jnlp-tqvq8"
#     - name: "JENKINS_AGENT_WORKDIR"
#       value: "/home/jenkins/agent"
#     - name: "JENKINS_URL"
#       value: "http://192.168.7.2:30000/"
#     image: "jenkins/jnlp-slave"
#     imagePullPolicy: "Always"
#     name: "jnlp"
#     resources:
#       limits: {}
#       requests: {}
#     tty: true
#     volumeMounts:
#     - mountPath: "/home/jenkins/agent"
#       name: "workspace-volume"
#       readOnly: false
#     workingDir: "/home/jenkins/agent"
#   hostNetwork: false
#   nodeSelector:
#     kubernetes.io/os: "linux"
#   restartPolicy: "Never"
#   volumes:
#   - emptyDir:
#       medium: ""
#     name: "workspace-volume"

# Building remotely on jnlp-tqvq8 (jnlp-slave) in workspace /home/jenkins/agent/workspace/test
# [test] $ /bin/sh -xe /tmp/jenkins5743626022052088383.sh
# + sleep 60

# Finished: SUCCESS

# /********************************************************/


# /********************************************************/
GIT JENKINS INTEGRATION - CREATE BUILD
# /********************************************************/
# source: https://www.youtube.com/watch?v=bGqS0f4Utn4
# name  : Jenkins Beginner Tutorial 8 - Jenkins integration with GIT (SCM)

New Item : Freesytle Project

Source Code Management  : Git
Repository URL          : https://github.com/karlring-devops/HelloWorld.git
Credentials             : Add -> Jenkins 
Username                : 
Password                : 
Credentials             : /******
Branch Specifier (blank for 'any') : **
Build (Execute Shell)   : 

cd /var/jenkins_home/workspace/HelloWorld
javac Hello.java
java Hello

# /********************************************************/
# JENKINS CLI - BUILD
# /********************************************************/
# source: https://www.jenkins.io/doc/book/managing/cli/

# Tokens: https://stackoverflow.com/questions/45466090/how-to-get-the-api-token-for-jenkins
# JENKINS -> USER -> CONFIGURE -> API Token -> Generate -> Copy
# apitoken : 11bd03efda038e8ab9048c79e63a847138
    # Log in to Jenkins.
    # Click you name (upper-right corner).
    # Click Configure (left-side menu).
    # Use "Add new Token" button to generate a new one then name it.
    # You must copy the token when you generate it as you cannot view the token afterwards.
    # Revoke old tokens when no longer needed.


jenv(){
         JENKINS_URL="${1}" #/--- eg. 'http://192.168.7.2:30000'
        JENKINS_USER=${2}   #/--- eg. jenkins
       JENKINS_TOKEN=${3}   #/--- eg. asdiasbiou23t43njk34nkj34k3j4h3k4
        JENKINS_AUTH="${JENKINS_USER}:${JENKINS_TOKEN}"
   JENKINS_HOME_USER=~/.jenkins

    [ ! -d ${JENKINS_HOME_USER} ] && mkdir ${JENKINS_HOME_USER}
    cd ${JENKINS_HOME_USER}
    [ -f jenkins-cli.jar ] && rm -f jenkins-cli.jar
    wget "${JENKINS_URL}/jnlpJars/jenkins-cli.jar"
}

   jhelp(){ cd ${JENKINS_HOME_USER} ; java -jar jenkins-cli.jar -s ${JENKINS_URL} -auth ${JENKINS_AUTH} help ; }
jplugins(){ cd ${JENKINS_HOME_USER} ; java -jar jenkins-cli.jar -s ${JENKINS_URL} -auth ${JENKINS_AUTH} list-plugins ; }

jinstall(){
            JENKINS_PLUGIN="${1}" #/--- eg. 'https://updates.jenkins-ci.org/download/plugins/gitbucket/0.8/gitbucket.hpi'
            cd ${JENKINS_HOME_USER} ; java -jar jenkins-cli.jar -s ${JENKINS_URL} -auth ${JENKINS_AUTH} install-plugin ${JENKINS_PLUGIN}
          }


# /********************************************************/

# /********************************************************/
# WORDPRESS - MYSQL DEPLOYMENT
# /********************************************************/
# Source:  https://pwittrock.github.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/

kcr8wpmysql(){
  wget https://raw.githubusercontent.com/kubernetes/examples/master/mysql-wordpress-pd/mysql-deployment.yaml
  wget https://raw.githubusercontent.com/kubernetes/examples/master/mysql-wordpress-pd/wordpress-deployment.yaml
  wget https://raw.githubusercontent.com/kubernetes/examples/master/mysql-wordpress-pd/local-volumes.yaml

  kubectl create -f local-volumes.yaml
  sleep 60
  kubectl create secret generic mysql-pass --from-literal=password=password
  sleep 30
  kubectl create -f mysql-deployment.yaml
  sleep 60
  kubectl create -f wordpress-deployment.yaml
  sleep 60
  kubectl get deployment,pod,svc,endpoints,pvc -l app=wordpress -o wide &&   kubectl get secret mysql-pass &&   kubectl get pv
  kgetloginwpmysql
}

kdelwpmysql(){
  kubectl delete -k ./
  kubectl delete -n default secret mysql-pass
}

kgetloginwpmysql(){

MasterIp=$(
    sudo kubectl get nodes -o wide | grep master | awk '{ print $6 }'
    )

NodePort=$(
    sudo kubectl get services --namespace default \
        | grep 'LoadBalancer' \
        | awk '{print $5}' \
        | sed -e 's|\/|:|g' \
        | awk -F':' '{print $2}' 
    )

cat <<EOF
/**************************************/
/** WORDPRESS Login Details:         **/
/--------------------------------------/

http://${MasterIp}:${NodePort}

EOF
}

kbash default wordpress <<EOF
apt update
apt install git
EOF

git init
git config --global user.email "karl.ring.oracle.dba@gmail.com"
git config --global user.name "captain"
git commit -m "first commit"
git branch -M main
git remote add origin git@github.com:karlring-devops/wpmysql-demo

git remote add origin https://github.com/karlring-devops/wpmysql-demo.git
git push -u origin main



# …or create a new repository on the command line

echo "# wpmysql-demo" >> README.md
git init
git add README.md
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/karlring-devops/wpmysql-demo.git
git push -u origin main


…or push an existing repository from the command line

git remote add origin https://github.com/karlring-devops/wpmysql-demo.git
git branch -M main
git push -u origin main

echo "Hello World!!!" > README.md
git add README.md
git commit -m "first commit"


git remote add origin https://github.com/karlring-devops/jenkins-kubernetes-pod.git
git branch -M main
git push -u origin main

# /****************************************/
# TOMCAT
# /****************************************/
# Source : https://www.youtube.com/watch?v=TbhJmDkNwm0
# Namespace YML: https://cloud.google.com/blog/products/containers-kubernetes/kubernetes-best-practices-organizing-with-namespaces
# tomcat-namespace.yaml
{
cat <<EOF
---
kind: Namespace
apiVersion: v1
metadata:
  name: tomcat
  labels:
    name: tomcat
EOF
}  > tomcat-namespace.yaml


# # persistent-volumes.yaml
# {
# cat <<EOF
# ---
# apiVersion: v1
# kind: PersistentVolume
# metadata:
#   name: pv-1
#   namespace: tomcat
#   labels:
#     type: pv-cluster
# spec:
#   capacity:
#     storage: 20Gi
#   accessModes:
#     - ReadWriteOnce
#   hostPath:
#     path: /tmp/data/pv-1
# ---
# apiVersion: v1
# kind: PersistentVolume
# metadata:
#   name: pv-2
#   namespace: tomcat
#   labels:
#     type: pv-cluster
# spec:
#   capacity:
#     storage: 20Gi
#   accessModes:
#     - ReadWriteOnce
#   hostPath:
#     path: /tmp/data/pv-2
# EOF
# } > persistent-volumes.yaml

{
cat <<EOF
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-volume-tomcat
  namespace: tomcat
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"
EOF
} > create-pv-tomcat.yaml

{
cat <<EOF
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pv-volume-tomcat
  namespace: tomcat
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
EOF
} > create-pv-claim-tomcat.yaml

# # persistent-volume-claims.yaml
# {
# cat <<EOF
# ---
# apiVersion: v1
# kind: PersistentVolumeClaim
# metadata:
#   name: pv-1
#   namespace: tomcat
# spec:
#   storageClassName: manual
#   accessModes:
#     - ReadWriteOnce
#   resources:
#     requests:
#       storage: 3Gi
# EOF
# } > persistent-volume-claims.yaml

kubectl delete -n tomcat persistentvolumeclaim pv-1

# tomcat-deployment.yaml
{
cat <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tomcat-deployment
  namespace: tomcat
  labels:
    app: tomcat
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tomcat
  replicas: 2
  template:
    metadata:
      labels:
        app: tomcat
    spec:
      containers:
      - name: tomcat-container
        image: tomcat:8.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "250Mi"
            cpu: "500m"
        volumeMounts:
        - name: tomcat-persistent-storage
          mountPath: /var/lib/tomcat
      volumes:
      - name: tomcat-persistent-storage
        persistentVolumeClaim:
          claimName: pv-volume-tomcat
EOF
} > tomcat-deployment.yaml

# apiVersion: v1
# kind: Pod
# metadata:
#   name: mypod
#   namespace: test
#   labels:
#     name: mypod
# spec:
#   containers:
#   - name: mypod
#     image: nginx

# tomcat-service.yaml 
{
cat <<EOF
---
kind: Service
apiVersion: v1
metadata:
  name: tomcat-service
  namespace: tomcat
spec:
  type: LoadBalancer
  selector:
    app: tomcat
  ports:
  - name: http
    protocol: TCP
    port: 8080
    targetPort: 8080
EOF
} > tomcat-service.yaml

kcr8tomcat(){
  kubectl create -f tomcat-namespace.yaml
  kubectl create -f create-pv-tomcat.yaml
  kubectl create -f create-pv-claim-tomcat.yaml
  kubectl create -f tomcat-deployment.yaml
  kubectl create -f tomcat-service.yaml
}

# /****************************************/

kdelpod(){ kubectl delete pod ${2} -n ${1} --grace-period 0 --force ; }
kdelpod default tomcat-deployment-7d785c4ccd-rgkrq

kdelpod tomcat tomcat-deployment-fb5f96945-79xgp
kdelpod tomcat tomcat-deployment-fb5f96945-q79x6










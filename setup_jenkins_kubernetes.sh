# /****************************************/
# JENKINS
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
  name: jenkins
  labels:
    name: jenkins
EOF
}  > jenkins-namespace.yaml

#jenkins-role.yml
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


# jenkins-role-bind.yml
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

{
cat <<EOF
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-volume-jenkins
  namespace: jenkins
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
} > create-pv-jenkins.yaml

{
cat <<EOF
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pv-volume-jenkins
  namespace: jenkins
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF
} > create-pv-claim-jenkins.yaml




# jenkins-deployment.yaml
{
cat <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
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
        - name: jenkins-persistent-storage
          mountPath: /var/jenkins_vol
      volumes:
      - name: jenkins-persistent-storage
        persistentVolumeClaim:
          claimName: pv-volume-jenkins
EOF
} > jenkins-deployment.yaml

# Source: https://dev.to/techworld_with_nana/run-pod-with-root-privileges-41n9
# Solution:

# In order to run a container inside a pod with root, add following config:

# apiVersion: extensions/v1beta1
# kind: Deployment
# metadata:
#   name: my-app
# spec:
#   template: 
#     spec:
#       containers:
#       - image: my-image
#         name: my-app
#         ...
#         securityContext:
#           allowPrivilegeEscalation: false
#           runAsUser: 0


# jenkins-service.yaml 
{
cat <<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins-service
  namespace: jenkins
spec:
  # serviceAccountName: jenkins-admin-sa
  type: NodePort
  ports:
    - port: 8080
      targetPort: 8080
      nodePort: 30000
  selector:
    app: jenkins
EOF
} > jenkins-service.yaml

# jenkins-service-jnlp.yaml 
{
cat <<EOF
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins-jnlp
  namespace: jenkins
spec:
  type: ClusterIP
  ports:
    - port: 50000
      targetPort: 50000
  selector:
    app: jenkins
EOF
} > jenkins-service-jnlp.yaml



kcr8jenkins(){
kubectl create -f jenkins-namespace.yaml
kubectl apply -f jenkins-role.yml
kubectl apply -f jenkins-role-bind.yml
kubectl create serviceaccount jenkins-admin-sa -n jenkins
kubectl create clusterrolebinding jenkins-admin-sa --clusterrole=cluster-admin --serviceaccount=jenkins:jenkins-admin-sa -n jenkins

kubectl create -f create-pv-jenkins.yaml
kubectl create -f create-pv-claim-jenkins.yaml
kubectl create -f jenkins-deployment.yaml
kubectl create -f jenkins-service.yaml --validate=false
kubectl create -f jenkins-service-jnlp.yaml
kubectl scale -n jenkins deployment jenkins --replicas=1
}

kdeljenkins2(){
  kubectl delete namespace jenkins
  kubectl delete persistentvolume pv-volume-jenkins
  kubectl delete persistentvolume pv-volume-jenkins
  kubectl delete clusterrolebinding jenkins-admin-sa
}

kdeljenkins(){
  kubectl delete -n jenkins service jenkins-service
  kubectl delete -n jenkins service jenkins-jnlp
  kubectl delete -n jenkins deployment jenkins-deployment
  kubectl delete -n jenkins role jenkins-admin-sa-role
  kubectl delete -n jenkins rolebinding jenkin-admin-sa-role-binding
  kubectl delete clusterrolebinding jenkins-admin-sa
  kubectl delete -n jenkins serviceaccount jenkins-admin-sa
  kubectl delete -n jenkins persistentvolumeclaim pv-volume-jenkins
  kubectl delete persistentvolume pv-volume-jenkins
  kubectl delete namespace jenkins
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

kstat(){ watch kubectl get pods,svc,nodes,rc,rs,pv,pvc --all-namespaces ; }

main(){
  echo -n "Enter action (create/destroy): "
  read VAR

  if [[ $VAR == "create" ]] ; then
    kcr8tomcat
    kstat
  elif [[ $VAR == "destroy" ]] ; then
    kdeltomcat
    kstat
  else
    echo '[ERR] Please enter "create" or "destroy"...'
  fi
}

main



# /****************************************/

kdelpod(){ kubectl delete pod ${2} -n ${1} --grace-period 0 --force ; }

# kdelpod tomcat tomcat-deployment-fb5f96945-79xgp
# kdelpod tomcat tomcat-deployment-fb5f96945-q79x6

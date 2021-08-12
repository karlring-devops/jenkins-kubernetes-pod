# jenkins-kubernetes-pod
jenkins-kubernetes-pod

#!/bin/bash

# /********************************************************/
# JENKINS: jnlp-slave agent kubernetes
# /********************************************************/

# Source: https://www.youtube.com/watch?v=-saC-Y7Zwqc
# Other : https://hub.docker.com/r/jenkins/jnlp-slave/
# Name  : Create Your First CI/CD Pipeline on Kubernetes With Jenkins

-----------------------------------------------
1) JENKINS: Manage Jenkins -> Configure Clouds

*Kubernetes*
Name				:	kubernetes
Kubernetes URL		:   https://192.168.7.2:6443 (k8s cluster-info -- master node)
kubernetes Namespace: 	kubernetes
Credentials			:  	none
Jenkins tunnel		:	10.100.134.95:50000 (k8s get svc -o wide)

*Pod Label*
Key					:	jenkins
Value				: 	slave

*Advanced*
Defaults Provider Template Name	:	jnlp-slave

	*Pod Templates* 
	Name				:	jnlp-slave
	
	*Pod Template Details* 
	Namespace			:	jenkins
	Labels				:	jnlp-slave
	Usage				:	Use node as much as possible
	
		*Containers*
		
		Name				:	jnlp
		Docker Image		:	jenkins/jnlp-slave
		Working directory	:	/home/jenkins/agent
		Allocate pseudo-TTY	: 	YES
		
		Show raw yaml in console :	YES

		
---- SAVE -----

2) DISABLE BUILD EXECUTOR ON MASTER: 
	
	-- DASHBOARD -> MANAGE JENKINS -> MANAGE NODES AND CLOUD
					-> MASTER -> CONFIGURE
		Number of executors	:	0 (zero)

---- SAVE -----

3) CONFIGURE JOB TO USE jnlp-slave

	JOB -> CONFIGURE 		

	Restrict where this project can be run	:		YES
	Label Expression						:		jnlp-slave

	Should see this message appear:
	
	"Label jnlp-slave matches no nodes and 1 cloud. 
	 Permissions or other restrictions provided by 
	 plugins may further reduce that list."

-----------------------------------------------

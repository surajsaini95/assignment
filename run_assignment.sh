#!/bin/bash
#
# SCRIPT: run_assignment
# AUTHOR: Suraj Saini
#
# PURPOSE: automation for making blue/green deployments and testing APIs. 
#
################################################################
#          			Define functions here              		   #

checkMinikube() {
	echo "----------------------------------------------------------------------------------"
	if [[ $(minikube status | grep "not found") ||  $(minikube status | grep "Stopped") ]]; then
		echo "Minikube is not running"
		echo "Starting Minikube now..."
		minikube start
	else
		echo "Minikube is running"
		minikube status
	fi
	eval $(minikube docker-env)
	echo -e "Configured minikube to use Docker daemon for your kubernetes cluster\n"	
	sleep 3s
	echo "----------------------------------------------------------------------------------"	
}

checkHelm() {
	echo "----------------------------------------------------------------------------------"
	if [[ $(helm version | grep "not found") ]]; then
		echo "Helm not found"
		echo "Installing Helm now..."
		curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
	else
		echo "Helm found"
	fi
	sleep 2s
	echo "----------------------------------------------------------------------------------"	
}

replaceEnvInCode() {
	echo "----------------------------------------------------------------------------------"
	FLASKAPI="userapp/flaskapi.py"
	ENV_NEW=`echo ${1^^}`
	[[ $ENV_NEW == "BLUE" ]] && ENV_OLD=GREEN || ENV_OLD=BLUE
	echo "New : $ENV_NEW"
	echo "Old : $ENV_OLD"
	sed -i 's/'"$ENV_OLD"'/'"$ENV_NEW"'/gI' $FLASKAPI 
	echo "----------------------------------------------------------------------------------"
}

dockerImages() {
	echo "----------------------------------------------------------------------------------"
	MYSQL_IMAGE=mysql:latest
	APP_IMAGE=userapp:$1

	echo -e "\nPulling $MYSQL_IMAGE\n"
	docker pull $MYSQL_IMAGE

	# change env in source code
	replaceEnvInCode $1

	echo -e "\nBUilding image for userapp as $APP_IMAGE\n"
	docker build -t $APP_IMAGE ./userapp 
	echo "----------------------------------------------------------------------------------"	
}

createHostPathForPV() {
	echo "----------------------------------------------------------------------------------"	
	HOSTPATH_DIR="/mnt/$1"
	echo "Create a directory that will be used as hostpath by PV for persistence"
	sudo -- sh -c "mkdir -p $HOSTPATH_DIR"
	[[ -d $HOSTPATH_DIR ]] && echo "directory created" || echo "directory not created , please check"
	echo "----------------------------------------------------------------------------------"		
}

switchTraffic() {
	echo "----------------------------------------------------------------------------------"
	echo "Switching traffic from $2 to $3"
    sleep 5s
    kubectl get ingress userapp-ingress -o json \
        | jq '(.spec.rules['"$1"'].http.paths[].backend.service.name | select(. == "'"$2"'-test-userapp-svc")) |= "'"$3"'-test-userapp-svc"' \
        | kubectl apply -f -

    # kubectl describe ingress userapp-ingress
	echo "----------------------------------------------------------------------------------"	
}

stopDeployment() {
    echo "----------------------------------------------------------------------------------"
	echo "ENV should be either blue or green"
    exit
    echo "----------------------------------------------------------------------------------"
}

makeDeployment() {
    echo "----------------------------------------------------------------------------------"	
	echo "Starting with $1 deployment"
	ENV=$1
    if [[ `helm status $ENV | grep STATUS | wc -l` == 1 ]]; then
		echo "Upgrading deployment in $ENV environment"
        helm upgrade $ENV test -f test/$ENV-values.yaml --reuse-values
	else
		echo "Making a new deployment in $ENV environment"
        echo -e "\nEnter mysql_root_password: "  
		read MYSQL_ROOT_PASSWORD  
		helm install $ENV test -f test/$ENV-values.yaml --set mysql_root_password=$MYSQL_ROOT_PASSWORD --set appService.externalIP=`minikube ip`
		populateDB $ENV
	fi
}

populateDB() {
	echo "----------------------------------------------------------------------------------"	
	echo "Populating DB with existing dump"
	# this is required as it will allow proper spinning up of pod and then proceed with dump.
	sleep 30s
	MYSQL_POD=`kubectl  get po -o custom-columns=":metadata.name" | grep -m1 $1-test-mysql`
	# echo "pod = $MYSQL_POD"
	kubectl  exec -i pod/$MYSQL_POD -- mysql -u root -p$MYSQL_ROOT_PASSWORD < userapp_dump.sql
	echo "----------------------------------------------------------------------------------"	
}

availableAPIs() {
	echo "----------------------------------------------------------------------------------"
	echo "THis is a loop for API interaction:"
	echo "Select any one from the following:"
	echo -e "\t1.Health Check"
	echo -e "\t2.Create user"
	echo -e "\t3.Get a user"
	echo -e "\t4.Get all users"
	echo -e "\t5.Update a user"
	echo -e "\t6.Delete a user"
	echo -e "\t7.Finish Testing and exit"
	echo "----------------------------------------------------------------------------------"
}

setupIngress() {
	echo "----------------------------------------------------------------------------------"
	echo "Setting up ingress"
	minikube addons enable ingress
	sleep 30s
	kubectl apply -f ingress.yaml
	NEW_HOST_ENTRY="`minikube ip` $1.userapp.info"
	echo "$NEW_HOST_ENTRY"
	echo "Updating /etc/hosts file"
	[[ `grep "$NEW_HOST_ENTRY" /etc/hosts | wc -l` != 1 ]] && \
		sudo -- sh -c "echo $NEW_HOST_ENTRY >> /etc/hosts" && \
		echo "Added new hosts entry"
	echo "----------------------------------------------------------------------------------"
}

deploy_blue_green() {
    echo -e "\n\n\n----------------------------------------------------------------------------------"
	
    checkMinikube
	checkHelm
	dockerImages $ENV
	createHostPathForPV $ENV
    
	setupIngress $ENV

    SWITCH_FROM=$ENV
    [[ $SWITCH_FROM = "blue" ]] && SWITCH_TO=green && RULE_NO=1
    [[ $SWITCH_FROM = "green" ]] && SWITCH_TO=blue && RULE_NO=2
    
	switchTraffic $RULE_NO $SWITCH_FROM $SWITCH_TO
    
    makeDeployment $ENV
	sleep 10s
    switchTraffic $RULE_NO $SWITCH_TO $SWITCH_FROM

	echo "Deployment Complete..."
	sleep 5s
	echo "----------------------------------------------------------------------------------"
}

testAssignment() {
	echo -e "\n\n\n----------------------------------------------------------------------------------"
	choice=0
	# APP_URL=`minikube service $(kubectl get svc -o custom-columns=":metadata.name" | grep userapp) --url`
	APP_URL=$ENV.userapp.info
	echo "APP_URL : $APP_URL"
	sleep 2s
	until [ $choice -eq 7 ]
	do
	  availableAPIs
	  echo "Enter your choice:"
	  read choice
	  case $choice in
	    1) curl $APP_URL
	      ;;
	    2)echo "Enter user name:" 
		  read USER_NAME
		  echo "Enter user email:" 
		  read USER_EMAIL
		  echo "Enter user password:" 
		  read USER_PASS
		  curl -H "Content-Type: application/json" -d '{"name": "'"$USER_NAME"'", "email": "'"$USER_EMAIL"'", "pwd": "'"$USER_PASS"'"}' $APP_URL/create
	      ;;

	    3)echo "Enter user id:" 
		  read USER_ID 
		  curl $APP_URL/user/$USER_ID | jq '.'
	      ;;

	    4)echo "Displaying all users:"  
		  curl $APP_URL/users | jq '.'
	      ;;

	    5)echo "Enter user id to update user:" 
		  read USER_ID
		  echo "Enter user name:" 
		  read USER_NAME
		  echo "Enter user email:" 
		  read USER_EMAIL
		  echo "Enter user password:" 
		  read USER_PASS
	      curl -H "Content-Type: application/json" -d '{"name": "'"$USER_NAME"'", "email": "'"$USER_EMAIL"'", "pwd": "'"$USER_PASS"'", "user_id": "'"$USER_ID"'"}' $APP_URL/update
	      ;;

	    6)echo "Enter user id to delete user:" 
		  read USER_ID 
		  curl -H "Content-Type: application/json" $APP_URL/delete/$USER_ID
	      ;;
	    7) echo "Exiting from loop"
	      ;;
	    *)
	      echo "Invalid choice...try again"
	      ;;
	  esac
	  sleep 1s
	  echo -e "\n\n"
	done
	echo "We are done with testing"
	echo "----------------------------------------------------------------------------------"
	
}

thanks () {
	echo "----------------------------------------------------------------------------------"
	echo "Thanks for you time."
	echo "Please do share the feedback."
	echo "----------------------------------------------------------------------------------"
	
}

################################################################
#          Beginning of Main  - call functions                 #

echo "Welcome....."
echo -e "\nEnter either 'blue' or 'green' to start:"  
read INPUT1

STOP_FLAG=1
[[ "$INPUT1" = "blue" ]] && ENV=blue && STOP_FLAG=0
[[ "$INPUT1" = "green" ]] && ENV=green && STOP_FLAG=0
[[ $STOP_FLAG = 1 ]] && stopDeployment

echo -e "\n\nPress 'y' to make $ENV deployment: "  
read INPUT2
[[ $INPUT2 == "y" ]] && deploy_blue_green

echo -e "\n\nPress 'y' to test $ENV APIs interactively: "  
read INPUT2
[[ $INPUT2 == "y" ]] && testAssignment

thanks

################################################################
#						 End of script						   #
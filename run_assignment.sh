#!/bin/bash
#
# SCRIPT: run_assignment
# AUTHOR: Suraj Saini
#
# PURPOSE: automation for running and testing assignment. 
#
################################################################
#          Define functions here                     #

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
	echo "----------------------------------------------------------------------------------"	
}

dockerImages() {
	echo "----------------------------------------------------------------------------------"
	
	MYSQL_IMAGE=mysql:latest
	APP_IMAGE=userapp:latest

	echo -e "\nPulling $MYSQL_IMAGE\n"
	docker pull $MYSQL_IMAGE

	echo -e "\nBUilding image for userapp as $MYSQL_IMAGE\n"
	docker build -t $APP_IMAGE ./userapp 
	
	echo "----------------------------------------------------------------------------------"	
}

createHostPathForPV() {
	echo "----------------------------------------------------------------------------------"	
	HOSTPATH_DIR="/mnt/data"
	echo "Create a directory that will be used as hostpath by PV for persistence"
	mkdir -p $HOSTPATH_DIR
	[[ -d $HOSTPATH_DIR ]] && echo "directory created" || echo "directory not created , please check"
	echo "----------------------------------------------------------------------------------"		
}

deployHelmChart() {
	echo "----------------------------------------------------------------------------------"	
	echo "Starting with the Helm deployment"
	echo -e "\nEnter mysql_root_password: "  
	read MYSQL_ROOT_PASSWORD  
	helm install myapp test --set mysql_root_password=$MYSQL_ROOT_PASSWORD --set appService.externalIP=`minikube ip`
	echo "----------------------------------------------------------------------------------"		
}

populateDB() {
	echo "----------------------------------------------------------------------------------"	
	echo "Populating DB with existing dump"
	# this is required as it will allow proper spinning up of pod and then proceed with dump.
	sleep 30s
	MYSQL_POD=`kubectl get po -o custom-columns=":metadata.name" | grep -m1 mysql`
	kubectl exec -i pod/$MYSQL_POD -- mysql -u root -p$MYSQL_ROOT_PASSWORD < userapp_dump.sql
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

testAssignment() {
	echo "----------------------------------------------------------------------------------"
	choice=0
	APP_URL=`minikube service $(kubectl get svc -o custom-columns=":metadata.name" | grep userapp) --url`
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

checkMinikube
checkHelm
dockerImages
createHostPathForPV
deployHelmChart
populateDB
testAssignment
thanks

################################################################
# End of script
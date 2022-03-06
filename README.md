# Deploying a User CRUD App with MySQL on Kubernetes via blue/green deployment.

## Prerequisites or tools req.
1. `docker` 
2. `minikube`
2. `helm`
2. `jq`


## Getting started
1. Clone the repository
2. Execute `bash run_assignment.sh` script.
3. `main` branch makes a plain deployment with any deployment strategy.
4. `deployment/blue-green` branch makes deployment with blue/green strategy.
5. switch the branch as required.
6. Everything will be deployed in default namespace.

## About run_assignment.sh
This script can be used to run and test the assignment.
It will do the following this for you:
1. Accept the ENV you want to use.
2. Ask to make deployment in the choosen ENV, enter 'y' to proceed with deployment.
   a. Check the minikube status and start it if req.
   b. Check whether `helm` is available or not.
   c. Pull and build the required docker images.
   d. Create hostpath dir to be used by PV for persistence.
   e. Setup ingress in minikube 
   f. Switch trafic from blue/green to green/blue.
   g. Make deployment via `helm` chart.
   h. Switch trafic from back.
   i. Ends deployment
3. Asks to interact with APIs deployed in the choosen ENV, enter 'y' to proceed.
   a. Menu based loop will run to accept inputs and fire APIs.
   b. APIs available are:
      i.    Health Check
	   ii.   Create user"
	   iii.  Get a user"
	   iv.   Get all users"
	   v.    Update a user"
	   vi.   Delete a user"
	c. Press '7' to finish Testing and exit"
	

## Expose the APP
The APP can be accessed by following URLs:
1. green.userapp.info
   Hit this via `curl` or via `browser` you will see the `GREEN: I am healthy and functioning` message.
2. blue.userapp.info
   Hit this via `curl` or via `browser` you will see the `BLUE: I am healthy and functioning` message.


## APIs Available
You can use the `API` to `CRUD` your database:
1. Add a user: 
   `curl -H "Content-Type: application/json" -d '{"name": "<user_name>", "email": "<user_email>", "pwd": "<user_password>"}' <APP_URL>/create`
2. Get all users: 
   `curl <APP_URL>/users`
3. Get a specific user:
   `curl <APP_URL>/user/<user_id>`
4. Delete a user by user_id: 
   `curl -H "Content-Type: application/json" <APP_URL>/delete/<user_id>`
5. Update a user's information: 
   `curl -H "Content-Type: application/json" -d {"name": "<user_name>", "email": "<user_email>", "pwd": "<user_password>", "user_id": <user_id>} <APP_URL>/update`

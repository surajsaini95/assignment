# Deploying a User CRUD App with MySQL on Kubernetes

## Prerequisites or tools req.
1. `docker` 
2. `minikube`
2. `helm`
2. `jq`


## Getting started
1. Clone the repository
2. Execute `bash run_assignment.sh` script.
3. Master branch makes a plain deployment with any deployment strategy.
4. Everything will be deployed in default namespace.

## About run_assignment.sh
This script can be used to run and test the assignment.
It will do the following this for you:
1. Check the minikube status and start it if req.
2. Check whether `helm` is available or not.
3. Pull and build the required docker images.
4. Create hostpath dir to be used by PV for persistence.
5. Deploy `helm` chart.
6. Populate `mysql` with from initial dump.
7. Run an interactive loop to test the application by performing user CRUD operations.



## Creating database and schema
In case the script fails to create db and tables then execute the following steps:
1. Connect with `MySQL database` :
   1. `MYSQL_HOST=$(kubectl get svc -o custom-columns=":metadata.name" | grep db)`
   2. `kubectl run -it --rm --image=mysql --restart=Never mysql-client -- mysql --host $MYSQL_HOST --password=<your-secret-password>`
   
2. Create the database and table:
   1. `CREATE DATABASE userapp;`
   2. `USE userapp;`
   3. `CREATE TABLE users(user_id INT PRIMARY KEY AUTO_INCREMENT, user_name VARCHAR(255), user_email VARCHAR(255), user_password VARCHAR(255));`
    
## Expose the API
The API can be accessed by exposing it using minikube: 
   `minikube service $(kubectl get svc -o custom-columns=":metadata.name" | grep userapp) --url`. 
Hit this via `curl` or via `browser` you will see the `I am healthy and functioning` message.

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

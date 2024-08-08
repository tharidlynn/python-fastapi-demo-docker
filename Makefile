# Kubernetes Makefile for FastAPI Microservice

# Variables
NAMESPACE := diraht
DEPLOYMENT := fastapi-deployment
SERVICE := fastapi-service
STATEFULSET := fastapi-postgres
DB_SERVICE := db
KUBECTL := kubectl -n $(NAMESPACE)

# Colors for output
CYAN := \033[0;36m
NC := \033[0m # No Color

# Main tasks
.PHONY: all deploy undeploy restart logs scale status clean

all: deploy

# Deployment tasks
deploy: create-namespace deploy-secrets deploy-configmaps deploy-app deploy-db

create-namespace:
	@echo "$(CYAN)Creating namespace $(NAMESPACE)...$(NC)"
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -

deploy-secrets:
	@echo "$(CYAN)Deploying secrets...$(NC)"
	@kubectl create secret generic fastapi-secret \
		--from-literal=POSTGRES_USER=bookdbadmin \
		--from-literal=POSTGRES_PASSWORD=dbpassword \
		--from-literal=POSTGRES_DB=bookstore \
		--dry-run=client -o yaml | $(KUBECTL) apply -f -

deploy-configmaps:
	@echo "$(CYAN)Deploying ConfigMaps...$(NC)"
	@if [ -f server/db/init.sh ]; then \
		$(KUBECTL) create configmap db-init-script --from-file=server/db/init.sh --dry-run=client -o yaml | $(KUBECTL) apply -f -; \
	else \
		echo "$(CYAN)Warning: init.sh not found. Skipping ConfigMap creation.$(NC)"; \
	fi

deploy-app:
	@echo "$(CYAN)Deploying FastAPI application...$(NC)"
	@$(KUBECTL) apply -f kubernetes/fastapi-app.yaml

deploy-db:
	@echo "$(CYAN)Deploying PostgreSQL database...$(NC)"
	@$(KUBECTL) apply -f kubernetes/postgres-db.yaml

# Undeployment tasks
undeploy:
	@echo "$(CYAN)Undeploying all resources...$(NC)"
	@$(KUBECTL) delete -f kubernetes/fastapi-app.yaml
	@$(KUBECTL) delete -f kubernetes/postgres-db.yaml
	@$(KUBECTL) delete configmap db-init-script
	@$(KUBECTL) delete secret fastapi-secret

# Operational tasks
restart:
	@echo "$(CYAN)Restarting deployment...$(NC)"
	@$(KUBECTL) rollout restart deployment $(DEPLOYMENT)

logs:
	@echo "$(CYAN)Fetching logs...$(NC)"
	@$(KUBECTL) logs -l app=fastapi-app --tail=100

scale:
	@echo "$(CYAN)Scaling deployment...$(NC)"
	@$(KUBECTL) scale deployment $(DEPLOYMENT) --replicas=$(replicas)

status:
	@echo "$(CYAN)Checking deployment status...$(NC)"
	@$(KUBECTL) get all
	@$(KUBECTL) get pvc

clean:
	@echo "$(CYAN)Cleaning up resources...$(NC)"
	@$(KUBECTL) delete namespace $(NAMESPACE)

# Incident response tasks
.PHONY: incident-response db-backup increase-resources

incident-response:
	@echo "$(CYAN)Running incident response...$(NC)"
	@make logs
	@make status
	@make restart

db-backup:
	@echo "$(CYAN)Creating database backup...$(NC)"
	@$(KUBECTL) exec $(STATEFULSET)-0 -- pg_dump -U bookdbadmin bookstore > backup_$(shell date +%Y%m%d_%H%M%S).sql

increase-resources:
	@echo "$(CYAN)Increasing resources for deployment...$(NC)"
	@$(KUBECTL) patch deployment $(DEPLOYMENT) -p '{"spec":{"template":{"spec":{"containers":[{"name":"web","resources":{"requests":{"cpu":"200m","memory":"200Mi"},"limits":{"cpu":"1000m","memory":"1000Mi"}}}]}}}}'

# Help
.PHONY: help

help:
	@echo "$(CYAN)Available commands:$(NC)"
	@echo "  make deploy              - Deploy all resources"
	@echo "  make undeploy            - Remove all resources"
	@echo "  make restart             - Restart the deployment"
	@echo "  make logs                - Fetch recent logs"
	@echo "  make scale replicas=3    - Scale the deployment to specified replicas"
	@echo "  make status              - Check the status of all resources"
	@echo "  make clean               - Remove the entire namespace"
	@echo "  make incident-response   - Run incident response tasks"
	@echo "  make db-backup           - Create a database backup"
	@echo "  make increase-resources  - Increase resources for the deployment"
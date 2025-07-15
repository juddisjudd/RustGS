# RustGS Docker Makefile
# Provides convenient commands for building, testing, and deploying

# Configuration
DOCKER_USERNAME ?= ipajudd
IMAGE_NAME = rustgs
IMAGE_TAG ?= latest
FULL_IMAGE_NAME = $(DOCKER_USERNAME)/$(IMAGE_NAME):$(IMAGE_TAG)

# Colors for output
GREEN = \033[0;32m
RED = \033[0;31m
YELLOW = \033[1;33m
NC = \033[0m

.PHONY: help build test run stop clean push setup dev-build dev-run logs shell

# Default target
help: ## Show this help message
	@echo "RustGS Docker - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $1, $2}'
	@echo ""
	@echo "Environment Variables:"
	@echo "  DOCKER_USERNAME - Your Docker Hub username (default: juddisjudd)"
	@echo "  IMAGE_TAG       - Docker image tag (default: latest)"

setup: ## Create necessary directory structure and scripts
	@echo "$(GREEN)Setting up project structure...$(NC)"
	@mkdir -p scripts
	@chmod +x build.sh scripts/*.sh 2>/dev/null || true
	@echo "$(GREEN)Setup complete!$(NC)"

build: setup ## Build the Docker image
	@echo "$(GREEN)Building Docker image: $(FULL_IMAGE_NAME)$(NC)"
	@docker build -t $(FULL_IMAGE_NAME) .
	@echo "$(GREEN)Build complete!$(NC)"

dev-build: setup ## Build image for development (no cache)
	@echo "$(GREEN)Building Docker image for development (no cache)...$(NC)"
	@docker build --no-cache -t $(FULL_IMAGE_NAME) .
	@echo "$(GREEN)Development build complete!$(NC)"

test: build ## Build and test the image
	@echo "$(GREEN)Testing Docker image...$(NC)"
	@docker run --rm -d --name rust-server-test $(FULL_IMAGE_NAME)
	@sleep 30
	@if docker ps | grep -q rust-server-test; then \
		echo "$(GREEN)Container test passed!$(NC)"; \
		docker stop rust-server-test; \
	else \
		echo "$(RED)Container test failed!$(NC)"; \
		docker logs rust-server-test; \
		exit 1; \
	fi

run: build ## Run the server using docker-compose
	@echo "$(GREEN)Starting RustGS server with docker-compose...$(NC)"
	@docker-compose up -d
	@echo "$(GREEN)Server started! Use 'make logs' to view output$(NC)"

dev-run: build ## Run the server in development mode (foreground)
	@echo "$(GREEN)Starting RustGS server in development mode...$(NC)"
	@docker-compose up

stop: ## Stop the running server
	@echo "$(YELLOW)Stopping RustGS server...$(NC)"
	@docker-compose down
	@echo "$(GREEN)Server stopped!$(NC)"

restart: stop run ## Restart the server

logs: ## Show server logs
	@docker-compose logs -f rust-server

logs-tail: ## Show last 100 lines of server logs
	@docker-compose logs --tail=100 rust-server

shell: ## Get a shell inside the running container
	@docker-compose exec rust-server /bin/bash

push: test ## Build, test, and push to Docker Hub
	@echo "$(GREEN)Pushing image to Docker Hub...$(NC)"
	@docker push $(FULL_IMAGE_NAME)
	@echo "$(GREEN)Image pushed successfully!$(NC)"
	@echo "$(GREEN)Available at: https://hub.docker.com/r/$(DOCKER_USERNAME)/$(IMAGE_NAME)$(NC)"

clean: ## Clean up Docker images and containers
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	@docker-compose down -v 2>/dev/null || true
	@docker rmi $(FULL_IMAGE_NAME) 2>/dev/null || true
	@docker image prune -f
	@docker volume prune -f
	@echo "$(GREEN)Cleanup complete!$(NC)"

status: ## Show status of server containers
	@echo "$(GREEN)Container Status:$(NC)"
	@docker-compose ps
	@echo ""
	@echo "$(GREEN)Resource Usage:$(NC)"
	@docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

health: ## Check server health
	@echo "$(GREEN)Checking server health...$(NC)"
	@docker-compose exec rust-server /home/steam/scripts/healthcheck.sh

backup: ## Create backup of server data
	@echo "$(GREEN)Creating backup of server data...$(NC)"
	@mkdir -p backups
	@docker run --rm -v rust_server_data:/data -v $(PWD)/backups:/backup alpine tar czf /backup/rustgs-backup-$(shell date +%Y%m%d_%H%M%S).tar.gz -C /data .
	@echo "$(GREEN)Backup created in ./backups/$(NC)"

restore: ## Restore server data from backup (requires BACKUP_FILE variable)
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "$(RED)Error: Please specify BACKUP_FILE variable$(NC)"; \
		echo "Example: make restore BACKUP_FILE=backups/rustgs-backup-20231201_120000.tar.gz"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Restoring from $(BACKUP_FILE)...$(NC)"
	@docker run --rm -v rust_server_data:/data -v $(PWD)/$(BACKUP_FILE):/backup.tar.gz alpine sh -c "cd /data && rm -rf * && tar xzf /backup.tar.gz"
	@echo "$(GREEN)Restore complete!$(NC)"

update: ## Update server (pulls latest image and restarts)
	@echo "$(GREEN)Updating RustGS server...$(NC)"
	@docker-compose pull
	@docker-compose up -d
	@echo "$(GREEN)Update complete!$(NC)"

monitor: ## Monitor server logs in real-time with filtering
	@echo "$(GREEN)Monitoring server (Ctrl+C to stop)...$(NC)"
	@docker-compose logs -f rust-server | grep -E "(Player|Admin|Error|Warning|oxide|carbon)"

# Development helpers
lint: ## Lint shell scripts
	@echo "$(GREEN)Linting shell scripts...$(NC)"
	@command -v shellcheck >/dev/null 2>&1 || { echo "$(RED)shellcheck not installed$(NC)"; exit 1; }
	@find scripts/ -name "*.sh" -exec shellcheck {} \;
	@shellcheck build.sh
	@echo "$(GREEN)Linting complete!$(NC)"

validate: ## Validate docker-compose file
	@echo "$(GREEN)Validating docker-compose.yml...$(NC)"
	@docker-compose config -q
	@echo "$(GREEN)Validation passed!$(NC)"

info: ## Show image and container information
	@echo "$(GREEN)Image Information:$(NC)"
	@docker images $(FULL_IMAGE_NAME) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
	@echo ""
	@echo "$(GREEN)Volume Information:$(NC)"
	@docker volume ls | grep rust || echo "No rust volumes found"

# Colors for output
GREEN = \033[0;32m
RED = \033[0;31m
YELLOW = \033[1;33m
NC = \033[0m

.PHONY: help build test run stop clean push setup dev-build dev-run logs shell

# Default target
help: ## Show this help message
	@echo "Rust Game Server Docker - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "Environment Variables:"
	@echo "  DOCKER_USERNAME - Your Docker Hub username (default: yourusername)"
	@echo "  IMAGE_TAG       - Docker image tag (default: latest)"

setup: ## Create necessary directory structure and scripts
	@echo "$(GREEN)Setting up project structure...$(NC)"
	@mkdir -p scripts
	@chmod +x build.sh scripts/*.sh 2>/dev/null || true
	@echo "$(GREEN)Setup complete!$(NC)"

build: setup ## Build the Docker image
	@echo "$(GREEN)Building Docker image: $(FULL_IMAGE_NAME)$(NC)"
	@docker build -t $(FULL_IMAGE_NAME) .
	@echo "$(GREEN)Build complete!$(NC)"

dev-build: setup ## Build image for development (no cache)
	@echo "$(GREEN)Building Docker image for development (no cache)...$(NC)"
	@docker build --no-cache -t $(FULL_IMAGE_NAME) .
	@echo "$(GREEN)Development build complete!$(NC)"

test: build ## Build and test the image
	@echo "$(GREEN)Testing Docker image...$(NC)"
	@docker run --rm -d --name rust-server-test $(FULL_IMAGE_NAME)
	@sleep 30
	@if docker ps | grep -q rust-server-test; then \
		echo "$(GREEN)Container test passed!$(NC)"; \
		docker stop rust-server-test; \
	else \
		echo "$(RED)Container test failed!$(NC)"; \
		docker logs rust-server-test; \
		exit 1; \
	fi

run: build ## Run the server using docker-compose
	@echo "$(GREEN)Starting Rust server with docker-compose...$(NC)"
	@docker-compose up -d
	@echo "$(GREEN)Server started! Use 'make logs' to view output$(NC)"

dev-run: build ## Run the server in development mode (foreground)
	@echo "$(GREEN)Starting Rust server in development mode...$(NC)"
	@docker-compose up

stop: ## Stop the running server
	@echo "$(YELLOW)Stopping Rust server...$(NC)"
	@docker-compose down
	@echo "$(GREEN)Server stopped!$(NC)"

restart: stop run ## Restart the server

logs: ## Show server logs
	@docker-compose logs -f rust-server

logs-tail: ## Show last 100 lines of server logs
	@docker-compose logs --tail=100 rust-server

shell: ## Get a shell inside the running container
	@docker-compose exec rust-server /bin/bash

push: test ## Build, test, and push to Docker Hub
	@echo "$(GREEN)Pushing image to Docker Hub...$(NC)"
	@docker push $(FULL_IMAGE_NAME)
	@echo "$(GREEN)Image pushed successfully!$(NC)"
	@echo "$(GREEN)Available at: https://hub.docker.com/r/$(DOCKER_USERNAME)/$(IMAGE_NAME)$(NC)"

clean: ## Clean up Docker images and containers
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	@docker-compose down -v 2>/dev/null || true
	@docker rmi $(FULL_IMAGE_NAME) 2>/dev/null || true
	@docker image prune -f
	@docker volume prune -f
	@echo "$(GREEN)Cleanup complete!$(NC)"

status: ## Show status of server containers
	@echo "$(GREEN)Container Status:$(NC)"
	@docker-compose ps
	@echo ""
	@echo "$(GREEN)Resource Usage:$(NC)"
	@docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

health: ## Check server health
	@echo "$(GREEN)Checking server health...$(NC)"
	@docker-compose exec rust-server /home/steam/scripts/healthcheck.sh

backup: ## Create backup of server data
	@echo "$(GREEN)Creating backup of server data...$(NC)"
	@mkdir -p backups
	@docker run --rm -v rust_server_data:/data -v $(PWD)/backups:/backup alpine tar czf /backup/rust-server-backup-$(shell date +%Y%m%d_%H%M%S).tar.gz -C /data .
	@echo "$(GREEN)Backup created in ./backups/$(NC)"

restore: ## Restore server data from backup (requires BACKUP_FILE variable)
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "$(RED)Error: Please specify BACKUP_FILE variable$(NC)"; \
		echo "Example: make restore BACKUP_FILE=backups/rust-server-backup-20231201_120000.tar.gz"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Restoring from $(BACKUP_FILE)...$(NC)"
	@docker run --rm -v rust_server_data:/data -v $(PWD)/$(BACKUP_FILE):/backup.tar.gz alpine sh -c "cd /data && rm -rf * && tar xzf /backup.tar.gz"
	@echo "$(GREEN)Restore complete!$(NC)"

update: ## Update server (pulls latest image and restarts)
	@echo "$(GREEN)Updating Rust server...$(NC)"
	@docker-compose pull
	@docker-compose up -d
	@echo "$(GREEN)Update complete!$(NC)"

monitor: ## Monitor server logs in real-time with filtering
	@echo "$(GREEN)Monitoring server (Ctrl+C to stop)...$(NC)"
	@docker-compose logs -f rust-server | grep -E "(Player|Admin|Error|Warning|oxide|carbon)"

# Development helpers
lint: ## Lint shell scripts
	@echo "$(GREEN)Linting shell scripts...$(NC)"
	@command -v shellcheck >/dev/null 2>&1 || { echo "$(RED)shellcheck not installed$(NC)"; exit 1; }
	@find scripts/ -name "*.sh" -exec shellcheck {} \;
	@shellcheck build.sh
	@echo "$(GREEN)Linting complete!$(NC)"

validate: ## Validate docker-compose file
	@echo "$(GREEN)Validating docker-compose.yml...$(NC)"
	@docker-compose config -q
	@echo "$(GREEN)Validation passed!$(NC)"

info: ## Show image and container information
	@echo "$(GREEN)Image Information:$(NC)"
	@docker images $(FULL_IMAGE_NAME) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
	@echo ""
	@echo "$(GREEN)Volume Information:$(NC)"
	@docker volume ls | grep rust || echo "No rust volumes found"
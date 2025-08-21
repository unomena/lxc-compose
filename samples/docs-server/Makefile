.PHONY: help up down status logs test rebuild clean

help: ## Show this help message
	@echo "Documentation Server Management"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

up: ## Start the documentation server
	@echo "Starting documentation server..."
	@lxc-compose up
	@echo "Waiting for initialization..."
	@sleep 5
	@echo "Documentation will be available at http://localhost"

down: ## Stop the documentation server
	@echo "Stopping documentation server..."
	@lxc-compose down

status: ## Show container status
	@lxc-compose list
	@echo ""
	@echo "Services status:"
	@lxc exec lxc-docs -- supervisorctl status 2>/dev/null || echo "Container not running"

logs: ## View container logs
	@echo "Showing recent logs..."
	@lxc-compose logs lxc-docs

test: ## Run all tests
	@echo "Running tests..."
	@lxc-compose test

rebuild: ## Manually rebuild documentation
	@echo "Rebuilding documentation..."
	@lxc exec lxc-docs -- /docs/scripts/manual-rebuild.sh

clean: ## Destroy the container and clean up
	@echo "Destroying container..."
	@lxc-compose destroy
	@echo "Cleanup complete"

install: ## Install from scratch
	@echo "Installing documentation server..."
	@make clean 2>/dev/null || true
	@make up
	@sleep 30
	@make test
	@echo ""
	@echo "Installation complete!"
	@echo "Documentation available at http://localhost"

dev: ## Start MkDocs development server
	@echo "Starting development server on port 8000..."
	@lxc exec lxc-docs -- /docs/scripts/start-dev.sh

shell: ## Access container shell
	@echo "Accessing container shell..."
	@lxc exec lxc-docs -- /bin/sh

update: ## Force update from repository
	@echo "Updating from repository..."
	@lxc exec lxc-docs -- sh -c "cd /opt/lxc-compose && git pull origin main"
	@make rebuild

info: ## Show container information
	@echo "Documentation Server Information"
	@echo "================================"
	@echo "Container: lxc-docs"
	@echo "Repository: https://github.com/unomena/lxc-compose"
	@echo "Web URL: http://localhost"
	@echo "Dev URL: http://localhost:8000 (if enabled)"
	@echo ""
	@echo "Container IP:"
	@lxc list lxc-docs -c 4 --format csv 2>/dev/null || echo "Not running"
	@echo ""
	@echo "Exposed Ports:"
	@grep exposed_ports lxc-compose.yml | sed 's/.*://'
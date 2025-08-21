.PHONY: help install dev build serve clean test deploy check-links

# Variables
VENV = .venv
PYTHON = $(VENV)/bin/python
PIP = $(VENV)/bin/pip
MKDOCS = $(VENV)/bin/mkdocs
PORT = 8000

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Install MkDocs and dependencies
	@echo "Creating virtual environment..."
	@python3 -m venv $(VENV)
	@echo "Upgrading pip..."
	@$(PIP) install --upgrade pip setuptools wheel
	@echo "Installing MkDocs and themes..."
	@$(PIP) install mkdocs mkdocs-material mkdocs-mermaid2-plugin pygments pymdown-extensions
	@echo "Installation complete!"

dev: install ## Start development server with live reload
	@echo "Starting MkDocs development server on http://localhost:$(PORT)"
	@$(MKDOCS) serve --dev-addr localhost:$(PORT) --livereload

build: install ## Build static documentation site
	@echo "Building documentation site..."
	@$(MKDOCS) build --clean --strict
	@echo "Documentation built in site/ directory"

serve: build ## Serve the built documentation (production mode)
	@echo "Serving built documentation on http://localhost:$(PORT)"
	@cd site && python3 -m http.server $(PORT)

clean: ## Clean build artifacts and cache
	@echo "Cleaning build artifacts..."
	@rm -rf site/
	@rm -rf .cache/
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@echo "Clean complete!"

test: install ## Test documentation build with strict mode
	@echo "Testing documentation build..."
	@$(MKDOCS) build --strict --quiet
	@echo "Documentation build test passed!"

deploy: build ## Deploy to GitHub Pages
	@echo "Deploying to GitHub Pages..."
	@$(MKDOCS) gh-deploy --force --clean
	@echo "Deployment complete!"

check-links: install ## Check for broken links in documentation
	@echo "Installing linkchecker..."
	@$(PIP) install linkchecker
	@echo "Checking links..."
	@$(MKDOCS) build --quiet
	@$(VENV)/bin/linkchecker site/

# Alternative simple Python HTTP server without MkDocs
simple-serve: ## Serve raw markdown files with simple HTTP server
	@echo "Serving documentation on http://localhost:$(PORT)"
	@echo "Note: This serves raw markdown files without processing"
	@python3 -m http.server $(PORT)

# Watch for changes and rebuild
watch: install ## Watch for changes and rebuild automatically
	@echo "Watching for changes..."
	@$(MKDOCS) build --clean
	@while true; do \
		$(MKDOCS) build --dirty; \
		sleep 2; \
	done

# Create initial MkDocs configuration if it doesn't exist
init: ## Initialize MkDocs configuration
	@if [ ! -f mkdocs.yml ]; then \
		echo "Error: mkdocs.yml not found. Please create it first."; \
		exit 1; \
	else \
		echo "mkdocs.yml already exists"; \
	fi


# Quick start for new users
quickstart: init install dev ## Quick start: initialize, install, and run dev server

# Variables for customization
set-port: ## Set custom port (usage: make set-port PORT=8080)
	@echo "Server will run on port $(PORT)"

# Check if all dependencies are installed
check-deps: ## Check if all dependencies are installed
	@echo "Checking dependencies..."
	@command -v python3 >/dev/null 2>&1 || { echo "Python 3 is required but not installed."; exit 1; }
	@if [ -d $(VENV) ]; then \
		echo "✓ Virtual environment exists"; \
		$(PIP) list | grep -q mkdocs && echo "✓ MkDocs installed" || echo "✗ MkDocs not installed"; \
		$(PIP) list | grep -q mkdocs-material && echo "✓ Material theme installed" || echo "✗ Material theme not installed"; \
	else \
		echo "✗ Virtual environment not found. Run 'make install' first."; \
	fi

# Print current configuration
info: ## Show current configuration
	@echo "Documentation Configuration:"
	@echo "  Virtual Environment: $(VENV)"
	@echo "  Python: $(PYTHON)"
	@echo "  MkDocs: $(MKDOCS)"
	@echo "  Default Port: $(PORT)"
	@echo ""
	@if [ -f mkdocs.yml ]; then \
		echo "MkDocs configuration found:"; \
		grep -E "^site_name:|^theme:" mkdocs.yml | sed 's/^/  /'; \
	else \
		echo "No mkdocs.yml found. Run 'make init' to create one."; \
	fi
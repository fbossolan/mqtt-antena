IMAGE_NAME=mqtt-antena
DOCKER_USER=fbossolan
VENV=.venv
PYTHON?=$(VENV)/bin/python
PIP?=$(VENV)/bin/pip
PYTHON_VERSION_ARG=$(shell cat .python-version)
VERSION_TAG=$(shell cat VERSION)

.PHONY: build lint format clean publish run venv destroy help release test

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

venv: $(VENV)/bin/activate ## Create and sync the virtual environment

$(VENV)/bin/activate: requirements.txt requirements-dev.txt
	test -d $(VENV) || python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt
	$(PIP) install -r requirements-dev.txt
	touch $(VENV)/bin/activate

build: ## Build the Docker image (local architecture)
	docker build --build-arg PYTHON_VERSION=$(PYTHON_VERSION_ARG) -t $(IMAGE_NAME) .

run: build ## Start the application via Docker Compose
	docker-compose up -d

run-flask: venv ## Start the application via Flask
	$(VENV)/bin/python src/app.py

lint: venv ## Run code linting with Ruff
	$(VENV)/bin/ruff check src --fix

format: venv ## Format code with Ruff
	$(VENV)/bin/ruff format src

clean: ## Clean up caches
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	rm -rf .ruff_cache

publish: ## Build and push multi-arch image to Docker Hub
	@TAG_TO_USE=$(TAG); \
	if [ -z "$$TAG_TO_USE" ]; then \
		TAG_TO_USE=$(VERSION_TAG); \
		echo "TAG not provided, using VERSION: $$TAG_TO_USE"; \
	fi; \
	docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v6 --push \
		--build-arg PYTHON_VERSION=$(PYTHON_VERSION_ARG) \
		-t $(DOCKER_USER)/$(IMAGE_NAME):$$TAG_TO_USE \
		-t $(DOCKER_USER)/$(IMAGE_NAME):latest .

destroy: ## Remove local containers and images
	docker-compose down --rmi local --volumes --remove-orphans
	docker rmi $(IMAGE_NAME) || true

test: venv ## Run unit tests
	$(PYTHON) -m pytest tests/

reset-password: venv ## Reset a user's password (usage: make reset-password user=USERNAME pass=NEWPASS)
	@if [ -z "$(user)" ] || [ -z "$(pass)" ]; then \
		echo "Error: user and pass are required. Usage: make reset-password user=USERNAME pass=NEWPASS"; \
		exit 1; \
	fi
	NO_MONKEY_PATCH=1 FLASK_APP=src/app.py $(VENV)/bin/flask reset-password $(user) $(pass)

release: ## Update the VERSION file (usage: make release v=1.2.3)
	@if [ -z "$(v)" ]; then echo "Error: v is not set. Use 'make release v=1.2.3'"; exit 1; fi
	@./create_release.sh $(v)

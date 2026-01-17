IMAGE_NAME=mqtt-antena
DOCKER_USER=flvbssln

.PHONY: build container lint format clean publish run stop

build:
	docker build -t $(IMAGE_NAME) .

run: build
	docker-compose up -d

stop:
	docker-compose down

container: build
	docker run -it --rm -v $(PWD)/data:/app/data --entrypoint /bin/bash $(IMAGE_NAME)

lint:
	ruff check src

format:
	ruff format src

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	rm -rf .ruff_cache

publish: build
	@if [ -z "$(TAG)" ]; then echo "Error: TAG is not set. Use 'make publish TAG=v1.0.0'"; exit 1; fi
	docker tag $(IMAGE_NAME) $(DOCKER_USER)/$(IMAGE_NAME):$(TAG)
	docker tag $(IMAGE_NAME) $(DOCKER_USER)/$(IMAGE_NAME):latest
	docker push $(DOCKER_USER)/$(IMAGE_NAME):$(TAG)
	docker push $(DOCKER_USER)/$(IMAGE_NAME):latest

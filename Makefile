.PHONY: init down ps

init:
	docker network create docker-infra-network 2>/dev/null || echo "Network already exists"
	@if [ ! -f .env ]; then cp .env.example .env && echo "Created .env from .env.example"; fi

down:
	docker compose -f services/databases/postgres.yml down
	docker compose -f services/databases/pgvector.yml down
	docker compose -f services/databases/mongodb.yml down
	docker compose -f services/databases/redis.yml down
	docker compose -f services/databases/oracle.yml down
	docker compose -f services/storage/minio.yml down
	docker compose -f services/storage/qdrant.yml down
	docker compose -f services/queue/rabbitmq.yml down

ps:
	docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

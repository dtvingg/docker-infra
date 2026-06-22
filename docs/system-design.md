# System Design — docker-infra

## 1. Mục tiêu

Bộ infrastructure Docker Compose tối giản, tập trung vào **databases**, **storage**, **queue**. Mỗi service chạy độc lập bằng lệnh `docker compose` trực tiếp, không phụ thuộc vào Makefile để start service.

---

## 2. Cấu trúc thư mục

```
docker-infra/
│
├── .env                          # Biến môi trường chung cho toàn bộ project
├── .env.example                  # Template, commit vào git, không chứa giá trị thật
├── Makefile                      # Chỉ dùng cho: init network, down all, ps
├── README.md                     # Hướng dẫn sử dụng
│
└── services/
    ├── databases/
    │   ├── postgres.yml
    │   ├── pgvector.yml
    │   ├── mongodb.yml
    │   ├── redis.yml
    │   └── oracle.yml
    │
    ├── storage/
    │   ├── minio.yml
    │   └── qdrant.yml
    │
    └── queue/
        └── rabbitmq.yml
```

---

## 3. Network

### Chiến lược

Tất cả services dùng chung **1 external network** duy nhất. Network phải được tạo **1 lần** trước khi chạy bất kỳ service nào, thông qua `make init`.

### Tên network

```
docker-infra-network
```

### Khai báo trong mỗi compose file

```yaml
networks:
  default:
    name: docker-infra-network
    external: true
```

---

## 4. Biến môi trường

### Thứ tự ưu tiên (cao → thấp)

```
1. Shell environment  (export VAR=value)
2. .env file ở root
3. Default value trong compose.yml  (${VAR:-default})
4. Default value trong Docker image
```

### Quy tắc

- File `.env` là nguồn config chính, tất cả services đọc từ đây
- Mỗi lệnh `docker compose` truyền `--env-file .env` (đường dẫn từ root)
- File `.env` **không commit** vào git, chỉ commit `.env.example`
- Biến trong compose.yml dùng cú pháp `${VAR_NAME:-default_value}`

### `.env.example`

```dotenv
# ================================
# PostgreSQL
# ================================
POSTGRES_PORT=5432
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres

# ================================
# pgvector
# ================================
PGVECTOR_PORT=5433
PGVECTOR_DB=vectordb
PGVECTOR_USER=postgres
PGVECTOR_PASSWORD=postgres

# ================================
# MongoDB
# ================================
MONGO_PORT=27017
MONGO_INITDB_DATABASE=admin
MONGO_INITDB_ROOT_USERNAME=admin
MONGO_INITDB_ROOT_PASSWORD=admin

# ================================
# Redis
# ================================
REDIS_PORT=6379
REDIS_PASSWORD=redis

# ================================
# Oracle
# ================================
ORACLE_PORT=1521
ORACLE_DATABASE=freepdb1
ORACLE_PASSWORD=oracle

# ================================
# MinIO
# ================================
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin

# ================================
# Qdrant
# ================================
QDRANT_PORT=6333
QDRANT_GRPC_PORT=6334

# ================================
# RabbitMQ
# ================================
RABBITMQ_PORT=5672
RABBITMQ_MANAGEMENT_PORT=15672
RABBITMQ_DEFAULT_USER=guest
RABBITMQ_DEFAULT_PASS=guest
RABBITMQ_DEFAULT_VHOST=/
```

---

## 5. Quy ước đặt tên

### Container name

Pattern: `<service>` (không prefix, tên ngắn gọn)

| Service    | Container name |
|------------|----------------|
| PostgreSQL | `postgres`     |
| pgvector   | `pgvector`     |
| MongoDB    | `mongodb`      |
| Redis      | `redis`        |
| Oracle     | `oracle`       |
| MinIO      | `minio`        |
| Qdrant     | `qdrant`       |
| RabbitMQ   | `rabbitmq`     |

### Volume name

Pattern: `<service>_data`

| Service    | Volume name      |
|------------|------------------|
| PostgreSQL | `postgres_data`  |
| pgvector   | `pgvector_data`  |
| MongoDB    | `mongodb_data`   |
| Redis      | `redis_data`     |
| Oracle     | `oracle_data`    |
| MinIO      | `minio_data`     |
| Qdrant     | `qdrant_data`    |
| RabbitMQ   | `rabbitmq_data`  |

---

## 6. Chi tiết từng service

### 6.1 PostgreSQL (`services/databases/postgres.yml`)

- **Image**: `postgres:16-alpine`
- **Container**: `postgres`
- **Port**: `${POSTGRES_PORT:-5432}:5432`
- **Volume**: `postgres_data:/var/lib/postgresql/data`
- **Restart**: `unless-stopped`
- **Env**:
  - `POSTGRES_DB=${POSTGRES_DB:-postgres}`
  - `POSTGRES_USER=${POSTGRES_USER:-postgres}`
  - `POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}`
- **Health check**: `pg_isready -U postgres`

---

### 6.2 pgvector (`services/databases/pgvector.yml`)

- **Image**: `pgvector/pgvector:pg16`
- **Container**: `pgvector`
- **Port**: `${PGVECTOR_PORT:-5433}:5432` ← port 5433 để tránh conflict với postgres
- **Volume**: `pgvector_data:/var/lib/postgresql/data`
- **Restart**: `unless-stopped`
- **Env**:
  - `POSTGRES_DB=${PGVECTOR_DB:-vectordb}`
  - `POSTGRES_USER=${PGVECTOR_USER:-postgres}`
  - `POSTGRES_PASSWORD=${PGVECTOR_PASSWORD:-postgres}`
- **Health check**: `pg_isready -U postgres`

---

### 6.3 MongoDB (`services/databases/mongodb.yml`)

- **Image**: `mongo:7`
- **Container**: `mongodb`
- **Port**: `${MONGO_PORT:-27017}:27017`
- **Volume**: `mongodb_data:/data/db`
- **Restart**: `unless-stopped`
- **Env**:
  - `MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME:-admin}`
  - `MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD:-admin}`
  - `MONGO_INITDB_DATABASE=${MONGO_INITDB_DATABASE:-admin}`
- **Health check**: `mongosh --eval "db.adminCommand('ping')" --quiet`

---

### 6.4 Redis (`services/databases/redis.yml`)

- **Image**: `redis:7-alpine`
- **Container**: `redis`
- **Port**: `${REDIS_PORT:-6379}:6379`
- **Volume**: `redis_data:/data`
- **Restart**: `unless-stopped`
- **Command**: `redis-server --requirepass ${REDIS_PASSWORD:-redis}`
- **Health check**: `redis-cli -a ${REDIS_PASSWORD:-redis} ping`

---

### 6.5 Oracle (`services/databases/oracle.yml`)

- **Image**: `gvenzl/oracle-free:23-slim`
- **Container**: `oracle`
- **Port**: `${ORACLE_PORT:-1521}:1521`
- **Volume**: `oracle_data:/opt/oracle/oradata`
- **Restart**: `unless-stopped`
- **Env**:
  - `ORACLE_PASSWORD=${ORACLE_PASSWORD:-oracle}`
  - `ORACLE_DATABASE=${ORACLE_DATABASE:-freepdb1}`
- **Health check**: `healthcheck.sh` (script có sẵn trong image)
- **Lưu ý**: Khởi động lâu 2-5 phút, health check cần `start_period: 120s`

---

### 6.6 MinIO (`services/storage/minio.yml`)

- **Image**: `minio/minio:latest`
- **Container**: `minio`
- **Port**:
  - `${MINIO_PORT:-9000}:9000` (S3 API)
  - `${MINIO_CONSOLE_PORT:-9001}:9001` (Web Console)
- **Volume**: `minio_data:/data`
- **Restart**: `unless-stopped`
- **Command**: `server /data --console-address ":9001"`
- **Env**:
  - `MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}`
  - `MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-minioadmin}`
- **Health check**: `curl -f http://localhost:9000/minio/health/live`

---

### 6.7 Qdrant (`services/storage/qdrant.yml`)

- **Image**: `qdrant/qdrant:latest`
- **Container**: `qdrant`
- **Port**:
  - `${QDRANT_PORT:-6333}:6333` (HTTP REST API)
  - `${QDRANT_GRPC_PORT:-6334}:6334` (gRPC)
- **Volume**: `qdrant_data:/qdrant/storage`
- **Restart**: `unless-stopped`
- **Health check**: `curl -f http://localhost:6333/healthz`

---

### 6.8 RabbitMQ (`services/queue/rabbitmq.yml`)

- **Image**: `rabbitmq:3-management-alpine`
- **Container**: `rabbitmq`
- **Port**:
  - `${RABBITMQ_PORT:-5672}:5672` (AMQP)
  - `${RABBITMQ_MANAGEMENT_PORT:-15672}:15672` (Management UI)
- **Volume**: `rabbitmq_data:/var/lib/rabbitmq`
- **Restart**: `unless-stopped`
- **Env**:
  - `RABBITMQ_DEFAULT_USER=${RABBITMQ_DEFAULT_USER:-guest}`
  - `RABBITMQ_DEFAULT_PASS=${RABBITMQ_DEFAULT_PASS:-guest}`
  - `RABBITMQ_DEFAULT_VHOST=${RABBITMQ_DEFAULT_VHOST:-/}`
- **Health check**: `rabbitmq-diagnostics ping`

---

## 7. Makefile

```makefile
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
```

---

## 8. Cách sử dụng

### Lần đầu setup

```bash
# 1. Clone project
git clone <repo-url>
cd docker-infra

# 2. Tạo network và .env
make init

# 3. Chỉnh .env nếu cần (hoặc dùng default luôn cũng được)
nano .env
```

### Chạy service

```bash
docker compose -f services/databases/postgres.yml --env-file .env up -d
docker compose -f services/databases/pgvector.yml --env-file .env up -d
docker compose -f services/databases/mongodb.yml --env-file .env up -d
docker compose -f services/databases/redis.yml --env-file .env up -d
docker compose -f services/databases/oracle.yml --env-file .env up -d
docker compose -f services/storage/minio.yml --env-file .env up -d
docker compose -f services/storage/qdrant.yml --env-file .env up -d
docker compose -f services/queue/rabbitmq.yml --env-file .env up -d
```

### Dừng service

```bash
# Dừng 1 service
docker compose -f services/databases/postgres.yml down

# Dừng tất cả
make down
```

### Xem trạng thái

```bash
make ps
```

---

## 9. Port mapping tổng hợp

| Service    | Port host | Port container | Giao thức          |
|------------|-----------|----------------|--------------------|
| PostgreSQL | 5432      | 5432           | TCP                |
| pgvector   | 5433      | 5432           | TCP                |
| MongoDB    | 27017     | 27017          | TCP                |
| Redis      | 6379      | 6379           | TCP                |
| Oracle     | 1521      | 1521           | TCP                |
| MinIO      | 9000      | 9000           | HTTP (S3 API)      |
| MinIO      | 9001      | 9001           | HTTP (Console)     |
| Qdrant     | 6333      | 6333           | HTTP (REST)        |
| Qdrant     | 6334      | 6334           | gRPC               |
| RabbitMQ   | 5672      | 5672           | AMQP               |
| RabbitMQ   | 15672     | 15672          | HTTP (Management)  |

---

## 10. Lưu ý

- **Không hardcode** password trong compose file, luôn dùng biến `${VAR:-default}`
- **pgvector dùng port 5433** ở host để tránh conflict với postgres trên 5432
- **Oracle** cần ít nhất 2GB RAM, `start_period: 120s` trong health check
- **Tất cả volumes** là named volume, không dùng bind mount
- **Restart policy** `unless-stopped` — tự restart khi Docker daemon khởi động lại, trừ khi stop thủ công
- **Default values** đủ để chạy local ngay, chỉ cần đổi khi deploy production

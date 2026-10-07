# docker-infra

Bộ Docker Compose infrastructure tối giản cho local development — databases, storage, queue, streaming. Mỗi service chạy độc lập, không phụ thuộc nhau.

## Yêu cầu

- Docker Desktop (hoặc Docker Engine + Docker Compose v2)
- GNU Make

## Setup lần đầu

```bash
# 1. Tạo network và .env
make init

# 2. Chỉnh .env nếu cần (mặc định là dùng được luôn)
```

## Chạy service

```bash
docker compose -f services/databases/postgres.yml --env-file .env up -d
docker compose -f services/databases/pgvector.yml --env-file .env up -d
docker compose -f services/databases/postgis.yml  --env-file .env up -d
docker compose -f services/databases/mongodb.yml  --env-file .env up -d
docker compose -f services/databases/redis.yml    --env-file .env up -d
docker compose -f services/databases/oracle.yml   --env-file .env up -d
docker compose -f services/storage/minio.yml      --env-file .env up -d
docker compose -f services/storage/qdrant.yml     --env-file .env up -d
docker compose -f services/queue/rabbitmq.yml     --env-file .env up -d
docker compose -f services/queue/emqx.yml         --env-file .env up -d
docker compose -f services/streaming/mosquitto.yml --env-file .env up -d
docker compose -f services/streaming/mediamtx.yml  --env-file .env up -d
```

## Dừng service

```bash
# Dừng 1 service
docker compose -f services/databases/postgres.yml down

# Dừng tất cả
make down
```

## Xem trạng thái

```bash
make ps
```

## Port mapping

| Service    | Port  | Giao thức        | UI / Tool           |
|------------|-------|------------------|---------------------|
| PostgreSQL | 5432  | TCP              |                     |
| pgvector   | 5433  | TCP              |                     |
| PostGIS    | 5434  | TCP              |                     |
| MongoDB    | 27017 | TCP              |                     |
| Redis      | 6379  | TCP              |                     |
| Oracle     | 1521  | TCP              |                     |
| MinIO      | 9000  | HTTP (S3 API)    |                     |
| MinIO      | 9001  | HTTP             | http://localhost:9001 |
| Qdrant     | 6333  | HTTP (REST)      | http://localhost:6333/dashboard |
| Qdrant     | 6334  | gRPC             |                     |
| RabbitMQ   | 5672  | AMQP             |                     |
| RabbitMQ   | 15672 | HTTP             | http://localhost:15672 |
| EMQX       | 1884  | MQTT             |                     |
| EMQX       | 8883  | MQTT over TLS    |                     |
| EMQX       | 8083  | MQTT over WS     |                     |
| EMQX       | 18083 | HTTP             | http://localhost:18083 |
| Mosquitto  | 1883  | MQTT             |                     |
| MediaMTX   | 8554  | RTSP             |                     |
| MediaMTX   | 8888  | HTTP (HLS)       | http://localhost:8888/<path> |
| MediaMTX   | 9997  | HTTP (API)       | http://localhost:9997/v3/paths/list |

## Cấu trúc thư mục

```
docker-infra/
├── .env                    # Config thực (không commit)
├── .env.example            # Template
├── Makefile
└── services/
    ├── databases/
    │   ├── postgres.yml
    │   ├── pgvector.yml
    │   ├── postgis.yml
    │   ├── mongodb.yml
    │   ├── redis.yml
    │   └── oracle.yml
    ├── storage/
    │   ├── minio.yml
    │   └── qdrant.yml
    ├── queue/
    │   ├── rabbitmq.yml
    │   └── emqx.yml
    └── streaming/
        ├── mosquitto.yml
        └── mediamtx.yml
```

## Lưu ý

- **Oracle** khởi động mất 2–5 phút, `health check` có `start_period: 120s` — bình thường.
- **pgvector** dùng port `5433` để tránh conflict với postgres trên `5432`.
- **PostGIS** dùng port `5434` để tránh conflict với postgres (`5432`) và pgvector (`5433`).
- **EMQX** dùng port MQTT `1884` ở host để tránh conflict với Mosquitto trên `1883`.
- **Mosquitto** chạy với config có sẵn trong image (`/mosquitto-no-auth.conf`): cho phép anonymous, chỉ mở MQTT `1883` — chỉ dùng cho local.
- **MediaMTX** chạy với config mặc định của image (mọi path đều publish/read được), không có health check vì image không có shell.
- Tất cả data lưu trong **named volumes** (`postgres_data`, `mongodb_data`, ...) — xóa container không mất data.
- Thêm `--volumes` khi `down` nếu muốn xóa sạch data: `docker compose -f ... down --volumes`.

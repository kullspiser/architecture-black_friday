# pymongo-api

Проект демонстрирует шардирование, репликацию и кеширование MongoDB для приложения FastAPI.

## Структура проекта

| Директория | Описание |
|------------|----------|
| `mongo-sharding/` | Шардирование MongoDB (2 шарда) |
| `mongo-sharding-repl/` | Шардирование + репликация (3 реплики на шард) |
| `sharding-repl-cache/` | Шардирование + репликация + кеширование Redis |

Для проверки используется директория **`sharding-repl-cache/`**, которая включает решения заданий 2, 3 и 4.

## Быстрый старт (sharding-repl-cache)

1. Перейдите в директорию проекта:

```bash
cd sharding-repl-cache
```

2. Запустите все сервисы:

```bash
docker compose up -d
```

3. Дождитесь запуска контейнеров (15-20 секунд) и проверьте статус:

```bash
docker compose ps
```

4. Выполните скрипт инициализации шардирования, репликации и заполнения данными:

```bash
./scripts/mongo-init.sh
```

## Проверка

### Основная информация

Откройте в браузере:

```
http://localhost:8080
```

Приложение отобразит JSON с информацией:
- `mongo_topology_type: "Sharded"` — кластер с шардированием
- `collections.helloDoc.documents_count` — общее количество документов (>= 1000)
- `shards` — список шардов с адресами всех реплик
- `cache_enabled: true` — кеширование включено

### Проверка шардирования

```bash
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

### Проверка репликации

```bash
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.status().members.forEach(function(m) { print(m.name + " — " + m.stateStr) })
EOF
```

### Проверка кеширования

```bash
# Первый запрос (~1 сек — данные из MongoDB)
time curl -s  http://localhost:8080/helloDoc/users

# Второй запрос (<100мс — данные из Redis)
time curl -s  http://localhost:8080/helloDoc/users

# Очистка кеша (на всякий случай)
docker compose exec -T redis_cache redis-cli FLUSHALL
```

## Архитектура (sharding-repl-cache)

- **pymongo_api** — приложение (FastAPI), образ `kazhem/pymongo_api:1.0.0`, порт 8080
- **mongos_router** — маршрутизатор MongoDB, порт 27020
- **redis** — кеш Redis, порт 6379
- **Config Server Replica Set** (`config_server`): configSrv1, configSrv2, configSrv3
- **Shard 1 Replica Set** (`shard1`): shard1-1, shard1-2, shard1-3
- **Shard 2 Replica Set** (`shard2`): shard2-1, shard2-2, shard2-3

## Доступные эндпоинты

Swagger: http://localhost:8080/docs

| Метод | Эндпоинт | Описание |
|-------|----------|----------|
| GET | `/` | Информация о MongoDB, шардах, репликах, кеше |
| GET | `/{collection}/count` | Количество документов в коллекции |
| GET | `/{collection}/users` | Список пользователей (кешируется на 60 сек) |
| GET | `/{collection}/users/{name}` | Получить пользователя по имени |
| POST | `/{collection}/users` | Создать пользователя |

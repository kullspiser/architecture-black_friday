# mongo-sharding-repl

MongoDB с шардированием (2 шарда) и репликацией (3 реплики на шард).

## Архитектура

- **pymongo_api** — приложение (FastAPI), порт 8080
- **mongos_router** — маршрутизатор MongoDB, порт 27020
- **Config Server Replica Set** (`config_server`):
  - configSrv1, configSrv2, configSrv3 — порт 27017
- **Shard 1 Replica Set** (`shard1`):
  - shard1-1, shard1-2, shard1-3 — порт 27018
- **Shard 2 Replica Set** (`shard2`):
  - shard2-1, shard2-2, shard2-3 — порт 27018

## Запуск

1. Запустите все сервисы:

```bash
docker compose up -d
```

2. Дождитесь запуска всех контейнеров (15-20 секунд):

```bash
docker compose ps
```

3. Выполните скрипт инициализации:

```bash
./scripts/mongo-init.sh
```

Скрипт выполняет следующие шаги:
- Инициализирует Config Server Replica Set (3 ноды)
- Инициализирует Shard 1 Replica Set (3 ноды)
- Инициализирует Shard 2 Replica Set (3 ноды)
- Добавляет оба шарда в кластер через mongos router
- Включает шардирование для БД `somedb`
- Шардирует коллекцию `helloDoc` по хешированному ключу `_id`
- Заполняет коллекцию 1000 документами
- Выводит количество документов на каждом шарде и статус реплик

## Проверка

Откройте в браузере:

```
http://localhost:8080
```

Приложение отобразит JSON с информацией о MongoDB, включая:
- `mongo_topology_type: "Sharded"`
- `collections.helloDoc.documents_count` — общее количество документов (>= 1000)
- `shards` — список шардов с адресами всех реплик

Проверка статуса реплик шарда:

```bash
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.status().members.forEach(function(m) { print(m.name + " — " + m.stateStr) })
EOF
```

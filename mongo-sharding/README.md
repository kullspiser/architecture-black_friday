# mongo-sharding

MongoDB с шардированием на 2 шарда.

## Архитектура

- **pymongo_api** — приложение (FastAPI), порт 8080
- **mongos_router** — маршрутизатор MongoDB, порт 27020
- **configSrv** — конфиг-сервер (replica set `config_server`), порт 27017
- **shard1** — первый шард, порт 27018
- **shard2** — второй шард, порт 27018

## Запуск

1. Запустите все сервисы:

```bash
docker compose up -d
```

2. Дождитесь запуска всех контейнеров (10-15 секунд):

```bash
docker compose ps
```

3. Выполните скрипт инициализации шардирования и заполнения БД:

```bash
./scripts/mongo-init.sh
```

Скрипт выполняет следующие шаги:
- Инициализирует config server как replica set
- Добавляет shard1 и shard2 в кластер через mongos router
- Включает шардирование для БД `somedb`
- Шардирует коллекцию `helloDoc` по хешированному ключу `_id`
- Заполняет коллекцию 1000 документами
- Выводит количество документов на каждом шарде

## Проверка

Откройте в браузере:

```
http://localhost:8080
```

Приложение отобразит JSON с информацией о MongoDB, включая:
- `mongo_topology_type: "Sharded"`
- `collections.helloDoc.documents_count` — общее количество документов (>= 1000)
- `shards` — список шардов с адресами

Для проверки количества документов на каждом шарде:

```bash
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF

docker compose exec -T shard2 mongosh --port 27018 --quiet <<EOF
use somedb
db.helloDoc.countDocuments()
EOF
```

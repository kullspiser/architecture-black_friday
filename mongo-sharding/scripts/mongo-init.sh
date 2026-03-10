#!/bin/bash

set -e

echo ">>> 1. Инициализация config server replica set..."
docker compose exec -T configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv:27017" }
  ]
})
EOF

sleep 3

echo ">>> 2. Добавление шардов в mongos router..."
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1:27018")
sh.addShard("shard2:27018")
EOF

sleep 2

echo ">>> 3. Включение шардирования для БД и коллекции..."
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "_id": "hashed" })
EOF

sleep 2

echo ">>> 4. Заполнение данными (1000 документов)..."
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF

echo ">>> 5. Проверка количества документов на шардах..."
docker compose exec -T shard1 mongosh --port 27018 --quiet <<EOF
use somedb
print("shard1: " + db.helloDoc.countDocuments())
EOF

docker compose exec -T shard2 mongosh --port 27018 --quiet <<EOF
use somedb
print("shard2: " + db.helloDoc.countDocuments())
EOF

echo ">>> Готово! Откройте http://localhost:8080 для проверки."

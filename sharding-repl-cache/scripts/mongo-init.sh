#!/bin/bash

# Функция ожидания готовности mongod
wait_for_mongo() {
  local service=$1
  local port=$2
  echo "    Ожидание готовности $service:$port..."
  until docker compose exec -T "$service" mongosh --port "$port" --quiet --eval "db.runCommand({ping:1})" > /dev/null 2>&1; do
    sleep 2
  done
  echo "    $service:$port готов."
}

echo ">>> 1. Ожидание готовности всех сервисов..."
wait_for_mongo configSrv1 27017
wait_for_mongo shard1-1 27018
wait_for_mongo shard2-1 27018

echo ">>> 2. Инициализация Config Server Replica Set..."
docker compose exec -T configSrv1 mongosh --port 27017 --quiet <<EOF
rs.initiate({
  _id: "config_server",
  configsvr: true,
  members: [
    { _id: 0, host: "configSrv1:27017" },
    { _id: 1, host: "configSrv2:27017" },
    { _id: 2, host: "configSrv3:27017" }
  ]
})
EOF

echo ">>> 3. Инициализация Shard 1 Replica Set..."
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard1",
  members: [
    { _id: 0, host: "shard1-1:27018" },
    { _id: 1, host: "shard1-2:27018" },
    { _id: 2, host: "shard1-3:27018" }
  ]
})
EOF

echo ">>> 4. Инициализация Shard 2 Replica Set..."
docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<EOF
rs.initiate({
  _id: "shard2",
  members: [
    { _id: 0, host: "shard2-1:27018" },
    { _id: 1, host: "shard2-2:27018" },
    { _id: 2, host: "shard2-3:27018" }
  ]
})
EOF

echo ">>> Ожидание выборов PRIMARY (15 сек)..."
sleep 15

echo ">>> 5. Добавление шардов в mongos router..."
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard("shard1/shard1-1:27018,shard1-2:27018,shard1-3:27018")
sh.addShard("shard2/shard2-1:27018,shard2-2:27018,shard2-3:27018")
EOF

sleep 3

echo ">>> 6. Включение шардирования для БД и коллекции..."
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
sh.enableSharding("somedb")
sh.shardCollection("somedb.helloDoc", { "_id": "hashed" })
EOF

sleep 2

echo ">>> 7. Заполнение данными (1000 документов)..."
docker compose exec -T mongos_router mongosh --port 27020 --quiet <<EOF
use somedb
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
EOF

echo ">>> 8. Проверка количества документов на шардах..."
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
use somedb
print("shard1: " + db.helloDoc.countDocuments())
EOF

docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<EOF
use somedb
print("shard2: " + db.helloDoc.countDocuments())
EOF

echo ">>> 9. Проверка статуса реплик..."
docker compose exec -T shard1-1 mongosh --port 27018 --quiet <<EOF
rs.status().members.forEach(function(m) { print(m.name + " — " + m.stateStr) })
EOF

docker compose exec -T shard2-1 mongosh --port 27018 --quiet <<EOF
rs.status().members.forEach(function(m) { print(m.name + " — " + m.stateStr) })
EOF

echo ">>> Готово! Откройте http://localhost:8080 для проверки."
echo ">>> Для проверки кеша: curl http://localhost:8080/helloDoc/users (второй запрос должен быть <100мс)"

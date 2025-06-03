## ------------------------ Обнова на версию 0.3.1 ---------------------------
```bash
wget https://raw.githubusercontent.com/noderguru/pipe-testnet/main/update_node-pipe_v0.3.1.sh -O /opt/popcache/update_node-pipe_v0.3.1.sh && cd /opt/popcache/ && chmod +x update_node-pipe_v0.3.1.sh && ./update_node-pipe_v0.3.1.sh
```


# 🚀 PoP Cache Node Docker Installer

bash-скрипт для установки и запуска PoP Cache Node в Docker-контейнере на базе Ubuntu 24.04.

🧰 Что делает скрипт:

✅ Проверяет и при необходимости устанавливает Docker

✅ Убивает процессы, занимающие порты 80 и 443

✅ Автоматически определяет регион и страну по IP

✅ Запрашивает параметры узла и собирает config.json

✅ Применяет системные настройки (sysctl, nofile)

✅ Скачивает PoP-бинарь, создаёт Dockerfile, билдит образ

✅ Запускает контейнер и монтирует данные в /opt/popcache


## 📦 Установка и запуск:
```bash
git clone https://github.com/noderguru/pipe-testnet.git
cd pipe-testnet
```
```bash
chmod +x install_pop_testnet-docker-full.sh && ./install_pop_testnet-docker-full.sh
```
## 🔎 Проверка работоспособности:

### 📜 Логи контейнера:
```bash
docker logs -f popnode
```
![image](https://github.com/user-attachments/assets/dff0dc87-eaed-4b83-8849-e4e822e5e59c)


### 🧪 Статус PoP-ноды:

```bash
curl -sk https://localhost/health && echo -e "\n"
```
http://your-server-ip/health   вот такой ответ должен быть ```{"status":"ok","message":"Direct HTTP server is working"}```

https://your-server-ip/state

или посмотреть метрики на сервере 
```bash
curl -sk https://localhost/state && echo -e "\n"
```
![image](https://github.com/user-attachments/assets/69d84f7c-1823-4bdf-aed2-148817773e58)

# 💾 Обязательно:

Сохраните файл .pop_state.json из директории /opt/popcache — это ваш приватный идентификатор узла. Без него восстановление невозможно!




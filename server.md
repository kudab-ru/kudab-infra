# Быстрый старт: Laravel сервер на VDS Selectel (Ubuntu, WSL)

## 1. Подключение к серверу

- Сгенерируй SSH-ключ на своей машине (WSL/Ubuntu) или используй уже существующий.
    ```sh
    ssh-keygen -t ed25519 -C "your_email@example.com"
    ```
- Скопируй публичный ключ (`cat ~/.ssh/id_ed25519.pub`) и добавь его в панель Selectel при создании сервера.

- Получи IP адрес сервера из панели управления.

- Подключись:
    ```sh
    ssh root@IP_АДРЕС_СЕРВЕРА
    ```

---

## 2. Обновление системы

```sh
apt update && apt upgrade -y
```

## 3. Установка базового софта

```sh
apt install -y git docker.io docker-compose zip unzip curl wget nano
```

## 4. Создание пользователя для работы

```sh
adduser maks
usermod -aG sudo maks
```

После установки docker:

```sh
usermod -aG docker maks
```

## 5. Проверка/создание docker group (если нужно)

```sh
groupadd docker
usermod -aG docker maks
systemctl restart docker
```

## 6. Смена пользователя
```shell
su - maks
```
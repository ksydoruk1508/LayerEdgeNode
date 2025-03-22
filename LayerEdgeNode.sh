#!/bin/bash

# Задать приватный ключ вручную (без 0x), если не хочешь интерактивный ввод
# Если оставить пустым, скрипт запросит выбор
DEFAULT_PRIVATE_KEY=""

# Цвета текста
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # Нет цвета (сброс цвета)

# Логотип
channel_logo() {
    echo -e "${GREEN}"
    cat << "EOF"
██       █████  ██    ██ ███████ ██████      ███████ ██████   ██████  ███████ 
██      ██   ██ ██    ██ ██      ██   ██     ██      ██   ██ ██    ██ ██      
██      ███████ ██    ██ █████   ██████      █████   ██   ██ ██    ██ █████   
██      ██   ██  ██  ██  ██      ██   ██     ██      ██   ██ ██    ██ ██      
███████ ██   ██   ████   ███████ ██   ██     ███████ ██████   ██████  ███████ 
                                                                              
EOF
    echo -e "${NC}"
}

generate_wallet() {
    echo -e "${BLUE}Генерируем новый кошелёк...${NC}" >&2

    # Проверяем, установлен ли Go
    if ! command -v go &> /dev/null; then
        echo -e "${RED}Go не установлен! Установите Go перед генерацией кошелька.${NC}" >&2
        return 1
    fi

    # Создаём временный Go-файл для генерации кошелька
    cat <<EOF > /tmp/generate_wallet.go
package main

import (
    "fmt"
    "github.com/ethereum/go-ethereum/crypto"
    "log"
)

func main() {
    // Генерация нового приватного ключа
    privateKey, err := crypto.GenerateKey()
    if err != nil {
        log.Fatal(err)
    }

    // Получение публичного ключа и адреса
    privateKeyBytes := crypto.FromECDSA(privateKey)
    publicKey := privateKey.PublicKey
    address := crypto.PubkeyToAddress(publicKey).Hex()

    // Вывод приватного ключа (без префикса 0x) и адреса
    fmt.Printf("%x\n", privateKeyBytes)
    fmt.Printf("%s\n", address)
}
EOF

    # Компилируем и запускаем
    go run /tmp/generate_wallet.go > /tmp/wallet.txt 2>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}Не удалось сгенерировать кошелёк. Убедитесь, что Go установлен и работает корректно.${NC}" >&2
        return 1
    fi

    # Читаем приватный ключ и адрес из файла
    private_key=$(head -n 1 /tmp/wallet.txt)
    address=$(tail -n 1 /tmp/wallet.txt)

    # Сохраняем кошелёк в файл
    echo -e "Private Key: $private_key\nAddress: $address" > $HOME/layer-edge-wallet.txt
    echo -e "${GREEN}Новый кошелёк сгенерирован и сохранён в $HOME/layer-edge-wallet.txt:${NC}" >&2
    echo -e "${CYAN}Адрес: $address${NC}" >&2
    echo -e "${CYAN}Приватный ключ: $private_key${NC}" >&2
    echo -e "${YELLOW}Сохраните эти данные в безопасном месте!${NC}" >&2

    # Удаляем временные файлы
    rm -f /tmp/generate_wallet.go /tmp/wallet.txt

    echo "$private_key"
}

get_private_key() {
    # Если задан DEFAULT_PRIVATE_KEY, используем его
    if [ -n "$DEFAULT_PRIVATE_KEY" ]; then
        echo -e "${GREEN}Используется заранее заданный приватный ключ: $DEFAULT_PRIVATE_KEY${NC}" >&2
        echo "$DEFAULT_PRIVATE_KEY"
        return 0
    fi

    # Проверяем, доступен ли интерактивный терминал
    if [ -t 0 ] && [ -t 1 ]; then
        echo -e "${BLUE}Терминал интерактивный, запрашиваем выбор...${NC}" >&2
        interactive=true
    else
        echo -e "${RED}Терминал не интерактивный! Запрос ввода невозможен.${NC}" >&2
        echo -e "${YELLOW}Пожалуйста, задайте приватный ключ вручную в переменной DEFAULT_PRIVATE_KEY в начале скрипта.${NC}" >&2
        interactive=false
    fi

    if [ "$interactive" = true ]; then
        # Выводим запрос
        echo -e "${YELLOW}Хотите использовать существующий кошелёк или сгенерировать новый?${NC}" >&2
        echo -e "${CYAN}1. Использовать существующий кошелёк${NC}" >&2
        echo -e "${CYAN}2. Сгенерировать новый кошелёк${NC}" >&2
        echo -e "${YELLOW}Введите номер:${NC} " >&2

        # Читаем выбор пользователя (без тайм-аута в интерактивной среде)
        read wallet_choice < /dev/tty
        if [ -z "$wallet_choice" ]; then
            echo -e "${YELLOW}Выбор не указан, используется значение по умолчанию (1).${NC}" >&2
            wallet_choice=1
        fi
    else
        # Если терминал не интерактивный, используем значение по умолчанию
        echo -e "${YELLOW}Используется значение по умолчанию (1) из-за неинтерактивного режима.${NC}" >&2
        wallet_choice=1
    fi

    # Отладка: выводим выбранный вариант
    echo -e "${BLUE}Выбранный вариант: $wallet_choice${NC}" >&2

    case $wallet_choice in
        1)
            if [ "$interactive" = true ]; then
                echo -e "${YELLOW}Введите приватный ключ вашего кошелька (без приставки 0x):${NC}" >&2
                read private_key < /dev/tty
                if [ -z "$private_key" ]; then
                    echo -e "${RED}Приватный ключ не может быть пустым! Выход...${NC}" >&2
                    return 1
                fi
            else
                echo -e "${RED}Неинтерактивный режим: невозможно запросить приватный ключ.${NC}" >&2
                echo -e "${YELLOW}Задайте приватный ключ в переменной DEFAULT_PRIVATE_KEY в начале скрипта.${NC}" >&2
                return 1
            fi
            echo -e "${BLUE}Введённый приватный ключ: $private_key${NC}" >&2
            echo "$private_key"
            ;;
        2)
            private_key=$(generate_wallet)
            if [ $? -ne 0 ]; then
                echo -e "${RED}Ошибка генерации кошелька. Выход...${NC}" >&2
                return 1
            fi
            echo "$private_key"
            ;;
        *)
            echo -e "${RED}Неверный выбор! Выход...${NC}" >&2
            return 1
            ;;
    esac
}

get_address_from_private_key() {
    local private_key=$1

    # Проверяем, установлен ли Go
    if ! command -v go &> /dev/null; then
        echo -e "${RED}Go не установлен! Установите Go для получения адреса из приватного ключа.${NC}" >&2
        return 1
    fi

    # Создаём временный Go-файл для получения адреса из приватного ключа
    cat <<EOF > /tmp/get_address.go
package main

import (
    "fmt"
    "github.com/ethereum/go-ethereum/crypto"
    "log"
)

func main() {
    // Приватный ключ (без 0x)
    privateKeyHex := "$private_key"
    privateKeyBytes, err := crypto.HexToECDSA(privateKeyHex)
    if err != nil {
        log.Fatal(err)
    }

    // Получение публичного ключа и адреса
    publicKey := privateKeyBytes.PublicKey
    address := crypto.PubkeyToAddress(publicKey).Hex()

    // Вывод адреса
    fmt.Println(address)
}
EOF

    # Компилируем и запускаем
    address=$(go run /tmp/get_address.go 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}Не удалось получить адрес из приватного ключа. Убедитесь, что приватный ключ корректен.${NC}" >&2
        return 1
    fi

    # Удаляем временный файл
    rm -f /tmp/get_address.go

    echo "$address"
}

view_private_key() {
    echo -e "${BLUE}Извлекаем приватный ключ...${NC}" >&2

    # Проверяем .env файл
    if [ -f $HOME/light-node/.env ]; then
        private_key=$(grep "PRIVATE_KEY" $HOME/light-node/.env | cut -d '=' -f 2)
        if [ -n "$private_key" ]; then
            echo -e "${CYAN}Приватный ключ из .env:${NC} $private_key" >&2
        else
            echo -e "${RED}Приватный ключ не найден в .env!${NC}" >&2
        fi
    else
        echo -e "${RED}Файл .env не найден!${NC}" >&2
    fi

    # Проверяем файл layer-edge-wallet.txt
    if [ -f $HOME/layer-edge-wallet.txt ]; then
        private_key=$(grep "Private Key" $HOME/layer-edge-wallet.txt | cut -d ' ' -f 3)
        if [ -n "$private_key" ]; then
            echo -e "${CYAN}Приватный ключ из layer-edge-wallet.txt:${NC} $private_key" >&2
        else
            echo -e "${RED}Приватный ключ не найден в layer-edge-wallet.txt!${NC}" >&2
        fi
    else
        echo -e "${YELLOW}Файл layer-edge-wallet.txt не найден (возможно, кошелёк не был сгенерирован скриптом).${NC}" >&2
    fi

    if [ -z "$private_key" ]; then
        echo -e "${RED}Не удалось найти приватный ключ!${NC}" >&2
    fi
}

view_public_key() {
    echo -e "${BLUE}Извлекаем публичный ключ (адрес) для дашборда...${NC}" >&2

    # Проверяем логи сервиса edged
    echo -e "${BLUE}Проверяем логи сервиса edged...${NC}" >&2
    public_key=$(journalctl -u edged -o cat | grep -i "public key" | head -n 1 | grep -oE 'cosmos1[a-z0-9]{38}' || echo "")
    if [ -n "$public_key" ]; then
        echo -e "${CYAN}Публичный ключ из логов:${NC} $public_key" >&2
        return
    else
        echo -e "${YELLOW}Публичный ключ не найден в логах. Пробуем другие способы...${NC}" >&2
    fi

    # Проверяем файл layer-edge-wallet.txt
    if [ -f $HOME/layer-edge-wallet.txt ]; then
        address=$(grep "Address" $HOME/layer-edge-wallet.txt | cut -d ' ' -f 2)
        if [ -n "$address" ]; then
            echo -e "${CYAN}Адрес из layer-edge-wallet.txt:${NC} $address" >&2
            return
        else
            echo -e "${RED}Адрес не найден в layer-edge-wallet.txt!${NC}" >&2
        fi
    else
        echo -e "${YELLOW}Файл layer-edge-wallet.txt не найден (возможно, кошелёк не был сгенерирован скриптом).${NC}" >&2
    fi

    # Пробуем получить адрес из приватного ключа
    if [ -f $HOME/light-node/.env ]; then
        private_key=$(grep "PRIVATE_KEY" $HOME/light-node/.env | cut -d '=' -f 2)
        if [ -n "$private_key" ]; then
            echo -e "${BLUE}Пробуем получить адрес из приватного ключа...${NC}" >&2
            address=$(get_address_from_private_key "$private_key")
            if [ $? -eq 0 ]; then
                echo -e "${CYAN}Адрес, полученный из приватного ключа:${NC} $address" >&2
                return
            else
                echo -e "${RED}Не удалось получить адрес из приватного ключа!${NC}" >&2
            fi
        else
            echo -e "${RED}Приватный ключ не найден в .env!${NC}" >&2
        fi
    else
        echo -e "${RED}Файл .env не найден!${NC}" >&2
    fi

    echo -e "${RED}Не удалось найти публичный ключ! Убедитесь, что нода запущена и логи содержат публичный ключ.${NC}" >&2
}

install_node() {
    echo -e "${BLUE}Начинается установка ноды Layer Edge...${NC}" >&2

    # Проверка свободного места на диске
    echo -e "${BLUE}Проверяем свободное место на диске...${NC}" >&2
    free_space=$(df -h $HOME | tail -1 | awk '{print $4}')
    if [[ $free_space == *G* ]]; then
        free_space_gb=$(echo $free_space | tr -d 'G')
        if (( $(echo "$free_space_gb < 5" | bc -l) )); then
            echo -e "${RED}Недостаточно места на диске! Требуется минимум 5 ГБ, доступно: $free_space. Выход...${NC}" >&2
            return 1
        fi
    else
        echo -e "${RED}Недостаточно места на диске! Доступно: $free_space. Выход...${NC}" >&2
        return 1
    fi
    echo -e "${GREEN}Свободное место на диске: $free_space. Продолжаем...${NC}" >&2

    # Обновление и установка зависимостей
    echo -e "${BLUE}Обновляем и устанавливаем необходимые пакеты...${NC}" >&2
    sudo apt-get update -y && sudo apt upgrade -y
    sudo apt install mc wget curl git htop netcat-openbsd net-tools unzip jq build-essential ncdu tmux make cmake clang pkg-config libssl-dev protobuf-compiler bc lz4 screen -y

    # Установка Go
    echo -e "${BLUE}Устанавливаем Go 1.22.4...${NC}" >&2
    sudo rm -rf /usr/local/go
    curl -Ls https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh
    echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile
    source /etc/profile.d/golang.sh
    source $HOME/.profile

    # Установка Rust
    echo -e "${BLUE}Устанавливаем Rust...${NC}" >&2
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"

    # Установка cargo
    echo -e "${BLUE}Устанавливаем cargo...${NC}" >&2
    sudo apt install cargo -y

    # Установка Risc0
    echo -e "${BLUE}Устанавливаем Risc0...${NC}" >&2
    curl -L https://risczero.com/install | bash
    # Добавляем путь к rzup в PATH вручную
    export PATH="$PATH:/root/.risc0/bin"
    # Обновляем окружение
    source ~/.bashrc
    # Проверяем, доступен ли rzup
    if ! command -v rzup &> /dev/null; then
        echo -e "${RED}Не удалось найти команду rzup после установки! Проверьте установку Risc0.${NC}" >&2
        return 1
    fi
    # Выполняем установку Risc0
    rzup install
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при выполнении rzup install! Проверьте подключение к интернету и повторите установку.${NC}" >&2
        return 1
    fi

    # Проверка существования директории light-node
    echo -e "${BLUE}Проверяем наличие директории light-node...${NC}" >&2
    if [ -d "$HOME/light-node" ]; then
        echo -e "${YELLOW}Директория $HOME/light-node уже существует!${NC}" >&2
        if [ -t 0 ] && [ -t 1 ]; then
            echo -e "${CYAN}1. Удалить существующую директорию и клонировать заново${NC}" >&2
            echo -e "${CYAN}2. Использовать существующую директорию (выполнить git pull)${NC}" >&2
            echo -e "${CYAN}3. Прервать установку${NC}" >&2
            echo -e "${YELLOW}Введите номер:${NC} " >&2
            read dir_choice < /dev/tty
        else
            echo -e "${YELLOW}Неинтерактивный режим: автоматически выбираем удаление директории (1).${NC}" >&2
            dir_choice=1
        fi
        case $dir_choice in
            1)
                echo -e "${BLUE}Удаляем существующую директорию...${NC}" >&2
                rm -rf $HOME/light-node
                echo -e "${GREEN}Директория удалена.${NC}" >&2
                ;;
            2)
                echo -e "${BLUE}Используем существующую директорию, выполняем git pull...${NC}" >&2
                cd $HOME/light-node
                git pull
                if [ $? -ne 0 ]; then
                    echo -e "${RED}Не удалось выполнить git pull! Проверьте состояние репозитория.${NC}" >&2
                    return 1
                fi
                echo -e "${GREEN}Репозиторий обновлён.${NC}" >&2
                ;;
            3)
                echo -e "${RED}Установка прервана пользователем.${NC}" >&2
                return 1
                ;;
            *)
                echo -e "${RED}Неверный выбор! Установка прервана.${NC}" >&2
                return 1
                ;;
        esac
    fi

    # Клонирование репозитория, если директория была удалена или не существовала
    if [ ! -d "$HOME/light-node" ]; then
        echo -e "${BLUE}Клонируем репозиторий Layer Edge...${NC}" >&2
        timeout 300 git clone https://github.com/Layer-Edge/light-node.git
        if [ $? -ne 0 ]; then
            echo -e "${RED}Не удалось клонировать репозиторий! Проверьте подключение к интернету или доступ к GitHub.${NC}" >&2
            echo -e "${YELLOW}Попробуйте выполнить команду вручную: git clone https://github.com/Layer-Edge/light-node.git${NC}" >&2
            return 1
        fi
    fi

    # Переход в директорию light-node с отладкой
    echo -e "${BLUE}Переходим в директорию $HOME/light-node...${NC}" >&2
    cd $HOME/light-node || { echo -e "${RED}Не удалось перейти в директорию $HOME/light-node. Проверьте права доступа и наличие директории.${NC}" >&2; return 1; }
    echo -e "${GREEN}Успешно перешли в директорию $HOME/light-node.${NC}" >&2

    # Получение приватного ключа
    echo -e "${BLUE}Запрашиваем приватный ключ...${NC}" >&2
    private_key=$(get_private_key)
    exit_status=$?
    if [ $exit_status -ne 0 ] || [ -z "$private_key" ]; then
        echo -e "${RED}Не удалось получить приватный ключ! Код возврата: $exit_status, значение: '$private_key'. Выход...${NC}" >&2
        return 1
    fi
    echo -e "${GREEN}Приватный ключ успешно получен: $private_key${NC}" >&2

    # Настройка .env файла
    echo -e "${BLUE}Создаём файл .env...${NC}" >&2
    cat <<EOF > .env
GRPC_URL=grpc.testnet.layeredge.io:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=https://layeredge.mintair.xyz
API_REQUEST_TIMEOUT=100
POINTS_API=https://light-node.layeredge.io
PRIVATE_KEY=$private_key
EOF
    echo -e "${GREEN}Файл .env успешно создан!${NC}" >&2

    # Сборка risc0-merkle-service
    echo -e "${BLUE}Собираем и запускаем risc0-merkle-service...${NC}" >&2
    cd risc0-merkle-service
    screen -dmS risc
    screen -S risc -X stuff "cargo build && cargo run\n"
    echo -e "${YELLOW}risc0-merkle-service запущен в screen-сессии 'risc'. Дождитесь завершения сборки...${NC}" >&2
    sleep 10  # Даём время на начало сборки

    # Проверка, завершилась ли сборка
    echo -e "${BLUE}Ожидаем завершения сборки risc0-merkle-service...${NC}" >&2
    timeout 600 bash -c 'while screen -S risc -X stuff "echo \"still running\"\n" 2>/dev/null; do
        echo -e "${YELLOW}Сборка всё ещё выполняется, ждём...${NC}" >&2
        sleep 10
    done'
    if [ $? -ne 0 ]; then
        echo -e "${RED}Сборка risc0-merkle-service не завершилась за 10 минут!${NC}" >&2
        echo -e "${YELLOW}Проверьте логи screen-сессии: screen -r risc${NC}" >&2
        return 1
    fi
    echo -e "${GREEN}Сборка risc0-merkle-service завершена!${NC}" >&2

    # Сборка основного бинарника
    cd ..
    echo -e "${BLUE}Собираем основной бинарник light-node...${NC}" >&2
    go build
    if [ $? -ne 0 ]; then
        echo -e "${RED}Ошибка при сборке light-node! Проверьте зависимости Go.${NC}" >&2
        return 1
    fi
    echo -e "${GREEN}Сборка light-node завершена!${NC}" >&2

    # Создание сервисного файла
    echo -e "${BLUE}Создаём сервисный файл для автозапуска...${NC}" >&2
    sudo tee /etc/systemd/system/edged.service > /dev/null <<EOF
[Unit]
Description=Layer Edge
After=network.target
[Service]
User=root
WorkingDirectory=/root/light-node/
ExecStart=/root/light-node/light-node
Restart=on-failure
RestartSec=30
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

    # Запуск сервиса
    echo -e "${BLUE}Запускаем сервис edged...${NC}" >&2
    sudo systemctl daemon-reload
    sudo systemctl enable edged.service
    sudo systemctl start edged.service

    echo -e "${GREEN}Нода Layer Edge успешно установлена и запущена!${NC}" >&2
    echo -e "${YELLOW}Для просмотра логов используйте пункт меню 'Просмотреть логи'.${NC}" >&2
}

check_logs() {
    echo -e "${BLUE}Показываем логи сервиса edged...${NC}" >&2
    journalctl -u edged -f -o cat
    echo -e "${BLUE}Просмотр логов завершён. Возвращаемся в главное меню...${NC}" >&2
}

check_risc_logs() {
    echo -e "${BLUE}Показываем логи risc0-merkle-service (сессия screen 'risc')...${NC}" >&2
    if screen -list | grep -q "risc"; then
        screen -r risc
    else
        echo -e "${RED}Сессия screen 'risc' не найдена!${NC}" >&2
        echo -e "${YELLOW}Попробуйте запустить её вручную: cd ~/light-node/risc0-merkle-service && screen -S risc && cargo build && cargo run${NC}" >&2
    fi
    echo -e "${BLUE}Просмотр логов завершён. Возвращаемся в главное меню...${NC}" >&2
}

restart_node() {
    echo -e "${BLUE}Перезапускаем ноду Layer Edge...${NC}" >&2
    sudo systemctl stop edged.service
    sudo systemctl start edged.service
    echo -e "${GREEN}Нода Layer Edge успешно перезапущена!${NC}" >&2
}

delete_node() {
    echo -e "${YELLOW}Если уверены, что хотите удалить ноду, введите любую букву (CTRL+C чтобы выйти):${NC}" >&2
    if [ -t 0 ] && [ -t 1 ]; then
        read -p "> " checkjust < /dev/tty
    else
        echo -e "${YELLOW}Неинтерактивный режим: автоматически подтверждаем удаление.${NC}" >&2
        checkjust="y"
    fi

    # Остановка сервиса
    echo -e "${BLUE}Останавливаем сервис edged...${NC}" >&2
    sudo systemctl stop edged.service
    sudo systemctl disable edged.service
    sudo rm -f /etc/systemd/system/edged.service
    sudo systemctl daemon-reload
    echo -e "${GREEN}Сервис edged удалён.${NC}" >&2

    # Остановка screen-сессии
    echo -e "${BLUE}Останавливаем screen-сессию risc...${NC}" >&2
    screen -S risc -X quit 2>/dev/null
    echo -e "${GREEN}Screen-сессия risc остановлена.${NC}" >&2

    # Удаление директории
    echo -e "${BLUE}Удаляем директорию light-node...${NC}" >&2
    sudo rm -rf $HOME/light-node
    echo -e "${GREEN}Директория light-node удалена.${NC}" >&2

    echo -e "${GREEN}Нода Layer Edge полностью удалена!${NC}" >&2
}

exit_from_script() {
    echo -e "${BLUE}Выход из скрипта...${NC}" >&2
    exit 0
}

main_menu() {
    while true; do
        channel_logo
        sleep 2
        echo -e "\n\n${YELLOW}Выберите действие:${NC}" >&2
        echo -e "${CYAN}1. Установить ноду${NC}" >&2
        echo -e "${CYAN}2. Просмотреть логи ноды${NC}" >&2
        echo -e "${CYAN}3. Просмотреть логи risc0-merkle-service${NC}" >&2
        echo -e "${CYAN}4. Перезапустить ноду${NC}" >&2
        echo -e "${CYAN}5. Просмотреть приватный ключ${NC}" >&2
        echo -e "${CYAN}6. Просмотреть публичный ключ для дашборда${NC}" >&2
        echo -e "${CYAN}7. Удалить ноду${NC}" >&2
        echo -e "${CYAN}8. Выход${NC}" >&2
        
        echo -e "${YELLOW}Введите номер:${NC} " >&2
        if [ -t 0 ] && [ -t 1 ]; then
            read choice < /dev/tty
        else
            echo -e "${RED}Неинтерактивный режим: выбор невозможен. Выход...${NC}" >&2
            exit 1
        fi
        case $choice in
            1) install_node ;;
            2) check_logs ;;
            3) check_risc_logs ;;
            4) restart_node ;;
            5) view_private_key ;;
            6) view_public_key ;;
            7) delete_node ;;
            8) exit_from_script ;;
            *) echo -e "${RED}Неверный выбор, попробуйте снова.${NC}" >&2 ;;
        esac
    done
}

main_menu

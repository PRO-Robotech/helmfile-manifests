#!/bin/bash

# Функция для получения последней версии helmfile
get_latest_version() {
    curl --silent "https://api.github.com/repos/helmfile/helmfile/releases/latest" |   # Получаем последнюю версию через GitHub API
    grep '"tag_name":' |                                                              # Ищем строку с номером версии
    sed -E 's/.*"([^"]+)".*/\1/'                                                      # Извлекаем номер версии
}
VERSION=$(get_latest_version)
echo $VERSION


# Проверяем, установлен ли helmfile
if ! command -v helmfile &> /dev/null
then
    echo "helmfile не найден, выполняется установка..."

    # Определяем операционную систему
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')

    # Определяем архитектуру
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        i386|i686)
            ARCH="386"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        *)
            echo "Неподдерживаемая архитектура: $ARCH"
            exit 1
            ;;
    esac

    # Получаем последнюю версию
    VERSION=$(get_latest_version)

    # Формируем URL для загрузки
    echo "Загружается helmfile версии $VERSION для $OS-$ARCH..."
    DOWNLOAD_URL="https://github.com/helmfile/helmfile/releases/download/$VERSION/helmfile_${VERSION#v}_${OS}_${ARCH}.tar.gz"

    echo $DOWNLOAD_URL
    # Загружаем helmfile
    curl -L $DOWNLOAD_URL -o helmfile.tar.gz
    ls -al 
    # Распаковываем и устанавливаем
    tar -xzf helmfile.tar.gz helmfile
    chmod +x helmfile
    sudo mv helmfile /usr/local/bin/helmfile

    # Очищаем временные файлы
    rm helmfile.tar.gz

    echo "helmfile успешно установлен."
else
    echo "helmfile уже установлен."
fi

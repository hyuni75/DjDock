#!/bin/bash

# =============================================================================
# Django Docker Compose 초기 개발환경 설정 스크립트 - 최종 완성 버전
# WSL2, Ubuntu, CentOS 7 완벽 호환
# Docker 컨테이너 독립성을 활용한 최신 환경 지원
# =============================================================================

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
info() { echo -e "${CYAN}[INFO]${NC} $1"; }

# 시스템 감지
detect_system() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "WSL2"
    elif [[ -f /etc/centos-release ]]; then
        if grep -q "release 7" /etc/centos-release; then
            echo "CentOS7"
        else
            echo "CentOS"
        fi
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "Other"
    fi
}

# WSL2 환경 최적화 설정
setup_wsl2_environment() {
    if [[ "$SYSTEM" == "WSL2" ]]; then
        info "WSL2 환경 최적화 설정 중..."
        
        if ! locale -a | grep -q "ko_KR.utf8"; then
            warning "한글 로케일이 없습니다. 설치를 시작합니다..."
            sudo apt update -qq
            sudo apt install -y locales
            sudo locale-gen ko_KR.UTF-8
            sudo update-locale LANG=ko_KR.UTF-8
        fi
        
        if [[ ! -f ~/.vimrc ]] || ! grep -q "encoding=utf-8" ~/.vimrc; then
            info "Vim 한글 설정 추가..."
            cat >> ~/.vimrc << 'EOF'
" WSL2 한글 설정
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8,cp949,euc-kr
set termencoding=utf-8
EOF
            success "Vim 한글 설정 완료!"
        fi
        
        if ! grep -q "export LANG=ko_KR.UTF-8" ~/.bashrc; then
            echo '' >> ~/.bashrc
            echo '# WSL2 한글 환경 설정' >> ~/.bashrc
            echo 'export LANG=ko_KR.UTF-8' >> ~/.bashrc
            echo 'export LC_ALL=ko_KR.UTF-8' >> ~/.bashrc
            info "한글 환경변수가 ~/.bashrc에 추가되었습니다."
        fi
        
        export LANG=ko_KR.UTF-8
        export LC_ALL=ko_KR.UTF-8
    fi
}

# Make 설치 확인 및 설치
check_and_install_make() {
    if ! command -v make &> /dev/null; then
        warning "Make가 설치되어 있지 않습니다. 설치를 시작합니다..."
        
        if [[ "$SYSTEM" == "WSL2" ]] || [[ "$SYSTEM" == "ubuntu" ]]; then
            info "Ubuntu/WSL2에서 make 설치 중..."
            sudo apt update -qq
            sudo apt install -y make
            success "Make 설치 완료!"
        elif [[ "$SYSTEM" == "CentOS7" ]] || [[ "$SYSTEM" == "CentOS" ]]; then
            info "CentOS에서 make 설치 중..."
            sudo yum install -y make
            success "Make 설치 완료!"
        fi
    else
        info "Make가 이미 설치되어 있습니다."
    fi
}

# Docker 설치 확인
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker가 설치되어 있지 않습니다. 먼저 Docker를 설치해주세요."
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker 데몬이 실행중이지 않습니다. Docker를 시작해주세요."
    fi
    
    local docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    info "Docker 버전: $docker_version"
}

# Docker Compose 버전 확인
check_docker_compose() {
    COMPOSE_CMD=""
    
    if docker compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
        local version=$(docker compose version --short 2>/dev/null)
        info "Docker Compose v2 발견: $version (권장)"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
        local version=$(docker-compose version --short 2>/dev/null)
        info "Docker Compose v1 발견: $version"
    fi
    
    if [[ -z "$COMPOSE_CMD" ]]; then
        error "Docker Compose가 설치되어 있지 않습니다."
    fi
}

echo "======================================================="
echo "     Django Docker Compose 개발환경 초기화"
echo "     최종 완성 버전 (2024-2025)"
echo "======================================================="

SYSTEM=$(detect_system)
info "시스템 감지: $SYSTEM"

if [[ "$SYSTEM" == "WSL2" ]]; then
    success "WSL2가 감지되었습니다. 최적의 성능을 제공합니다."
    setup_wsl2_environment
fi

check_and_install_make
check_docker
check_docker_compose

# 프로젝트 설정 입력
echo ""
read -p "프로젝트 이름을 입력하세요: " PROJECT_NAME
read -p "웹 포트를 입력하세요 (기본값: 8084): " WEB_PORT
WEB_PORT=${WEB_PORT:-8084}
read -p "DB 포트를 입력하세요 (기본값: 3334): " DB_PORT
DB_PORT=${DB_PORT:-3334}
read -p "DB 이름을 입력하세요 (기본값: $PROJECT_NAME): " DB_NAME
DB_NAME=${DB_NAME:-$PROJECT_NAME}
read -p "DB 사용자를 입력하세요 (기본값: $PROJECT_NAME): " DB_USER
DB_USER=${DB_USER:-$PROJECT_NAME}
read -sp "DB 비밀번호를 입력하세요: " DB_PASS
echo ""

# 개발 환경 선택
echo ""
echo "개발 환경을 선택하세요:"
echo "1) 최신 환경 (Ubuntu 24.04 + Python 3.12 + Django 5.0) - 권장"
echo "2) 안정성 우선 (Ubuntu 22.04 + Python 3.11 + Django 4.2 LTS)"
echo "3) 호환성 우선 (Ubuntu 22.04 + Python 3.10 + Django 4.2 LTS)"
echo "4) 레거시 지원 (Ubuntu 20.04 + Python 3.8 + Django 3.2 LTS)"

read -p "선택 (1-4, 기본값: 1): " ENV_CHOICE
ENV_CHOICE=${ENV_CHOICE:-1}

case $ENV_CHOICE in
    1)
        UBUNTU_VERSION="24.04"
        UBUNTU_CODENAME="noble"
        PYTHON_VERSION="3.12"
        DJANGO_VERSION="5.0"
        info "최신 환경 선택됨"
        ;;
    2)
        UBUNTU_VERSION="22.04"
        UBUNTU_CODENAME="jammy"
        PYTHON_VERSION="3.11"
        DJANGO_VERSION="4.2"
        info "안정성 우선 환경 선택됨"
        ;;
    3)
        UBUNTU_VERSION="22.04"
        UBUNTU_CODENAME="jammy"
        PYTHON_VERSION="3.10"
        DJANGO_VERSION="4.2"
        info "호환성 우선 환경 선택됨"
        ;;
    4)
        UBUNTU_VERSION="20.04"
        UBUNTU_CODENAME="focal"
        PYTHON_VERSION="3.8"
        DJANGO_VERSION="3.2"
        info "레거시 지원 환경 선택됨"
        ;;
    *)
        UBUNTU_VERSION="24.04"
        UBUNTU_CODENAME="noble"
        PYTHON_VERSION="3.12"
        DJANGO_VERSION="5.0"
        info "기본값: 최신 환경"
        ;;
esac

# 성능 설정
MAX_UPLOAD_SIZE="500M"
NGINX_TIMEOUT="300"
GUNICORN_TIMEOUT="300"

CPU_CORES=$(nproc 2>/dev/null || echo 2)
GUNICORN_WORKERS=$(( (2 * CPU_CORES) + 1 ))
if [ $GUNICORN_WORKERS -gt 8 ]; then
    GUNICORN_WORKERS=8
fi

log "프로젝트 디렉토리 생성 중..."
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

# Docker 관련 디렉토리 구조 생성
mkdir -p docker/{nginx/sites-{available,enabled},django/scripts,mariadb}
mkdir -p src/{logs,media,run}
mkdir -p src/static/{css,js,images}
mkdir -p src/templates/{components,includes}
mkdir -p src/config/settings
mkdir -p src/apps

# .env 파일 생성
log ".env 파일 생성 중..."
SECRET_KEY=$(openssl rand -base64 50 | tr -d "=+/\n" | cut -c1-50)
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/\n" | cut -c1-25)

cat > .env << EOF
# System Info
SYSTEM_TYPE=$SYSTEM

# Project Settings
PROJECT_NAME=$PROJECT_NAME
WEB_PORT=$WEB_PORT
DB_PORT=$DB_PORT

# Environment Settings
UBUNTU_VERSION=$UBUNTU_VERSION
UBUNTU_CODENAME=$UBUNTU_CODENAME
PYTHON_VERSION=$PYTHON_VERSION
DJANGO_VERSION=$DJANGO_VERSION

# Database
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$DB_NAME
MYSQL_USER=$DB_USER
MYSQL_PASSWORD=$DB_PASS

# Django
DEBUG=True
ALLOWED_HOSTS=*
SECRET_KEY=$SECRET_KEY

# Performance Settings
MAX_UPLOAD_SIZE=$MAX_UPLOAD_SIZE
NGINX_TIMEOUT=$NGINX_TIMEOUT
GUNICORN_TIMEOUT=$GUNICORN_TIMEOUT
GUNICORN_WORKERS=$GUNICORN_WORKERS

# Locale Settings
LANG=ko_KR.UTF-8
LC_ALL=ko_KR.UTF-8
PYTHONIOENCODING=utf-8
TZ=Asia/Seoul
EOF

# 환경변수 export 스크립트 생성
cat > load-env.sh << 'EOF'
#!/bin/bash
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo "환경변수가 로드되었습니다."
    echo "PROJECT_NAME: $PROJECT_NAME"
else
    echo ".env 파일을 찾을 수 없습니다."
fi
EOF
chmod +x load-env.sh

# docker-compose.yml 생성
log "docker-compose.yml 생성 중..."

VOLUME_OPTS=""
if [[ "$SYSTEM" == "CentOS7" ]]; then
    VOLUME_OPTS=",Z"  # SELinux 컨텍스트 (ro와 함께 사용 시 콤마)
fi

if [[ "$COMPOSE_CMD" == "docker compose" ]]; then
    cat > docker-compose.yml << EOF
services:
  db:
    image: mariadb:10.6
    container_name: \${PROJECT_NAME}_db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: \${MYSQL_DATABASE}
      MYSQL_USER: \${MYSQL_USER}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
      TZ: \${TZ}
    volumes:
      - mysql_data:/var/lib/mysql
      - ./docker/mariadb/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro${VOLUME_OPTS}
      - ./docker/mariadb/my.cnf:/etc/mysql/conf.d/custom.cnf:ro${VOLUME_OPTS}
    ports:
      - "\${DB_PORT}:3306"
    networks:
      - app_network
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  web:
    build:
      context: .
      dockerfile: docker/django/Dockerfile
      args:
        UBUNTU_VERSION: \${UBUNTU_VERSION}
        PYTHON_VERSION: \${PYTHON_VERSION}
        PROJECT_NAME: \${PROJECT_NAME}
    container_name: \${PROJECT_NAME}_web
    restart: unless-stopped
    volumes:
      - ./src:/var/www/html/\${PROJECT_NAME}:Z
      - socket_volume:/var/www/html/\${PROJECT_NAME}/run
      - ./docker/django/scripts:/scripts:ro${VOLUME_OPTS}
    depends_on:
      db:
        condition: service_healthy
    environment:
      - PROJECT_NAME=\${PROJECT_NAME}
      - DB_NAME=\${MYSQL_DATABASE}
      - DB_USER=\${MYSQL_USER}
      - DB_PASS=\${MYSQL_PASSWORD}
      - DB_HOST=db
      - DB_PORT=3306
      - DEBUG=\${DEBUG}
      - SECRET_KEY=\${SECRET_KEY}
      - ALLOWED_HOSTS=\${ALLOWED_HOSTS}
      - MAX_UPLOAD_SIZE=\${MAX_UPLOAD_SIZE}
      - GUNICORN_TIMEOUT=\${GUNICORN_TIMEOUT}
      - GUNICORN_WORKERS=\${GUNICORN_WORKERS}
      - LANG=\${LANG}
      - LC_ALL=\${LC_ALL}
      - PYTHONIOENCODING=\${PYTHONIOENCODING}
      - TZ=\${TZ}
    networks:
      - app_network
    command: /scripts/entrypoint.sh

  nginx:
    image: nginx:mainline-alpine
    container_name: \${PROJECT_NAME}_nginx
    restart: unless-stopped
    volumes:
      - ./docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro${VOLUME_OPTS}
      - ./docker/nginx/sites-enabled:/etc/nginx/sites-enabled:ro${VOLUME_OPTS}
      - ./src:/var/www/html/\${PROJECT_NAME}:ro${VOLUME_OPTS}
      - socket_volume:/var/www/html/\${PROJECT_NAME}/run
    ports:
      - "\${WEB_PORT}:80"
    depends_on:
      - web
    environment:
      - NGINX_TIMEOUT=\${NGINX_TIMEOUT}
      - MAX_UPLOAD_SIZE=\${MAX_UPLOAD_SIZE}
      - TZ=\${TZ}
    networks:
      - app_network

volumes:
  mysql_data:
  socket_volume:

networks:
  app_network:
    driver: bridge
EOF
else
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  db:
    image: mariadb:10.6
    container_name: \${PROJECT_NAME}_db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: \${MYSQL_DATABASE}
      MYSQL_USER: \${MYSQL_USER}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD}
      TZ: \${TZ}
    volumes:
      - mysql_data:/var/lib/mysql
      - ./docker/mariadb/init.sql:/docker-entrypoint-initdb.d/01-init.sql:ro${VOLUME_OPTS}
      - ./docker/mariadb/my.cnf:/etc/mysql/conf.d/custom.cnf:ro${VOLUME_OPTS}
    ports:
      - "\${DB_PORT}:3306"
    networks:
      - app_network
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  web:
    build:
      context: .
      dockerfile: docker/django/Dockerfile
      args:
        UBUNTU_VERSION: \${UBUNTU_VERSION}
        PYTHON_VERSION: \${PYTHON_VERSION}
        PROJECT_NAME: \${PROJECT_NAME}
    container_name: \${PROJECT_NAME}_web
    restart: unless-stopped
    volumes:
      - ./src:/var/www/html/\${PROJECT_NAME}:Z
      - socket_volume:/var/www/html/\${PROJECT_NAME}/run
      - ./docker/django/scripts:/scripts:ro${VOLUME_OPTS}
    depends_on:
      db:
        condition: service_healthy
    environment:
      - PROJECT_NAME=\${PROJECT_NAME}
      - DB_NAME=\${MYSQL_DATABASE}
      - DB_USER=\${MYSQL_USER}
      - DB_PASS=\${MYSQL_PASSWORD}
      - DB_HOST=db
      - DB_PORT=3306
      - DEBUG=\${DEBUG}
      - SECRET_KEY=\${SECRET_KEY}
      - ALLOWED_HOSTS=\${ALLOWED_HOSTS}
      - MAX_UPLOAD_SIZE=\${MAX_UPLOAD_SIZE}
      - GUNICORN_TIMEOUT=\${GUNICORN_TIMEOUT}
      - GUNICORN_WORKERS=\${GUNICORN_WORKERS}
      - LANG=\${LANG}
      - LC_ALL=\${LC_ALL}
      - PYTHONIOENCODING=\${PYTHONIOENCODING}
      - TZ=\${TZ}
    networks:
      - app_network
    command: /scripts/entrypoint.sh

  nginx:
    image: nginx:mainline-alpine
    container_name: \${PROJECT_NAME}_nginx
    restart: unless-stopped
    volumes:
      - ./docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro${VOLUME_OPTS}
      - ./docker/nginx/sites-enabled:/etc/nginx/sites-enabled:ro${VOLUME_OPTS}
      - ./src:/var/www/html/\${PROJECT_NAME}:ro${VOLUME_OPTS}
      - socket_volume:/var/www/html/\${PROJECT_NAME}/run
    ports:
      - "\${WEB_PORT}:80"
    depends_on:
      - web
    environment:
      - NGINX_TIMEOUT=\${NGINX_TIMEOUT}
      - MAX_UPLOAD_SIZE=\${MAX_UPLOAD_SIZE}
      - TZ=\${TZ}
    networks:
      - app_network

volumes:
  mysql_data:
  socket_volume:

networks:
  app_network:
    driver: bridge
EOF
fi

# Dockerfile 생성
log "Dockerfile 생성 중..."
cat > docker/django/Dockerfile << EOF
ARG UBUNTU_VERSION=24.04
FROM ubuntu:\${UBUNTU_VERSION} AS base

ARG PYTHON_VERSION=3.12
ARG PROJECT_NAME

ENV DEBIAN_FRONTEND=noninteractive \\
    PYTHONDONTWRITEBYTECODE=1 \\
    PYTHONUNBUFFERED=1 \\
    PYTHONIOENCODING=utf-8 \\
    TZ=Asia/Seoul \\
    LANG=ko_KR.UTF-8 \\
    LC_ALL=ko_KR.UTF-8 \\
    LANGUAGE=ko_KR:ko:en_US:en

RUN rm -f /etc/apt/sources.list.d/*.list && \\
    echo "deb http://mirror.kakao.com/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse" > /etc/apt/sources.list && \\
    echo "deb http://mirror.kakao.com/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse" >> /etc/apt/sources.list && \\
    echo "deb http://mirror.kakao.com/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse" >> /etc/apt/sources.list && \\
    echo "deb http://mirror.kakao.com/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse" >> /etc/apt/sources.list && \\
    apt-get clean && \\
    rm -rf /var/lib/apt/lists/* && \\
    apt-get update && \\
    apt-get install -y --no-install-recommends \\
    software-properties-common \\
    build-essential \\
    pkg-config \\
    curl \\
    wget \\
    vim \\
    python\${PYTHON_VERSION} \\
    python\${PYTHON_VERSION}-dev \\
    python\${PYTHON_VERSION}-venv \\
    python3-pip \\
    default-libmysqlclient-dev \\
    mariadb-client \\
    netcat-openbsd \\
    locales \\
    fonts-nanum \\
    fontconfig \\
    wkhtmltopdf \\
    tzdata \\
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python\${PYTHON_VERSION} 1 && \\
    update-alternatives --install /usr/bin/python python /usr/bin/python\${PYTHON_VERSION} 1

RUN sed -i '/ko_KR.UTF-8/s/^# //g' /etc/locale.gen && \\
    locale-gen ko_KR.UTF-8 && \\
    update-locale LANG=ko_KR.UTF-8 LC_ALL=ko_KR.UTF-8

RUN ln -snf /usr/share/zoneinfo/Asia/Seoul /etc/localtime && \\
    echo "Asia/Seoul" > /etc/timezone && \\
    dpkg-reconfigure -f noninteractive tzdata

WORKDIR /var/www/html/\${PROJECT_NAME}

RUN python\${PYTHON_VERSION} -m venv /opt/venv
ENV PATH="/opt/venv/bin:\$PATH"

COPY requirements.txt /tmp/
RUN pip install --upgrade pip setuptools wheel && \\
    pip install -r /tmp/requirements.txt && \\
    playwright install chromium && \\
    playwright install-deps chromium && \\
    apt-get update && \\
    apt-get install -y --no-install-recommends fonts-noto-cjk fonts-noto-cjk-extra && \\
    rm -rf /var/lib/apt/lists/*

RUN fc-cache -fv

RUN useradd -ms /bin/bash django

EXPOSE 8000
EOF

# requirements.txt 생성
log "requirements.txt 생성 중..."
cat > requirements.txt << EOF
# Django Core
django==$DJANGO_VERSION
gunicorn==21.2.0

# Database
pymysql==1.1.0
mysqlclient==2.2.0

# Django Extensions
djangorestframework==3.14.0
django-extensions==3.2.3
django-debug-toolbar==4.2.0
django-cors-headers==4.3.1

# Authentication & Security
argon2-cffi==23.1.0
django-environ==0.11.2

# File Processing
pillow==10.1.0
openpyxl==3.1.2
pandas==2.1.4
arrow==1.3.0

# Document Processing
reportlab==4.0.8
pdfkit==1.0.0
weasyprint==60.1

# Utilities
ipython==8.18.1
python-dotenv==1.0.0
chardet==5.2.0

# Monitoring & Logging
django-silk==5.0.4

# Cache
django-redis==5.4.0
redis==5.0.1

# Others
django-user-agents==0.4.0
plotly==5.18.0
chart-studio==1.1.0

# Test Coverage
coverage==7.3.2

# Testing Framework
playwright==1.55.0
EOF

if [[ "$DJANGO_VERSION" == "5.0" ]]; then
    echo "" >> requirements.txt
    echo "# Async Support" >> requirements.txt
    echo "channels==4.0.0" >> requirements.txt
    echo "channels-redis==4.1.0" >> requirements.txt
fi

# MariaDB 설정 파일
log "MariaDB 설정 파일 생성 중..."
cat > docker/mariadb/my.cnf << 'EOF'
[client]
default-character-set = utf8mb4
port = 3306

[mysql]
default-character-set = utf8mb4

[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
skip-character-set-client-handshake

default-time-zone = '+9:00'

max_connections = 200
max_allowed_packet = 512M
innodb_buffer_pool_size = 512M
innodb_log_file_size = 128M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT

query_cache_type = 1
query_cache_size = 32M

bind-address = 0.0.0.0

slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
EOF

# MariaDB 초기화 SQL
cat > docker/mariadb/init.sql << EOF
ALTER DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

SELECT @@global.time_zone, @@session.time_zone;

SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
SHOW VARIABLES LIKE 'max_connections';
EOF

# Nginx 메인 설정
log "Nginx 설정 파일 생성 중..."
cat > docker/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
worker_rlimit_nofile 65535;

error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    charset utf-8;
    charset_types text/plain text/css text/xml text/javascript 
                   application/javascript application/json application/xml+rss;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 300s;
    keepalive_requests 100;
    reset_timedout_connection on;

    client_max_body_size 500M;
    client_body_buffer_size 128k;
    client_body_temp_path /tmp/nginx_client_temp 1 2;

    proxy_buffer_size 8k;
    proxy_buffers 8 8k;
    proxy_busy_buffers_size 16k;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript 
               application/javascript application/json application/xml+rss
               application/x-font-ttf font/opentype image/svg+xml;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    server_tokens off;

    include /etc/nginx/sites-enabled/*;
}
EOF

# Nginx 사이트 설정 (환경변수 직접 치환)
cat > docker/nginx/sites-enabled/$PROJECT_NAME << EOF
upstream ${PROJECT_NAME}_backend {
    server unix:/var/www/html/$PROJECT_NAME/run/$PROJECT_NAME.sock fail_timeout=0;
    keepalive 32;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    charset utf-8;

    access_log /var/log/nginx/${PROJECT_NAME}_access.log main;
    error_log /var/log/nginx/${PROJECT_NAME}_error.log;

    client_max_body_size $MAX_UPLOAD_SIZE;

    location /static/ {
        alias /var/www/html/$PROJECT_NAME/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    location /media/ {
        alias /var/www/html/$PROJECT_NAME/media/;
        expires 30d;
        add_header Cache-Control "public";
    }

    location /favicon.ico {
        alias /var/www/html/$PROJECT_NAME/static/images/favicon.ico;
        access_log off;
        log_not_found off;
    }

    location /robots.txt {
        alias /var/www/html/$PROJECT_NAME/static/robots.txt;
        access_log off;
        log_not_found off;
    }

    location / {
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Nginx-Proxy true;

        proxy_redirect off;
        proxy_buffering off;

        proxy_pass http://${PROJECT_NAME}_backend;

        proxy_connect_timeout ${NGINX_TIMEOUT}s;
        proxy_send_timeout ${NGINX_TIMEOUT}s;
        proxy_read_timeout ${NGINX_TIMEOUT}s;

        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    location /health/ {
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Django entrypoint 스크립트
log "Django entrypoint 스크립트 생성 중..."
cat > docker/django/scripts/entrypoint.sh << 'EOF'
#!/bin/bash
set -e

export LANG=ko_KR.UTF-8
export LC_ALL=ko_KR.UTF-8
export PYTHONIOENCODING=utf-8

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Django 컨테이너 시작${NC}"
echo "프로젝트: $PROJECT_NAME"
echo "Python: $(python --version)"
echo "한글 설정: $LANG"
echo "시스템 시간: $(date +'%Y년 %m월 %d일 %H시 %M분 %S초')"

cd /var/www/html/$PROJECT_NAME

echo "데이터베이스 연결 대기 중..."
timeout=30
counter=0
while ! mysqladmin ping -h db -P 3306 -u$DB_USER -p$DB_PASS --silent 2>/dev/null; do
    counter=$((counter+1))
    if [ $counter -gt $timeout ]; then
        echo -e "${RED}데이터베이스 연결 실패 (${timeout}초 초과)${NC}"
        exit 1
    fi
    echo -n "."
    sleep 1
done
echo -e "\n${GREEN}데이터베이스 연결 성공!${NC}"

if [ ! -f "manage.py" ]; then
    echo "Django 프로젝트 생성 중..."
    django-admin startproject config .
    
    python /scripts/create_secrets.py
    
    cp /scripts/settings.py config/settings.py
    cp /scripts/urls.py config/urls.py
    
    cat > config/__init__.py << 'INIT'
# -*- coding: utf-8 -*-
import pymysql
pymysql.install_as_MySQLdb()

__version__ = '1.0.0'
INIT
    
    python manage.py startapp main
    
    mkdir -p main/templates/main
    mkdir -p main/static/main/{css,js,img}
    
    cat > main/apps.py << 'APPS'
from django.apps import AppConfig

class MainConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'main'
    verbose_name = '메인'
APPS
fi

echo "마이그레이션 실행 중..."
python manage.py makemigrations
python manage.py migrate

echo "Static 파일 수집 중..."
python manage.py collectstatic --noinput

mkdir -p logs staticfiles media run
chmod -R 755 logs/ staticfiles/ media/ run/

rm -f run/$PROJECT_NAME.sock

echo -e "${GREEN}Gunicorn 시작 (Workers: ${GUNICORN_WORKERS:-4})${NC}"
exec gunicorn config.wsgi:application \
    --name $PROJECT_NAME \
    --bind unix:run/$PROJECT_NAME.sock \
    --workers ${GUNICORN_WORKERS:-4} \
    --timeout ${GUNICORN_TIMEOUT:-300} \
    --graceful-timeout 30 \
    --max-requests 1000 \
    --max-requests-jitter 50 \
    --access-logfile logs/gunicorn_access.log \
    --error-logfile logs/gunicorn_error.log \
    --log-level info
EOF
chmod +x docker/django/scripts/entrypoint.sh

# secrets.json 생성 스크립트
cat > docker/django/scripts/create_secrets.py << 'EOF'
# -*- coding: utf-8 -*-
import json
import os

project_path = f"/var/www/html/{os.environ['PROJECT_NAME']}"
secrets = {
    "SECRET_KEY": os.environ.get('SECRET_KEY', 'django-insecure-change-this-in-production'),
    "EMAIL_HOST_PASSWORD": ""
}

with open(f"{project_path}/secrets.json", 'w', encoding='utf-8') as f:
    json.dump(secrets, f, indent=4, ensure_ascii=False)

print("✅ secrets.json 생성 완료!")
EOF

# Django settings.py와 urls.py는 너무 길어서 별도 파일로 생성
cat > docker/django/scripts/settings.py << 'SETTINGSEOF'
# -*- coding: utf-8 -*-
from pathlib import Path
import os
import json
from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent
LOGS_DIR = os.path.join(BASE_DIR, 'logs')
os.makedirs(LOGS_DIR, exist_ok=True)

secret_file = os.path.join(BASE_DIR, 'secrets.json')
with open(secret_file, encoding='utf-8') as f:
    secrets = json.loads(f.read())

def get_secret(setting, secrets=secrets):
    try:
        return secrets[setting]
    except KeyError:
        error_msg = f"Set the {setting} environment variable"
        raise ImproperlyConfigured(error_msg)

SECRET_KEY = get_secret("SECRET_KEY")
DEBUG = os.environ.get('DEBUG', 'False') == 'True'
ALLOWED_HOSTS = ['*'] if DEBUG else os.environ.get('ALLOWED_HOSTS', '').split(',')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.humanize',
    'rest_framework',
    'django_extensions',
    'corsheaders',
    'main',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.locale.LocaleMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [os.path.join(BASE_DIR, 'templates')],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'django.template.context_processors.i18n',
                'django.template.context_processors.media',
                'django.template.context_processors.static',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': os.environ.get('DB_NAME'),
        'USER': os.environ.get('DB_USER'),
        'PASSWORD': os.environ.get('DB_PASS'),
        'HOST': os.environ.get('DB_HOST', 'db'),
        'PORT': os.environ.get('DB_PORT', '3306'),
        'OPTIONS': {
            'charset': 'utf8mb4',
            'use_unicode': True,
            'init_command': "SET sql_mode='STRICT_TRANS_TABLES'",
            'connect_timeout': 10,
        },
        'CONN_MAX_AGE': 60,
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator', 'OPTIONS': {'min_length': 8}},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'ko-kr'
TIME_ZONE = 'Asia/Seoul'
USE_I18N = True
USE_L10N = True
USE_TZ = True

LANGUAGES = [('ko', '한국어'), ('en', 'English')]
LOCALE_PATHS = [os.path.join(BASE_DIR, 'locale')]

STATIC_URL = '/static/'
STATICFILES_DIRS = [os.path.join(BASE_DIR, 'static')] if os.path.exists(os.path.join(BASE_DIR, 'static')) else []
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

DATA_UPLOAD_MAX_MEMORY_SIZE = 1024 * 1024 * 500
FILE_UPLOAD_MAX_MEMORY_SIZE = 1024 * 1024 * 100
DATA_UPLOAD_MAX_NUMBER_FIELDS = 10000
FILE_UPLOAD_TEMP_DIR = '/tmp'

FILE_UPLOAD_HANDLERS = ['django.core.files.uploadhandler.TemporaryFileUploadHandler']

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

SESSION_COOKIE_AGE = 86400 * 7
SESSION_EXPIRE_AT_BROWSER_CLOSE = False
SESSION_SAVE_EVERY_REQUEST = True
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Lax'
SESSION_ENGINE = 'django.contrib.sessions.backends.db'

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'unique-snowflake',
    }
}

CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    f"http://localhost:{os.environ.get('WEB_PORT', '8000')}",
]

REST_FRAMEWORK = {
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
        'rest_framework.renderers.BrowsableAPIRenderer',
    ],
    'DEFAULT_PARSER_CLASSES': [
        'rest_framework.parsers.JSONParser',
        'rest_framework.parsers.FormParser',
        'rest_framework.parsers.MultiPartParser',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
}

if DEBUG:
    INSTALLED_APPS += ['debug_toolbar', 'silk']
    MIDDLEWARE.insert(0, 'debug_toolbar.middleware.DebugToolbarMiddleware')
    MIDDLEWARE.append('silk.middleware.SilkyMiddleware')
    INTERNAL_IPS = ['127.0.0.1', 'localhost']
    
    import socket
    hostname, _, ips = socket.gethostbyname_ex(socket.gethostname())
    INTERNAL_IPS += [ip[:-1] + '1' for ip in ips]

PROJECT_NAME = os.environ.get('PROJECT_NAME', 'Django Project')
PROJECT_VERSION = '1.0.0'
SETTINGSEOF

# Django urls.py
cat > docker/django/scripts/urls.py << 'URLSEOF'
# -*- coding: utf-8 -*-
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.http import JsonResponse

def index(request):
    return JsonResponse({
        'project': settings.PROJECT_NAME,
        'version': settings.PROJECT_VERSION,
        'status': 'healthy',
        'language': settings.LANGUAGE_CODE,
        'timezone': settings.TIME_ZONE,
        'debug': settings.DEBUG,
        'message': '🚀 Django 프로젝트가 성공적으로 실행중입니다!'
    }, json_dumps_params={'ensure_ascii': False})

def health_check(request):
    return JsonResponse({'status': 'healthy'})

urlpatterns = [
    path('', index, name='index'),
    path('health/', health_check, name='health_check'),
    path('admin/', admin.site.urls),
    path('api/', include('rest_framework.urls')),
    path('api/v1/', include('main.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    
    import debug_toolbar
    urlpatterns = [
        path('__debug__/', include(debug_toolbar.urls)),
        path('silk/', include('silk.urls', namespace='silk')),
    ] + urlpatterns

admin.site.site_header = f'{settings.PROJECT_NAME} 관리'
admin.site.site_title = f'{settings.PROJECT_NAME}'
admin.site.index_title = '관리 홈'
URLSEOF

# main 앱 urls.py
mkdir -p src/main
cat > src/main/urls.py << 'EOF'
# -*- coding: utf-8 -*-
from django.urls import path
from rest_framework.decorators import api_view
from rest_framework.response import Response

@api_view(['GET'])
def test_api(request):
    return Response({
        'message': '한글 테스트: 가나다라마바사',
        'timestamp': '2024년 12월',
        'status': 'success'
    })

app_name = 'main'
urlpatterns = [
    path('test/', test_api, name='test_api'),
]
EOF

# .gitignore 생성
log ".gitignore 생성 중..."
cat > .gitignore << 'EOF'
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
.env
*.env
*.log
local_settings.py
db.sqlite3
media/
staticfiles/
secrets.json
.vscode/
.idea/
*.swp
*.swo
.DS_Store
mysql_data/
logs/
*.tmp
*.bak
*~
.coverage
.pytest_cache/
htmlcov/
src/secrets.json
src/logs/
src/media/
src/staticfiles/
EOF

# WSL2 최적화 스크립트
if [[ "$SYSTEM" == "WSL2" ]]; then
    log "WSL2 최적화 스크립트 생성 중..."
    cat > optimize-wsl2.sh << 'EOF'
#!/bin/bash

echo "WSL2 성능 최적화 시작..."

WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')
WIN_HOME="/mnt/c/Users/$WIN_USER"

if [ -d "$WIN_HOME" ]; then
    cat > "$WIN_HOME/.wslconfig" << 'CONFIG'
[wsl2]
memory=8GB
processors=4
swap=2GB
localhostForwarding=true

[experimental]
sparseVhd=true
CONFIG
    echo ".wslconfig 파일이 생성되었습니다: $WIN_HOME/.wslconfig"
    echo "WSL을 재시작하려면: wsl --shutdown"
fi

echo ""
echo "한글 환경 설정 확인:"
echo "LANG: $LANG"
echo "LC_ALL: $LC_ALL"

if [ -f ~/.vimrc ]; then
    echo "Vim 한글 설정: 완료"
else
    echo "Vim 한글 설정: 미완료"
fi

echo ""
echo "WSL2 최적화 팁:"
echo "1. Linux 파일시스템 사용 (/home/user/ 이하)"
echo "2. Windows 파일시스템 (/mnt/c/) 사용 피하기"
echo "3. Visual Studio Code에서 Remote-WSL 확장 사용"
echo "4. Windows Terminal에서 한글 지원 폰트 설정"
echo ""
echo "WSL2 최적화 완료!"
EOF
    chmod +x optimize-wsl2.sh
    info "WSL2 최적화를 위해 './optimize-wsl2.sh' 실행을 권장합니다."
fi

# cleanup 스크립트 생성
cat > cleanup_project.sh << 'EOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ -z "$1" ]; then
    read -p "초기화할 프로젝트 이름을 입력하세요: " PROJECT_NAME
else
    PROJECT_NAME=$1
fi

echo -e "${YELLOW}[WARNING]${NC} '$PROJECT_NAME' 프로젝트를 완전히 초기화합니다."
echo -e "${YELLOW}[WARNING]${NC} 모든 데이터가 삭제됩니다!"
read -p "정말 계속하시겠습니까? [y/N]: " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo -e "${BLUE}[INFO]${NC} 취소되었습니다."
    exit 0
fi

echo -e "${BLUE}[INFO]${NC} 프로젝트 초기화 시작..."

if [ -d "$HOME/$PROJECT_NAME" ]; then
    cd "$HOME/$PROJECT_NAME"
    
    if [ -f "docker-compose.yml" ]; then
        echo -e "${BLUE}[INFO]${NC} Docker 컨테이너, 볼륨, 네트워크 제거 중..."
        
        if command -v docker-compose &> /dev/null; then
            COMPOSE_CMD="docker-compose"
        else
            COMPOSE_CMD="docker compose"
        fi
        
        if [ -f ".env" ]; then
            $COMPOSE_CMD --env-file .env down -v --remove-orphans 2>/dev/null || true
        else
            $COMPOSE_CMD down -v --remove-orphans 2>/dev/null || true
        fi
    fi
    
    cd ..
fi

echo -e "${BLUE}[INFO]${NC} Docker 리소스 정리 중..."

CONTAINERS=$(docker ps -a -q --filter "name=${PROJECT_NAME}")
if [ ! -z "$CONTAINERS" ]; then
    echo "  - 컨테이너 제거 중..."
    docker rm -f $CONTAINERS 2>/dev/null || true
fi

IMAGES=$(docker images -q "${PROJECT_NAME}*")
if [ ! -z "$IMAGES" ]; then
    echo "  - 이미지 제거 중..."
    docker rmi -f $IMAGES 2>/dev/null || true
fi

VOLUMES=$(docker volume ls -q | grep "${PROJECT_NAME}")
if [ ! -z "$VOLUMES" ]; then
    echo "  - 볼륨 제거 중..."
    docker volume rm $VOLUMES 2>/dev/null || true
fi

NETWORKS=$(docker network ls -q --filter "name=${PROJECT_NAME}")
if [ ! -z "$NETWORKS" ]; then
    echo "  - 네트워크 제거 중..."
    docker network rm $NETWORKS 2>/dev/null || true
fi

if [ -d "$HOME/$PROJECT_NAME" ]; then
    echo -e "${BLUE}[INFO]${NC} 프로젝트 디렉토리 삭제 중..."
    rm -rf "$HOME/$PROJECT_NAME"
fi

echo -e "${GREEN}[SUCCESS]${NC} '$PROJECT_NAME' 프로젝트가 완전히 초기화되었습니다!"
EOF

chmod +x cleanup_project.sh

# Makefile 생성 (TAB 문자 확실히 처리)
log "Makefile 생성 중..."

# printf를 사용하여 명시적으로 TAB 문자 삽입
cat > Makefile << 'EOF'
# Docker Compose 명령 설정
COMPOSE_BASE := docker compose
COMPOSE_CMD := $(COMPOSE_BASE) --env-file .env

.PHONY: help init build up down restart logs shell bash migrate createsuperuser collectstatic clean

help:
	@echo "======================================"
	@echo "Django Docker 개발환경 명령어"
	@echo "======================================"
	@echo "make init           - 초기 설정 (build + up + migrate + collectstatic)"
	@echo "make build          - Docker 이미지 빌드"
	@echo "make up             - 컨테이너 시작"
	@echo "make down           - 컨테이너 중지"
	@echo "make restart        - 컨테이너 재시작"
	@echo "make logs           - 전체 로그 확인"
	@echo "make shell          - Django Shell 접속"
	@echo "make bash           - 웹 컨테이너 bash 접속"
	@echo "make migrate        - 마이그레이션 실행"
	@echo "make createsuperuser - 슈퍼유저 생성"
	@echo "make collectstatic  - Static 파일 수집"
	@echo "make clean          - 모든 컨테이너/볼륨 제거"

init: build up
	@sleep 5
	@echo "마이그레이션 실행 중..."
	@$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$${PROJECT_NAME} && python manage.py makemigrations && python manage.py migrate"
	@echo "Static 파일 수집 중..."
	@$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$${PROJECT_NAME} && python manage.py collectstatic --noinput"
	@echo "✅ 초기 설정 완료! 다음 단계: make createsuperuser"

build:
	@echo "Docker 이미지 빌드 중..."
	@$(COMPOSE_CMD) build --no-cache

up:
	@echo "컨테이너 시작 중..."
	@$(COMPOSE_CMD) up -d
	@sleep 3
	@echo "✅ 서비스가 시작되었습니다!"
	@echo "웹: http://localhost:$${WEB_PORT}"
	@echo "Admin: http://localhost:$${WEB_PORT}/admin"

down:
	@echo "컨테이너 중지 중..."
	@$(COMPOSE_CMD) down

restart:
	@echo "컨테이너 재시작 중..."
	@$(COMPOSE_CMD) restart

logs:
	@$(COMPOSE_CMD) logs -f

shell:
	@echo "Django Shell 접속 중..."
	@$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$${PROJECT_NAME} && python manage.py shell"

bash:
	@$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$${PROJECT_NAME} && bash"

migrate:
	@echo "마이그레이션 실행 중..."
	@$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$${PROJECT_NAME} && python manage.py makemigrations && python manage.py migrate"

createsuperuser:
	@echo "슈퍼유저 생성 중..."
	@$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$${PROJECT_NAME} && python manage.py createsuperuser"

collectstatic:
	@echo "Static 파일 수집 중..."
	@$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$${PROJECT_NAME} && python manage.py collectstatic --noinput"

clean:
	@echo "⚠️  경고: 모든 컨테이너, 볼륨이 제거됩니다!"
	@read -p "정말 계속하시겠습니까? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@$(COMPOSE_CMD) down -v
	@echo "✅ 정리 완료"
EOF

# 확실하게 TAB 문자로 변환 (공백 4개 또는 8개를 TAB으로)
perl -i -pe 's/^(    )/\t/g' Makefile

success "Makefile 생성 완료 (TAB 문자 변환 완료)"

# CLAUDE.md 파일 생성
log "CLAUDE.md 파일 생성 중..."

# 현재 디렉토리의 절대 경로 저장
PROJECT_ABSOLUTE_PATH=$(pwd)

cat > src/CLAUDE.md << EOF
# Django 프로젝트 개발 가이드

## 👋 인사말 규칙
- **호칭**: 사용자를 항상 "제로님"으로 호칭
- **언어**: 모든 대화는 한국어로 진행
- **역할**: Django 프레임워크 프론트엔드 및 백엔드 전문 개발자

## 🏗️ 시스템 아키텍처

### 기술 스택
- **Backend**: Django $DJANGO_VERSION (MVT 패턴 - 전통적인 Django CRUD 방식)
- **Frontend**: HTML5, CSS3, jQuery 3.6+, AJAX (jQuery.ajax()만 사용)
- **Database**: MariaDB 10.11 (UTF8MB4)
- **Web Server**: Nginx
- **Container**: Docker Compose (django, mariadb, nginx)
- **Python**: $PYTHON_VERSION
- **CSS Framework**: Bootstrap 5
- **진행률 표시**: Bootstrap Progress Bar (필수)

### ✅ 허용된 기술
- Django Templates (서버사이드 렌더링)
- Django Forms / ModelForm
- Django 내장 인증 시스템 (django.contrib.auth)
- jQuery.ajax() (비동기 통신)
- Bootstrap 5 컴포넌트

### ❌ 절대 금지된 기술
- **HTMX** (절대 사용 금지 - jQuery AJAX만 사용)
- REST API Framework (DRF)
- React, Vue, Angular 등 SPA 프레임워크
- Redis, Celery, RabbitMQ 등 메시지 큐
- WebSocket, Server-Sent Events
- Chart.js (Bootstrap 컴포넌트로 대체)
- OAuth, JWT 등 외부 인증
- NoSQL 데이터베이스
- 마이크로서비스 아키텍처

## 📁 프로젝트 구조

\`\`\`
$PROJECT_ABSOLUTE_PATH/src/
├── config/
│   ├── settings.py              # 시스템 설정
│   └── urls.py                  # 루트 URL 설정
│
├── apps/                        # Django 앱 디렉토리 (startapp 메인 위치)
│   └── *****/                   # 앱이 생성될 디렉토리
│
├── static/
│   ├── css/
│   │   └── common.css           # 전역 스타일
│   ├── js/
│   │   ├── common.js            # 공통 함수
│   │   └── modal.js             # 공통 모달/토스트 구현
│   └── images/
│
└── templates/
    └── base.html                # 기본 템플릿
\`\`\`

## 🎨 공통 UI 컴포넌트

### 모달 및 토스트 메시지
- **위치**: \`/static/js/modal.js\`, \`/static/js/modal-state-manager.js\`
- **자동 로드**: \`base.html\`에 포함
- **사용법**: 모든 CRUD 작업에서 공통 모달/토스트 사용
- **기본 alert() 대체**: 화면 중앙 토스트 메시지로 구현

### UX 원칙 (중요!)
1. **단일 알림 원칙**: 로딩 모달이 표시 중일 때는 토스트 메시지 억제
2. **뒤로가기 처리**: 브라우저 뒤로가기 시 모든 모달 자동 정리
3. **계층 우선순위**: 로딩 모달 > 일반 모달 > 토스트 메시지
4. **중복 방지**: 동일한 메시지는 큐에 중복 저장하지 않음

### 사용 가능한 모달 함수
1. \`showDetailModal()\` - 상세 정보 표시
2. \`showEditModal()\` - 수정 폼
3. \`showCreateModal()\` - 생성 폼
4. \`showDeleteModal()\` - 삭제 확인
5. \`showCustomModal()\` - 커스텀 모달
6. \`showLoading()\` / \`hideLoading()\` - 로딩 모달 (자동 토스트 억제)

---

## ⚠️ 중첩 모달 문제 해결 (중요!)

### 문제 정의
편집 모달 내에서 저장 버튼 클릭 → 로딩 모달 표시 → AJAX 성공 후 로딩 모달이 사라지지 않는 현상

**증상**:
- "저장 중..." 로딩 모달이 화면에 계속 남아있음
- \`hideLoading()\` 호출해도 모달이 사라지지 않음
- 사용자 인터랙션 차단 (화면 전체가 블록됨)

### 근본 원인
1. **Bootstrap Modal API 한계**: \`hide()\`만으로는 중첩 모달 환경에서 DOM 완전 제거 불가
2. **백드롭 누적**: 각 모달이 생성한 backdrop 요소가 제거되지 않고 누적
3. **모달 닫기 순서**: 부모-자식 모달 관계에서 닫기 순서 중요 (내부 먼저 → 외부 나중)
4. **포커스 문제**: 자식 요소에 포커스가 남아있는 상태에서 모달 닫으면 aria-hidden 경고

### 4가지 핵심 해결책

#### 1. DOM 완전 제거 (\`dispose() + remove()\`)
\`\`\`javascript
// ❌ 잘못된 방법 (hide만 사용)
modalInstance.hide();  // DOM에 남아있음

// ✅ 올바른 방법 (완전 제거)
modalInstance.dispose();     // Bootstrap 인스턴스 완전 파괴
\$loadingModal.remove();      // DOM에서 완전 삭제 (not hide!)
\`\`\`

#### 2. 역순 닫기 (내부 → 외부)
\`\`\`javascript
// ✅ 올바른 순서
success: function(response) {
    // 1. 로딩 모달 먼저 제거 (내부)
    hideLoading();

    // 2. 지연 후 편집 모달 닫기 (외부)
    setTimeout(function() {
        instance.hide();  // 편집 모달 닫기
    }, 300);
}
\`\`\`

#### 3. 백드롭 명시적 제거
\`\`\`javascript
// 로딩 모달의 백드롭 제거 (마지막 백드롭)
\$('.modal-backdrop').last().remove();

// Body 정리 (다른 모달 없을 때만)
if (\$('.modal.show').length === 0) {
    \$('body').removeClass('modal-open');
    \$('body').css('padding-right', '');
    \$('body').css('overflow', '');
    \$('.modal-backdrop').remove();  // 모든 백드롭 제거
}
\`\`\`

#### 4. 포커스 해제 (aria-hidden 경고 방지)
\`\`\`javascript
// 모달 닫기 전에 포커스 해제
\$modal.find(':focus').blur();
instance.hide();
\`\`\`

### 완전한 hideLoading() 구현

\`\`\`javascript
window.hideLoading = function() {
    var \$loadingModal = \$('#loadingModal');

    // 1. Bootstrap 인스턴스 제거
    if (\$loadingModal.length > 0) {
        var modalInstance = bootstrap.Modal.getInstance(\$loadingModal[0]);
        if (modalInstance) {
            modalInstance.hide();
            modalInstance.dispose();  // 🔑 핵심: 인스턴스 완전 파괴
        }
    }

    // 2. DOM 완전 제거
    \$loadingModal.remove();  // 🔑 핵심: hide()가 아닌 remove()

    // 3. 백드롭 제거
    \$('.modal-backdrop').last().remove();  // 🔑 핵심: 명시적 제거

    // 4. Body 정리 (다른 모달 확인)
    setTimeout(function() {
        if (\$('.modal.show').length === 0) {
            \$('body').removeClass('modal-open');
            \$('body').css('padding-right', '');
            \$('body').css('overflow', '');
        }
    }, 100);

    ModalStateManager.setLoadingState(false);
};
\`\`\`

### AJAX Success 패턴 (편집 모달에서 사용)

\`\`\`javascript
\$('.btn-save').on('click', function() {
    var data = \$('#form').serializeArray();

    showLoading('저장 중...');

    \$.ajax({
        url: '/api/update/',
        method: 'POST',
        data: data,
        success: function(response) {
            // 1. 로딩 모달 먼저 제거
            hideLoading();

            // 2. 300ms 지연 후 편집 모달 닫기
            setTimeout(function() {
                // 포커스 해제 (aria-hidden 경고 방지)
                \$modal.find(':focus').blur();

                // 편집 모달 닫기
                instance.hide();

                // UI 업데이트 (예: 버튼 색상 변경)
                \$btn.removeClass('btn-secondary').addClass('btn-success');
            }, 300);
        },
        error: function() {
            hideLoading();
            showError('저장 실패!');
        }
    });
});
\`\`\`

### 체크리스트

중첩 모달 구현 시 반드시 확인:
- [ ] \`hideLoading()\`에서 \`dispose()\` + \`remove()\` 사용
- [ ] 로딩 모달 먼저 제거, 편집 모달은 나중에 (역순)
- [ ] 백드롭 명시적 제거 (\`.modal-backdrop.last().remove()\`)
- [ ] 모달 닫기 전 포커스 해제 (\`\$modal.find(':focus').blur()\`)
- [ ] Body 정리 시 다른 모달 존재 여부 확인
- [ ] 300ms 지연으로 DOM 정리 시간 확보

---

## 🌐 접속 정보
- **웹 포트**: $WEB_PORT
- **DB 포트**: $DB_PORT
- **메인 페이지**: http://localhost:$WEB_PORT/
- **관리자 페이지**: http://localhost:$WEB_PORT/admin/

## 🗄️ 데이터베이스 접속 정보
- **호스트**: localhost (Docker 외부) / db (Docker 내부)
- **포트**: $DB_PORT
- **데이터베이스명**: $DB_NAME
- **사용자명**: $DB_USER
- **비밀번호**: $DB_PASS
- **루트 비밀번호**: $MYSQL_ROOT_PASSWORD

### Docker MySQL 직접 접속 명령어
\`\`\`bash
# Docker 컨테이너 내부에서 MySQL 접속
docker compose exec db mysql -u$DB_USER -p'$DB_PASS' $DB_NAME

# 테이블 목록 확인
docker compose exec db mysql -u$DB_USER -p'$DB_PASS' $DB_NAME -e "SHOW TABLES;"

# 외부에서 MySQL 접속 (포트 $DB_PORT)
mysql -h 127.0.0.1 -P $DB_PORT -u$DB_USER -p'$DB_PASS' $DB_NAME
\`\`\`

## 🐳 Docker 운영 규칙
- **코드 수정 시**: 템플릿이나 백엔드 코드 변경 후 반드시 Docker 재시작
- **재시작 명령어**: \`docker compose restart\`
- **Python 가상환경**: Docker 사용으로 불필요

## 💻 개발 규칙

### 1. MVT 패턴 준수
- Model: 데이터베이스 구조 정의
- View: 비즈니스 로직 처리 (함수 기반 뷰 또는 클래스 기반 뷰)
- Template: Django 템플릿 엔진으로 렌더링

### 2. AJAX 통신
\`\`\`javascript
// jQuery.ajax() 사용 예시
$.ajax({
    url: '/api/endpoint/',
    method: 'POST',
    data: {
        csrfmiddlewaretoken: \$('[name=csrfmiddlewaretoken]').val(),
        // 데이터
    },
    success: function(response) {
        // 성공 처리
    },
    error: function(xhr, status, error) {
        // 에러 처리
    }
});
\`\`\`

### 3. Form 처리
- Django Forms 또는 ModelForm 사용
- CSRF 토큰 필수 포함
- 서버사이드 유효성 검증

### 4. 템플릿 상속
- 모든 페이지는 \`base.html\` 상속
- Bootstrap 5 클래스 활용
- jQuery는 base.html에서 로드

### 5. 데이터베이스
- MariaDB UTF8MB4 인코딩
- Django ORM 사용
- Raw SQL 최소화

## 📝 코딩 컨벤션
- Python: PEP 8 준수
- JavaScript: jQuery 패턴 준수
- HTML: Django 템플릿 태그 활용
- CSS: Bootstrap 5 우선, 커스텀은 common.css에 작성

## ⚠️ 주의사항
1. **HTMX 절대 사용 금지** - jQuery AJAX만 사용
2. API 엔드포인트는 Django 뷰로 구현 (DRF 사용 금지)
3. 모든 비동기 처리는 jQuery.ajax() 사용
4. 진행률 표시는 Bootstrap Progress Bar 필수
5. 차트는 Bootstrap 컴포넌트로 대체 (Chart.js 금지)

## 🔄 작업 플로우
1. 요구사항 분석
2. Django 앱 생성 (\`python manage.py startapp\`)
3. Model 설계 및 마이그레이션
4. View 로직 구현
5. Template 작성 (base.html 상속)
6. Static 파일 추가 (JS/CSS)
7. Docker 재시작 및 테스트
8. **Playwright로 자동 브라우저 테스트 실행** (필수)

## 🌿 Git 브랜치 전략 (필수)

### 브랜치 구조
\`\`\`
main (운영 서버)
  └── develop (개발 통합)
        ├── feature/feature1 
        ├── feature/feature2 
        └── feature/feature3 
\`\`\`

### 개발자 워크플로우
\`\`\`bash
# 1. develop 브랜치로 이동
git checkout develop

# 2. 최신 상태로 업데이트
git pull origin develop

# 3. 자신의 feature 브랜치 생성 (짧고 명확하게)
git checkout -b feature/feature1

# 4. 작업 & 커밋
git add .
git commit -m "feat: 기능 설명"

# 5. GitHub에 푸시
git push origin feature/feature1

# 6. GitHub에서 Pull Request 생성
# base: develop ← feature/자기브랜치
\`\`\`

### 커밋 메시지 규칙
- **feat**: 새로운 기능 추가
- **fix**: 버그 수정
- **docs**: 문서 수정
- **style**: 코드 포맷팅
- **refactor**: 코드 리팩토링
- **test**: 테스트 코드 추가
- **chore**: 빌드 업무 수정

## 🧪 자동화 테스트 (Playwright)

### 테스트 환경
- **테스트 도구**: Playwright 1.55.0 (설치됨)
- **브라우저**: Chromium (headless/headed 모드)
- **테스트 서버**: http://localhost:$WEB_PORT/

### 테스트 실행 규칙
**모든 기능 개발 완료 후 반드시 Playwright로 자동 테스트를 실행해야 함**

### 테스트 범위
1. **페이지 로딩 테스트**: 모든 페이지가 정상 로드되는지 확인
2. **CRUD 테스트**: Create, Read, Update, Delete 기능 검증
3. **AJAX 테스트**: jQuery.ajax() 비동기 통신 검증
4. **UI 컴포넌트 테스트**: 모달, 토스트 메시지 동작 확인
5. **폼 유효성 테스트**: 입력 폼 검증 및 CSRF 토큰 확인
6. **반응형 테스트**: 모바일/태블릿/데스크톱 뷰포트 검증

### 중요 체크리스트
- [ ] 모든 페이지 접근 가능 확인
- [ ] CRUD 작업 정상 동작 확인
- [ ] jQuery AJAX 통신 성공 확인
- [ ] 모달/토스트 메시지 표시 확인
- [ ] Bootstrap 컴포넌트 렌더링 확인
- [ ] CSRF 보호 동작 확인
- [ ] 반응형 디자인 확인

---

**이 문서는 모든 Claude Code 세션에서 자동으로 참조되며, 프로젝트 개발 시 반드시 준수해야 할 가이드라인입니다.**
**특히 기능 개발 후에는 반드시 Playwright로 자동 테스트를 실행하여 품질을 보장해야 합니다.**
EOF

# 완료 메시지
success "======================================================="
success "     Django Docker 개발환경 설정 완료!"
success "======================================================="
echo ""
info "프로젝트 정보:"
echo "  - 프로젝트명: $PROJECT_NAME"
echo "  - 웹 포트: $WEB_PORT"
echo "  - DB 포트: $DB_PORT"
echo "  - Python: $PYTHON_VERSION"
echo "  - Django: $DJANGO_VERSION"
echo "  - 시스템: $SYSTEM"
echo ""

if [[ "$SYSTEM" == "WSL2" ]]; then
    info "WSL2 추가 설정:"
    echo "  1. ./optimize-wsl2.sh 실행 (권장)"
    echo "  2. Linux 파일시스템 사용 권장 (/home/...)"
    success "  3. Vim 한글 설정 완료!"
    echo ""
fi

warning "중요: 환경변수를 현재 셸에 로드하려면 다음 명령을 실행하세요:"
echo "  source load-env.sh"
echo ""
info "다음 명령어로 시작하세요:"
echo "  1. cd $PROJECT_NAME"
echo "  2. source load-env.sh   # 환경변수 로드"
echo "  3. make init        # 초기 설정 (빌드 + 실행 + 마이그레이션)"
echo "  4. make createsuperuser  # 관리자 계정 생성"
echo ""
info "주요 명령어:"
echo "  - make help        # 전체 명령어 도움말"
echo "  - make up          # 컨테이너 시작"
echo "  - make down        # 컨테이너 중지"
echo "  - make logs        # 로그 확인"
echo "  - make shell       # Django 셸"
echo "  - make migrate     # 마이그레이션"
echo ""
info "프로젝트 초기화 방법:"
echo "  - ./cleanup_project.sh            # 프로젝트 초기화 (대화형)"
echo "  - ./cleanup_project.sh $PROJECT_NAME  # 프로젝트 즉시 초기화"
echo ""

if [[ "$SYSTEM" == "WSL2" ]]; then
    if [[ -f ~/.vimrc ]] && grep -q "encoding=utf-8" ~/.vimrc; then
        success "Vim 한글 설정이 완료되었습니다."
    fi
fi

success "행운을 빕니다! 🚀"
success "CLAUDE.md 파일이 src/ 폴더에 생성되었습니다!"

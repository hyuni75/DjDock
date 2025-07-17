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

# 시스템 감지 (개선된 버전)
detect_system() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "WSL2"
    elif [[ -f /etc/centos-release ]]; then
        # CentOS 버전 확인
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
        
        # 한글 로케일 설정
        if ! locale -a | grep -q "ko_KR.utf8"; then
            warning "한글 로케일이 없습니다. 설치를 시작합니다..."
            sudo apt update -qq
            sudo apt install -y locales
            sudo locale-gen ko_KR.UTF-8
            sudo update-locale LANG=ko_KR.UTF-8
        fi
        
        # vim 한글 설정
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
        
        # 환경변수 설정 (.bashrc)
        if ! grep -q "export LANG=ko_KR.UTF-8" ~/.bashrc; then
            echo '' >> ~/.bashrc
            echo '# WSL2 한글 환경 설정' >> ~/.bashrc
            echo 'export LANG=ko_KR.UTF-8' >> ~/.bashrc
            echo 'export LC_ALL=ko_KR.UTF-8' >> ~/.bashrc
            info "한글 환경변수가 ~/.bashrc에 추가되었습니다."
        fi
        
        # 현재 세션에도 적용
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
        else
            warning "Make를 수동으로 설치해주세요."
            warning "Ubuntu/Debian: sudo apt install make"
            warning "CentOS/RHEL: sudo yum install make"
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
    
    # Docker 버전 확인 (CentOS 7에서 중요)
    local docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    info "Docker 버전: $docker_version"
    
    # CentOS 7에서 Docker 버전 체크
    if [[ "$SYSTEM" == "CentOS7" ]]; then
        local major_version=$(echo $docker_version | cut -d. -f1)
        if [ "$major_version" -lt 19 ]; then
            warning "Docker 버전이 19.03 미만입니다. 업그레이드를 권장합니다."
        fi
    fi
}

# Docker Compose 버전 확인
check_docker_compose() {
    COMPOSE_CMD=""
    
    # Docker Compose v2 확인 (우선순위)
    if docker compose version &> /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
        local version=$(docker compose version --short 2>/dev/null)
        info "Docker Compose v2 발견: $version (권장)"
    # Docker Compose v1 확인
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
        local version=$(docker-compose version --short 2>/dev/null)
        info "Docker Compose v1 발견: $version"
    fi
    
    if [[ -z "$COMPOSE_CMD" ]]; then
        error "Docker Compose가 설치되어 있지 않습니다."
    fi
}

# SELinux 체크 (CentOS/RHEL)
check_selinux() {
    if command -v getenforce &> /dev/null; then
        local status=$(getenforce)
        if [ "$status" = "Enforcing" ]; then
            warning "SELinux가 Enforcing 모드입니다."
            warning "Docker 볼륨 마운트 문제가 발생할 수 있습니다."
            info "자동으로 :Z 옵션을 추가하여 대응합니다."
            echo ""
        fi
    fi
}

echo "======================================================="
echo "     Django Docker Compose 개발환경 초기화"
echo "     최종 완성 버전 (2024-2025)"
echo "======================================================="

# 시스템 정보 출력
SYSTEM=$(detect_system)
info "시스템 감지: $SYSTEM"

# 시스템별 특별 처리
if [[ "$SYSTEM" == "CentOS7" ]]; then
    info "CentOS 7이 감지되었습니다."
    success "Docker 컨테이너는 최신 Python/Django 환경을 사용할 수 있습니다!"
    check_selinux
elif [[ "$SYSTEM" == "WSL2" ]]; then
    success "WSL2가 감지되었습니다. 최적의 성능을 제공합니다."
    setup_wsl2_environment
fi

# Make 설치 확인
check_and_install_make

# Docker 확인
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

# 개발 환경 선택 (CentOS 7도 모든 옵션 사용 가능)
echo ""
echo "개발 환경을 선택하세요:"
echo "1) 최신 환경 (Ubuntu 24.04 + Python 3.12 + Django 5.0) - 권장"
echo "2) 안정성 우선 (Ubuntu 22.04 + Python 3.11 + Django 4.2 LTS)"
echo "3) 호환성 우선 (Ubuntu 22.04 + Python 3.10 + Django 4.2 LTS)"
echo "4) 레거시 지원 (Ubuntu 20.04 + Python 3.8 + Django 3.2 LTS)"

if [[ "$SYSTEM" == "CentOS7" ]]; then
    echo ""
    info "CentOS 7에서도 모든 환경을 사용할 수 있습니다!"
fi

read -p "선택 (1-4, 기본값: 1): " ENV_CHOICE
ENV_CHOICE=${ENV_CHOICE:-1}

case $ENV_CHOICE in
    1)
        UBUNTU_VERSION="24.04"
        PYTHON_VERSION="3.12"
        DJANGO_VERSION="5.0"
        info "최신 환경 선택됨"
        ;;
    2)
        UBUNTU_VERSION="22.04"
        PYTHON_VERSION="3.11"
        DJANGO_VERSION="4.2"
        info "안정성 우선 환경 선택됨"
        ;;
    3)
        UBUNTU_VERSION="22.04"
        PYTHON_VERSION="3.10"
        DJANGO_VERSION="4.2"
        info "호환성 우선 환경 선택됨"
        ;;
    4)
        UBUNTU_VERSION="20.04"
        PYTHON_VERSION="3.8"
        DJANGO_VERSION="3.2"
        info "레거시 지원 환경 선택됨"
        ;;
    *)
        UBUNTU_VERSION="24.04"
        PYTHON_VERSION="3.12"
        DJANGO_VERSION="5.0"
        info "기본값: 최신 환경"
        ;;
esac

# 성능 설정
MAX_UPLOAD_SIZE="500M"
NGINX_TIMEOUT="300"
GUNICORN_TIMEOUT="300"

# CPU 코어 수에 따른 Worker 수 계산
CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
GUNICORN_WORKERS=$(( (2 * CPU_CORES) + 1 ))
if [ $GUNICORN_WORKERS -gt 8 ]; then
    GUNICORN_WORKERS=8
fi

log "프로젝트 디렉토리 생성 중..."
mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

# WSL 최적화 확인
if [[ "$SYSTEM" == "WSL2" ]]; then
    CURRENT_PATH=$(pwd)
    if [[ "$CURRENT_PATH" == /mnt/* ]]; then
        warning "Windows 파일시스템에서 작업 중입니다 (/mnt/...)"
        warning "성능을 위해 Linux 파일시스템 (/home/...) 사용을 권장합니다."
        read -p "계속하시겠습니까? (y/N): " CONTINUE
        if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
            exit 0
        fi
    fi
fi

# Docker 관련 디렉토리 구조 생성
mkdir -p docker/{nginx/sites-{available,enabled},django/scripts,mariadb}
mkdir -p src/{logs,media,run}
mkdir -p src/static/{css,js,images,mxgraph-master}
mkdir -p src/templates/{components,includes}
mkdir -p src/config/settings
mkdir -p src/apps

# .env 파일 생성 (한 줄로 된 SECRET_KEY 생성)
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
# .env 파일의 환경변수를 현재 셸에 로드
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo "환경변수가 로드되었습니다."
    echo "PROJECT_NAME: $PROJECT_NAME"
else
    echo ".env 파일을 찾을 수 없습니다."
fi
EOF
chmod +x load-env.sh

# docker-compose.yml 생성 (네트워크 이름 수정)
log "docker-compose.yml 생성 중..."

# CentOS 7용 볼륨 옵션 설정
if [[ "$SYSTEM" == "CentOS7" ]]; then
    VOLUME_OPTS=":Z"  # SELinux 레이블 추가
else
    VOLUME_OPTS=""
fi

# Docker Compose 버전에 따른 분기
if [[ "$COMPOSE_CMD" == "docker compose" ]]; then
    # Docker Compose v2용 (version 필드 없음)
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
EOF
else
    # Docker Compose v1용 (version 필드 포함)
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
EOF
fi

# 공통 부분 추가
cat >> docker-compose.yml << EOF

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
      - ./src:/var/www/html/\${PROJECT_NAME}${VOLUME_OPTS}
      - socket_volume:/var/www/html/\${PROJECT_NAME}/run
      - ./docker/django/scripts:/scripts:ro${VOLUME_OPTS}
EOF

# WSL2 성능 최적화 추가
if [[ "$SYSTEM" == "WSL2" ]]; then
    cat >> docker-compose.yml << 'EOF'
      # WSL2 성능 최적화
      - type: tmpfs
        target: /tmp
        tmpfs:
          size: 1G
EOF
fi

cat >> docker-compose.yml << EOF
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

# Dockerfile 생성 (Python 버전별 최적화)
log "Dockerfile 생성 중..."
cat > docker/django/Dockerfile << 'EOF'
# Ubuntu 버전별 이미지 선택
ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION} AS base

# 빌드 인자
ARG PYTHON_VERSION=3.12
ARG PROJECT_NAME

# 환경 변수 설정
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=utf-8 \
    TZ=Asia/Seoul \
    LANG=ko_KR.UTF-8 \
    LC_ALL=ko_KR.UTF-8 \
    LANGUAGE=ko_KR:ko:en_US:en

# 시스템 패키지 설치 및 Python 설치
RUN apt-get update && apt-get install -y \
    # 기본 도구
    software-properties-common \
    build-essential \
    pkg-config \
    curl \
    wget \
    vim \
    # Python 설치
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-dev \
    python${PYTHON_VERSION}-venv \
    python3-pip \
    # MySQL/MariaDB 클라이언트
    default-libmysqlclient-dev \
    mariadb-client \
    # 네트워크 도구
    netcat-openbsd \
    # 로케일
    locales \
    # 폰트 (한글 지원)
    fonts-nanum \
    fontconfig \
    # 문서 처리
    wkhtmltopdf \
    # 시간대
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Python 기본 버전 설정
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python${PYTHON_VERSION} 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_VERSION} 1

# 한글 로케일 생성 및 설정
RUN sed -i '/ko_KR.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen ko_KR.UTF-8 && \
    update-locale LANG=ko_KR.UTF-8 LC_ALL=ko_KR.UTF-8

# 타임존 설정
RUN ln -snf /usr/share/zoneinfo/Asia/Seoul /etc/localtime && \
    echo "Asia/Seoul" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

# 작업 디렉토리 설정
WORKDIR /var/www/html/${PROJECT_NAME}

# 가상환경 생성 및 활성화
RUN python${PYTHON_VERSION} -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# pip 업그레이드 및 필수 패키지 설치
COPY requirements.txt /tmp/
RUN pip install --upgrade pip setuptools wheel && \
    pip install -r /tmp/requirements.txt

# 폰트 캐시 갱신
RUN fc-cache -fv

# 사용자 생성 (선택적)
RUN useradd -ms /bin/bash django

EXPOSE 8000
EOF

# requirements.txt 생성 (Python 버전별 최적화)
log "requirements.txt 생성 중..."

# 모든 Python 버전용 통합 requirements.txt
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

# Async Support (Django 5.0+)
EOF

if [[ "$DJANGO_VERSION" == "5.0" ]]; then
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
# 문자셋 설정
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
skip-character-set-client-handshake

# 타임존
default-time-zone = '+9:00'

# 연결 및 성능
max_connections = 200
max_allowed_packet = 512M
innodb_buffer_pool_size = 512M
innodb_log_file_size = 128M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT

# 쿼리 캐시 (MariaDB 10.6)
query_cache_type = 1
query_cache_size = 32M

# 바인딩
bind-address = 0.0.0.0

# 느린 쿼리 로그
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2

# JSON 지원 (MariaDB 10.6)
# JSON 테이블 함수 활성화됨
EOF

# MariaDB 초기화 SQL
cat > docker/mariadb/init.sql << EOF
-- 데이터베이스 문자셋 확인 및 설정
ALTER DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 사용자 권한 재설정
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

-- 타임존 설정 확인
SELECT @@global.time_zone, @@session.time_zone;

-- 성능 관련 변수 확인
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

    # 문자셋 설정
    charset utf-8;
    charset_types text/plain text/css text/xml text/javascript 
                   application/javascript application/json application/xml+rss;

    # 로그 포맷
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';

    access_log /var/log/nginx/access.log main;

    # 기본 설정
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 300s;
    keepalive_requests 100;
    reset_timedout_connection on;

    # 파일 크기 제한
    client_max_body_size 500M;
    client_body_buffer_size 128k;
    client_body_temp_path /tmp/nginx_client_temp 1 2;

    # 버퍼 설정
    proxy_buffer_size 8k;
    proxy_buffers 8 8k;
    proxy_busy_buffers_size 16k;

    # 압축
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript 
               application/javascript application/json application/xml+rss
               application/x-font-ttf font/opentype image/svg+xml;

    # 보안 헤더
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # 서버 토큰 숨기기
    server_tokens off;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Nginx 사이트 설정
cat > docker/nginx/sites-enabled/$PROJECT_NAME << EOF
# Unix 소켓을 사용한 업스트림 설정
upstream ${PROJECT_NAME}_backend {
    server unix:/var/www/html/$PROJECT_NAME/run/$PROJECT_NAME.sock fail_timeout=0;
    keepalive 32;
}

server {
    listen 80 default_server;
    server_name _;
    charset utf-8;

    # 로그
    access_log /var/log/nginx/${PROJECT_NAME}_access.log main;
    error_log /var/log/nginx/${PROJECT_NAME}_error.log;

    # 파일 업로드 크기
    client_max_body_size $MAX_UPLOAD_SIZE;

    # 정적 파일 캐싱
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
        
        # Unix 소켓 연결
        proxy_pass http://${PROJECT_NAME}_backend;
        
        # 타임아웃 설정
        proxy_connect_timeout ${NGINX_TIMEOUT}s;
        proxy_send_timeout ${NGINX_TIMEOUT}s;
        proxy_read_timeout ${NGINX_TIMEOUT}s;
        
        # Keep-alive 설정
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    # 헬스체크 엔드포인트
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

# 한글 환경 설정
export LANG=ko_KR.UTF-8
export LC_ALL=ko_KR.UTF-8
export PYTHONIOENCODING=utf-8

# 색상 정의
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

# 데이터베이스 연결 대기 (최대 30초)
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

# Django 프로젝트가 없으면 생성
if [ ! -f "manage.py" ]; then
    echo "Django 프로젝트 생성 중..."
    django-admin startproject config .
    
    # secrets.json 생성
    python /scripts/create_secrets.py
    
    # settings.py 교체
    cp /scripts/settings.py config/settings.py
    
    # urls.py 교체
    cp /scripts/urls.py config/urls.py
    
    # __init__.py 설정
    cat > config/__init__.py << 'INIT'
# -*- coding: utf-8 -*-
import pymysql
pymysql.install_as_MySQLdb()

# 버전 정보
__version__ = '1.0.0'
INIT
    
    # 기본 앱 생성
    python manage.py startapp main
    
    # main 앱의 기본 구조 생성
    mkdir -p main/templates/main
    mkdir -p main/static/main/{css,js,img}
    
    # main/apps.py 한글 설정
    cat > main/apps.py << 'APPS'
from django.apps import AppConfig

class MainConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'main'
    verbose_name = '메인'
APPS
fi

# 마이그레이션
echo "마이그레이션 실행 중..."
python manage.py makemigrations
python manage.py migrate

# static 파일 수집
echo "Static 파일 수집 중..."
python manage.py collectstatic --noinput

# 디렉토리 권한 설정
mkdir -p logs staticfiles media run
chmod -R 755 logs/ staticfiles/ media/ run/

# 소켓 파일 위치 확인
rm -f run/$PROJECT_NAME.sock

# Gunicorn 실행
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

# Django settings.py
cat > docker/django/scripts/settings.py << 'EOF'
# -*- coding: utf-8 -*-
"""
Django settings for config project.
최적화된 설정 - 대용량 파일, 한글, 성능 최적화 포함
"""

from pathlib import Path
import os
import json
from django.core.exceptions import ImproperlyConfigured

# Build paths
BASE_DIR = Path(__file__).resolve().parent.parent
LOGS_DIR = os.path.join(BASE_DIR, 'logs')
os.makedirs(LOGS_DIR, exist_ok=True)

# Secrets
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

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.environ.get('DEBUG', 'False') == 'True'

ALLOWED_HOSTS = ['*'] if DEBUG else os.environ.get('ALLOWED_HOSTS', '').split(',')

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.humanize',
    # Third party apps
    'rest_framework',
    'django_extensions',
    'corsheaders',
    # Local apps
    'main',
]

# Django 5.0의 경우 추가 앱
if os.environ.get('DJANGO_VERSION', '').startswith('5.'):
    INSTALLED_APPS += ['channels']

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

# Database - MariaDB 10.6 최적화
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

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
        'OPTIONS': {
            'min_length': 8,
        }
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# 국제화 설정
LANGUAGE_CODE = 'ko-kr'
TIME_ZONE = 'Asia/Seoul'
USE_I18N = True
USE_L10N = True
USE_TZ = True

# 언어 설정
LANGUAGES = [
    ('ko', '한국어'),
    ('en', 'English'),
]

LOCALE_PATHS = [
    os.path.join(BASE_DIR, 'locale'),
]

# Static files (CSS, JavaScript, Images)
STATIC_URL = '/static/'
STATICFILES_DIRS = [os.path.join(BASE_DIR, 'static')] if os.path.exists(os.path.join(BASE_DIR, 'static')) else []
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

# Media files
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# 파일 업로드 설정 (대용량 파일 지원)
DATA_UPLOAD_MAX_MEMORY_SIZE = 1024 * 1024 * 500  # 500MB
FILE_UPLOAD_MAX_MEMORY_SIZE = 1024 * 1024 * 100  # 100MB
DATA_UPLOAD_MAX_NUMBER_FIELDS = 10000
FILE_UPLOAD_TEMP_DIR = '/tmp'

# 청크 업로드 설정
FILE_UPLOAD_HANDLERS = [
    'django.core.files.uploadhandler.TemporaryFileUploadHandler',
]

# 기본 필드 타입
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# 세션 설정
SESSION_COOKIE_AGE = 86400 * 7  # 7일
SESSION_EXPIRE_AT_BROWSER_CLOSE = False
SESSION_SAVE_EVERY_REQUEST = True
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = 'Lax'
SESSION_ENGINE = 'django.contrib.sessions.backends.db'

# 캐시 설정 (Redis)
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'unique-snowflake',
    }
}

# CORS 설정
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    f"http://localhost:{os.environ.get('WEB_PORT', '8000')}",
]

# REST Framework 설정
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
    'DEFAULT_FILTER_BACKENDS': [
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ],
}

# 로깅 설정
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '[{levelname}] {asctime} [{name}:{lineno}] {message}',
            'style': '{',
            'datefmt': '%Y-%m-%d %H:%M:%S',
        },
        'simple': {
            'format': '{levelname} {message}',
            'style': '{',
        },
    },
    'filters': {
        'require_debug_false': {
            '()': 'django.utils.log.RequireDebugFalse',
        },
        'require_debug_true': {
            '()': 'django.utils.log.RequireDebugTrue',
        },
    },
    'handlers': {
        'console': {
            'level': 'INFO',
            'filters': ['require_debug_true'],
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
        'file': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': os.path.join(LOGS_DIR, 'django.log'),
            'formatter': 'verbose',
            'maxBytes': 1024 * 1024 * 10,  # 10MB
            'backupCount': 5,
            'encoding': 'utf-8',
        },
        'error_file': {
            'level': 'ERROR',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': os.path.join(LOGS_DIR, 'django_error.log'),
            'formatter': 'verbose',
            'maxBytes': 1024 * 1024 * 10,  # 10MB
            'backupCount': 5,
            'encoding': 'utf-8',
        },
    },
    'root': {
        'handlers': ['console', 'file'],
        'level': 'INFO',
    },
    'loggers': {
        'django': {
            'handlers': ['console', 'file'],
            'level': 'INFO',
            'propagate': False,
        },
        'django.request': {
            'handlers': ['error_file'],
            'level': 'ERROR',
            'propagate': False,
        },
        'django.db.backends': {
            'handlers': ['console'],
            'level': 'DEBUG' if DEBUG else 'INFO',
            'propagate': False,
        },
    },
}

# 개발 환경에서 디버그 툴바 설정
if DEBUG:
    INSTALLED_APPS += ['debug_toolbar', 'silk']
    MIDDLEWARE.insert(0, 'debug_toolbar.middleware.DebugToolbarMiddleware')
    MIDDLEWARE.append('silk.middleware.SilkyMiddleware')
    INTERNAL_IPS = ['127.0.0.1', 'localhost']
    
    # Docker 환경에서 디버그 툴바를 위한 설정
    import socket
    hostname, _, ips = socket.gethostbyname_ex(socket.gethostname())
    INTERNAL_IPS += [ip[:-1] + '1' for ip in ips]

# 보안 설정 (프로덕션용)
if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    X_FRAME_OPTIONS = 'DENY'
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True

# Email 설정
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend' if DEBUG else 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = os.environ.get('EMAIL_HOST', 'smtp.gmail.com')
EMAIL_PORT = os.environ.get('EMAIL_PORT', 587)
EMAIL_USE_TLS = True
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = get_secret('EMAIL_HOST_PASSWORD')

# 프로젝트 정보
PROJECT_NAME = os.environ.get('PROJECT_NAME', 'Django Project')
PROJECT_VERSION = '1.0.0'
EOF

# Django urls.py
cat > docker/django/scripts/urls.py << 'EOF'
# -*- coding: utf-8 -*-
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import TemplateView
from django.http import JsonResponse

def index(request):
    """메인 페이지 API"""
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
    """헬스체크 엔드포인트"""
    return JsonResponse({'status': 'healthy'})

urlpatterns = [
    path('', index, name='index'),
    path('health/', health_check, name='health_check'),
    path('admin/', admin.site.urls),
    path('api/', include('rest_framework.urls')),
    path('api/v1/', include('main.urls')),
]

# Static/Media 파일 서빙 (개발 환경)
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    
    # Debug Toolbar
    import debug_toolbar
    urlpatterns = [
        path('__debug__/', include(debug_toolbar.urls)),
        path('silk/', include('silk.urls', namespace='silk')),
    ] + urlpatterns

# Admin 사이트 설정
admin.site.site_header = f'{settings.PROJECT_NAME} 관리'
admin.site.site_title = f'{settings.PROJECT_NAME}'
admin.site.index_title = '관리 홈'
EOF

# main 앱 urls.py 생성
mkdir -p src/main
cat > src/main/urls.py << 'EOF'
# -*- coding: utf-8 -*-
from django.urls import path
from rest_framework.decorators import api_view
from rest_framework.response import Response

@api_view(['GET'])
def test_api(request):
    """테스트 API"""
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
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
.env
*.env

# Django
*.log
local_settings.py
db.sqlite3
media/
staticfiles/
secrets.json

# IDE
.vscode/
.idea/
*.swp
*.swo
.DS_Store

# Docker
mysql_data/

# 로그
logs/
*.log

# 임시 파일
*.tmp
*.bak
*~

# 테스트
.coverage
.pytest_cache/
htmlcov/

# 프로젝트별
src/secrets.json
src/logs/
src/media/
src/staticfiles/
EOF

# CentOS 7용 Docker 설정 스크립트
if [[ "$SYSTEM" == "CentOS7" ]]; then
    log "CentOS 7용 Docker 최적화 스크립트 생성 중..."
    cat > optimize-centos7.sh << 'EOF'
#!/bin/bash

# CentOS 7 Docker 최적화 스크립트
echo "CentOS 7 Docker 최적화 시작..."

# Docker daemon 설정
sudo tee /etc/docker/daemon.json > /dev/null << 'CONFIG'
{
  "storage-driver": "overlay2",
  "storage-opts": ["overlay2.override_kernel_check=true"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
CONFIG

# Docker 재시작
sudo systemctl restart docker

# 커널 파라미터 최적화
sudo tee -a /etc/sysctl.conf > /dev/null << 'SYSCTL'
# Docker 성능 최적화
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
vm.max_map_count = 262144
fs.file-max = 65536
SYSCTL

sudo sysctl -p

echo "CentOS 7 Docker 최적화 완료!"
echo ""
echo "추가 권장사항:"
echo "1. SELinux 임시 비활성화: sudo setenforce 0"
echo "2. SELinux 영구 비활성화: /etc/selinux/config 파일 수정"
echo "3. Docker CE 최신 버전 설치 확인"
echo ""
echo "참고: Docker 컨테이너는 최신 Ubuntu와 Python을 사용할 수 있습니다!"
EOF
    chmod +x optimize-centos7.sh
    info "CentOS 7 최적화를 위해 './optimize-centos7.sh' 실행을 권장합니다."
fi

# WSL2 최적화 스크립트
if [[ "$SYSTEM" == "WSL2" ]]; then
    log "WSL2 최적화 스크립트 생성 중..."
    cat > optimize-wsl2.sh << 'EOF'
#!/bin/bash

# WSL2 성능 최적화 스크립트
echo "WSL2 성능 최적화 시작..."

# .wslconfig 생성 (Windows 사용자 홈 디렉토리)
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

# Docker 데스크톱 없이 Docker 설치 확인
if ! command -v docker &> /dev/null; then
    echo "네이티브 Docker 설치를 권장합니다:"
    echo "curl -fsSL https://get.docker.com | sh"
    echo "sudo usermod -aG docker $USER"
fi

# 한글 환경 재확인
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

# cleanup 스크립트 생성 (하나의 범용 스크립트)
cat > cleanup_project.sh << 'EOF'
#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 프로젝트 이름 입력
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

# 1. 프로젝트 디렉토리 확인
if [ -d "$HOME/$PROJECT_NAME" ]; then
    cd "$HOME/$PROJECT_NAME"
    
    # Docker Compose 정리
    if [ -f "docker-compose.yml" ]; then
        echo -e "${BLUE}[INFO]${NC} Docker 컨테이너, 볼륨, 네트워크 제거 중..."
        
        # docker compose 또는 docker-compose 명령 확인
        if command -v docker-compose &> /dev/null; then
            COMPOSE_CMD="docker-compose"
        else
            COMPOSE_CMD="docker compose"
        fi
        
        # .env 파일 존재 확인
        if [ -f ".env" ]; then
            $COMPOSE_CMD --env-file .env down -v --remove-orphans 2>/dev/null || true
        else
            $COMPOSE_CMD down -v --remove-orphans 2>/dev/null || true
        fi
    fi
    
    # 상위 디렉토리로 이동
    cd ..
else
    echo -e "${YELLOW}[WARNING]${NC} 프로젝트 디렉토리가 없습니다: $HOME/$PROJECT_NAME"
fi

# 2. Docker 리소스 정리
echo -e "${BLUE}[INFO]${NC} Docker 리소스 정리 중..."

# 컨테이너 제거
CONTAINERS=$(docker ps -a -q --filter "name=${PROJECT_NAME}")
if [ ! -z "$CONTAINERS" ]; then
    echo "  - 컨테이너 제거 중..."
    docker rm -f $CONTAINERS 2>/dev/null || true
fi

# 이미지 제거
IMAGES=$(docker images -q "${PROJECT_NAME}*")
if [ ! -z "$IMAGES" ]; then
    echo "  - 이미지 제거 중..."
    docker rmi -f $IMAGES 2>/dev/null || true
fi

# 볼륨 제거
VOLUMES=$(docker volume ls -q | grep "${PROJECT_NAME}")
if [ ! -z "$VOLUMES" ]; then
    echo "  - 볼륨 제거 중..."
    docker volume rm $VOLUMES 2>/dev/null || true
fi

# 네트워크 제거
NETWORKS=$(docker network ls -q --filter "name=${PROJECT_NAME}")
if [ ! -z "$NETWORKS" ]; then
    echo "  - 네트워크 제거 중..."
    docker network rm $NETWORKS 2>/dev/null || true
fi

# 3. 프로젝트 디렉토리 삭제
if [ -d "$HOME/$PROJECT_NAME" ]; then
    echo -e "${BLUE}[INFO]${NC} 프로젝트 디렉토리 삭제 중..."
    rm -rf "$HOME/$PROJECT_NAME"
fi

# 4. 정리 결과 확인
echo -e "${BLUE}[INFO]${NC} 정리 결과 확인 중..."

# 남은 리소스 확인
REMAINING_CONTAINERS=$(docker ps -a | grep "$PROJECT_NAME" | wc -l)
REMAINING_IMAGES=$(docker images | grep "$PROJECT_NAME" | wc -l)
REMAINING_VOLUMES=$(docker volume ls | grep "$PROJECT_NAME" | wc -l)
REMAINING_NETWORKS=$(docker network ls | grep "$PROJECT_NAME" | wc -l)

if [ $REMAINING_CONTAINERS -eq 0 ] && [ $REMAINING_IMAGES -eq 0 ] && \
   [ $REMAINING_VOLUMES -eq 0 ] && [ $REMAINING_NETWORKS -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS]${NC} '$PROJECT_NAME' 프로젝트가 완전히 초기화되었습니다!"
else
    echo -e "${YELLOW}[WARNING]${NC} 일부 리소스가 남아있을 수 있습니다:"
    [ $REMAINING_CONTAINERS -gt 0 ] && echo "  - 컨테이너: $REMAINING_CONTAINERS개"
    [ $REMAINING_IMAGES -gt 0 ] && echo "  - 이미지: $REMAINING_IMAGES개"
    [ $REMAINING_VOLUMES -gt 0 ] && echo "  - 볼륨: $REMAINING_VOLUMES개"
    [ $REMAINING_NETWORKS -gt 0 ] && echo "  - 네트워크: $REMAINING_NETWORKS개"
fi

# 5. dangling 이미지 정리 (선택사항)
DANGLING_IMAGES=$(docker images -f "dangling=true" -q)
if [ ! -z "$DANGLING_IMAGES" ]; then
    echo -e "${BLUE}[INFO]${NC} dangling 이미지 정리 중..."
    docker rmi $DANGLING_IMAGES 2>/dev/null || true
fi

echo -e "${GREEN}[DONE]${NC} 초기화 완료!"
EOF

chmod +x cleanup_project.sh

# Makefile 생성 (환경변수 읽기 수정 및 --env-file 추가)
log "Makefile 생성 중..."
cat > Makefile << 'EOF'
# Docker Compose 명령 설정
COMPOSE_BASE := docker compose
COMPOSE_CMD := $(COMPOSE_BASE) --env-file .env

# 색상 정의
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
CYAN := \033[0;36m
NC := \033[0m

.PHONY: help build up down restart logs shell migrate test clean

help: ## 도움말 표시
	@echo "$(GREEN)Django Docker 개발환경 명령어$(NC)"
	@echo "======================================"
	@echo "시스템: $(CYAN)$(SYSTEM_TYPE)$(NC)"
	@echo "Docker Compose: $(CYAN)$(COMPOSE_BASE)$(NC)"
	@echo "Python: $(CYAN)$(PYTHON_VERSION)$(NC)"
	@echo "Django: $(CYAN)$(DJANGO_VERSION)$(NC)"
	@echo "======================================"	
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "$(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

build: ## Docker 이미지 빌드
	@echo "$(GREEN)Docker 이미지 빌드 중...$(NC)"
	$(COMPOSE_CMD) build --no-cache

build-fast: ## Docker 이미지 빠른 빌드 (캐시 사용)
	@echo "$(GREEN)Docker 이미지 빠른 빌드 중...$(NC)"
	$(COMPOSE_CMD) build

up: ## 컨테이너 실행
	@echo "$(GREEN)컨테이너 시작 중...$(NC)"
	$(COMPOSE_CMD) up -d
	@sleep 3
	@echo "$(GREEN)서비스가 시작되었습니다!$(NC)"
	@echo "웹: http://localhost:$(WEB_PORT)"
	@echo "Admin: http://localhost:$(WEB_PORT)/admin"
	@echo "API: http://localhost:$(WEB_PORT)/api/"

down: ## 컨테이너 중지
	@echo "$(YELLOW)컨테이너 중지 중...$(NC)"
	$(COMPOSE_CMD) down

restart: ## 컨테이너 재시작
	@echo "$(YELLOW)컨테이너 재시작 중...$(NC)"
	$(COMPOSE_CMD) restart

logs: ## 전체 로그 확인
	$(COMPOSE_CMD) logs -f

logs-web: ## Django 로그만 확인
	$(COMPOSE_CMD) logs -f web

logs-db: ## 데이터베이스 로그만 확인
	$(COMPOSE_CMD) logs -f db

logs-nginx: ## Nginx 로그만 확인
	$(COMPOSE_CMD) logs -f nginx

shell: ## Django Shell 접속
	@echo "$(GREEN)Django Shell 접속 중...$(NC)"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && python manage.py shell_plus --ipython || python manage.py shell"
	
bash: ## 웹 컨테이너 bash 접속
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && bash"
	
dbshell: ## MySQL Shell 접속
	$(COMPOSE_CMD) exec db mysql -u$(MYSQL_USER) -p$(MYSQL_PASSWORD) $(MYSQL_DATABASE)

migrate: ## 마이그레이션 실행
	@echo "$(GREEN)마이그레이션 실행 중...$(NC)"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && python manage.py makemigrations && python manage.py migrate"

makemigrations: ## 마이그레이션 파일 생성
	@echo "$(GREEN)마이그레이션 파일 생성 중...$(NC)"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && python manage.py makemigrations"

createsuperuser: ## 슈퍼유저 생성
	@echo "$(GREEN)슈퍼유저 생성 중...$(NC)"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && python manage.py createsuperuser"

collectstatic: ## Static 파일 수집
	@echo "$(GREEN)Static 파일 수집 중...$(NC)"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && python manage.py collectstatic --noinput"

test: ## 테스트 실행
	@echo "$(GREEN)테스트 실행 중...$(NC)"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && python manage.py test"

test-coverage: ## 테스트 커버리지 확인
	@echo "$(GREEN)테스트 커버리지 확인 중...$(NC)"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && coverage run --source='.' manage.py test && coverage report"

startapp: ## Django 앱 생성 (사용법: make startapp name=myapp)
	@if [ -z "$(name)" ]; then \
		echo "$(RED)오류: 앱 이름을 지정하세요. 사용법: make startapp name=myapp$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Django 앱 생성 중: $(name)$(NC)"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && python manage.py startapp $(name)"
	@echo "$(YELLOW)settings.py의 INSTALLED_APPS에 '$(name)'을 추가하는 것을 잊지 마세요!$(NC)"

pip-install: ## pip 패키지 설치 (사용법: make pip-install package=django-debug-toolbar)
	@if [ -z "$(package)" ]; then \
		echo "$(RED)오류: 패키지명을 지정하세요. 사용법: make pip-install package=package_name$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)$(package) 설치 중...$(NC)"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && pip install $(package)"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && pip freeze > /tmp/requirements.txt"
	docker cp $(PROJECT_NAME)_web:/tmp/requirements.txt ./requirements.txt
	@echo "$(YELLOW)requirements.txt가 업데이트되었습니다$(NC)"

pip-upgrade: ## 모든 패키지 업그레이드
	@echo "$(GREEN)패키지 업그레이드 중...$(NC)"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && pip list --outdated"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && pip install --upgrade pip setuptools wheel"

status: ## 컨테이너 상태 확인
	@echo "$(GREEN)컨테이너 상태:$(NC)"
	@$(COMPOSE_CMD) ps

ps: ## 실행중인 프로세스 확인
	@$(COMPOSE_CMD) exec web ps aux

check-korean: ## 한글 설정 확인
	@echo "$(GREEN)한글 설정 확인 중...$(NC)"
	@$(COMPOSE_CMD) exec web bash -c "locale | grep ko_KR"
	@$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && python -c \"print('한글 테스트: 가나다라마바사')\""
	@$(COMPOSE_CMD) exec db mysql -u$(MYSQL_USER) -p$(MYSQL_PASSWORD) -e "SHOW VARIABLES LIKE 'character%';" $(MYSQL_DATABASE)

check-performance: ## 성능 설정 확인
	@echo "$(GREEN)성능 설정 확인 중...$(NC)"
	@echo "Gunicorn Workers: $(GUNICORN_WORKERS)"
	@echo "Nginx Timeout: $(NGINX_TIMEOUT)s"
	@echo "Max Upload Size: $(MAX_UPLOAD_SIZE)"
	@$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && python -c \"import multiprocessing; print(f'CPU Cores: {multiprocessing.cpu_count()}')\""

clean: ## 모든 컨테이너, 볼륨, 네트워크 제거 (주의!)
	@echo "$(RED)경고: 모든 컨테이너, 볼륨, 네트워크가 제거됩니다!$(NC)"
	@read -p "정말 계속하시겠습니까? [y/N] " confirm && [ "$confirm" = "y" ] || exit 1
	$(COMPOSE_CMD) down -v
	@echo "$(GREEN)정리 완료$(NC)"

clean-logs: ## 로그 파일 정리
	@echo "$(YELLOW)로그 파일 정리 중...$(NC)"
	@find src/logs -name "*.log" -type f -delete 2>/dev/null || true
	@echo "$(GREEN)로그 정리 완료$(NC)"

backup-db: ## 데이터베이스 백업
	@echo "$(GREEN)데이터베이스 백업 중...$(NC)"
	@mkdir -p backups
	$(COMPOSE_CMD) exec db mysqldump -u$(MYSQL_USER) -p$(MYSQL_PASSWORD) $(MYSQL_DATABASE) | gzip > backups/backup_$(shell date +%Y%m%d_%H%M%S).sql.gz
	@echo "$(GREEN)백업 완료: backups/backup_$(shell date +%Y%m%d_%H%M%S).sql.gz$(NC)"

restore-db: ## 데이터베이스 복원 (사용법: make restore-db file=backup.sql.gz)
	@if [ -z "$(file)" ]; then \
		echo "$(RED)오류: 백업 파일을 지정하세요. 사용법: make restore-db file=backup.sql.gz$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)데이터베이스 복원 중...$(NC)"
	@gunzip -c $(file) | $(COMPOSE_CMD) exec -T db mysql -u$(MYSQL_USER) -p$(MYSQL_PASSWORD) $(MYSQL_DATABASE)
	@echo "$(GREEN)복원 완료$(NC)"

init: build up migrate collectstatic ## 초기 설정 (build + up + migrate + collectstatic)
	@echo "$(GREEN)초기 설정 완료!$(NC)"
	@echo "다음 단계: make createsuperuser"

dev: ## 개발 모드 실행 (로그 표시)
	@echo "$(GREEN)개발 모드로 실행 중...$(NC)"
	$(COMPOSE_CMD) up

prod: ## 프로덕션 모드 실행
	@echo "$(GREEN)프로덕션 모드로 실행 중...$(NC)"
	@sed -i 's/DEBUG=True/DEBUG=False/g' .env
	$(COMPOSE_CMD) up -d
	@echo "$(YELLOW)프로덕션 모드로 실행됨 (DEBUG=False)$(NC)"

dev-mode: ## 개발 모드로 전환
	@echo "$(GREEN)개발 모드로 전환 중...$(NC)"
	@sed -i 's/DEBUG=False/DEBUG=True/g' .env
	$(COMPOSE_CMD) restart web
	@echo "$(GREEN)개발 모드 활성화됨 (DEBUG=True)$(NC)"

check-security: ## 보안 체크
	@echo "$(GREEN)보안 체크 실행 중...$(NC)"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && python manage.py check --deploy"

show-urls: ## URL 패턴 확인
	@echo "$(GREEN)URL 패턴:$(NC)"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && python manage.py show_urls || echo 'django-extensions가 필요합니다'"

check-system: ## 시스템 호환성 체크
	@echo "$(GREEN)시스템 호환성 체크:$(NC)"
	@echo "OS Type: $(SYSTEM_TYPE)"
	@echo "Python Version: $(PYTHON_VERSION)"
	@echo "Django Version: $(DJANGO_VERSION)"
	@if [ "$(SYSTEM_TYPE)" = "CentOS7" ]; then \
		echo "$(YELLOW)CentOS 7 감지: SELinux 대응 및 Docker 최적화 적용$(NC)"; \
		echo "$(GREEN)Docker 컨테이너는 최신 Python/Django 사용 가능!$(NC)"; \
	elif [ "$(SYSTEM_TYPE)" = "WSL2" ]; then \
		echo "$(CYAN)WSL2 감지: 성능 최적화 적용됨$(NC)"; \
		echo "$(CYAN)Vim 한글 설정 완료$(NC)"; \
	else \
		echo "$(GREEN)표준 Ubuntu/Linux 환경$(NC)"; \
	fi

check-docker-version: ## Docker 버전 확인
	@echo "$(GREEN)Docker 환경 정보:$(NC)"
	@docker version --format 'Docker Engine: {{.Server.Version}}'
	@$(COMPOSE_BASE) version --short 2>/dev/null || echo "Docker Compose: Plugin mode"
	@echo ""
	@echo "$(GREEN)컨테이너 내부 환경:$(NC)"
	$(COMPOSE_CMD) exec web bash -c "cat /etc/os-release | grep PRETTY_NAME"
	$(COMPOSE_CMD) exec web bash -c "python --version"
	$(COMPOSE_CMD) exec web bash -c "cd /var/www/html/$(PROJECT_NAME) && django-admin --version"

env-check: ## 환경변수 확인
	@echo "$(GREEN)환경변수 확인:$(NC)"
	@echo "PROJECT_NAME: $(PROJECT_NAME)"
	@echo "WEB_PORT: $(WEB_PORT)"
	@echo "DB_PORT: $(DB_PORT)"
	@echo "COMPOSE_CMD: $(COMPOSE_CMD)"
	@echo "SYSTEM_TYPE: $(SYSTEM_TYPE)"

fix-permissions: ## 권한 문제 해결
	@echo "$(GREEN)파일 권한 수정 중...$(NC)"
	$(COMPOSE_CMD) exec web bash -c "chown -R django:django /var/www/html/$(PROJECT_NAME)"
	$(COMPOSE_CMD) exec web bash -c "chmod -R 755 /var/www/html/$(PROJECT_NAME)"
	@echo "$(GREEN)권한 수정 완료$(NC)"

check-compose-config: ## Docker Compose 설정 검증
	@echo "$(GREEN)Docker Compose 설정 검증 중...$(NC)"
	$(COMPOSE_CMD) config
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

# 시스템별 추가 안내
if [[ "$SYSTEM" == "CentOS7" ]]; then
    info "CentOS 7 추가 설정:"
    echo "  1. ./optimize-centos7.sh 실행 (권장)"
    echo "  2. SELinux 문제 시: sudo setenforce 0"
    success "  3. Docker 컨테이너는 최신 Python $PYTHON_VERSION 사용!"
    echo ""
elif [[ "$SYSTEM" == "WSL2" ]]; then
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
echo "  - make up          # 컨테이너 시작"
echo "  - make down        # 컨테이너 중지"
echo "  - make logs        # 로그 확인"
echo "  - make shell       # Django 쉘"
echo "  - make help        # 전체 명령어 도움말"
echo "  - make check-system # 시스템 호환성 체크"
echo "  - make check-docker-version # Docker/Python 버전 확인"
echo "  - make env-check   # 환경변수 확인"
echo "  - make check-compose-config # Docker Compose 설정 검증"
echo ""
info "프로젝트 초기화 방법:"
echo "  - ./cleanup_project.sh            # 프로젝트 초기화 (대화형)"
echo "  - ./cleanup_project.sh $PROJECT_NAME  # 프로젝트 즉시 초기화"
echo ""

# WSL2 한글 설정 재확인
if [[ "$SYSTEM" == "WSL2" ]]; then
    if [[ -f ~/.vimrc ]] && grep -q "encoding=utf-8" ~/.vimrc; then
        success "Vim 한글 설정이 완료되었습니다."
    else
        warning "Vim 한글 설정이 필요합니다. optimize-wsl2.sh를 실행하세요."
    fi
fi

success "행운을 빕니다! 🚀"

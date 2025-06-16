#!/usr/bin/env bash

##########################################################################
# Control Flags and Initialization
##########################################################################
set -e  # Exit on error
flag=$1
log_file="supabase_setup.log"

##########################################################################
# Global Variables and Colors
##########################################################################
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
BOLD="\033[1m"
NC="\033[0m"  # No Color

# Default values
DEFAULT_INSTALL_DIR="$HOME/DEPLOY/supabase"
COMPOSE_FILE="docker-compose.yml"
DEFAULT_STUDIO_PORT=3000
DEFAULT_KONG_HTTP_PORT=8000
DEFAULT_KONG_HTTPS_PORT=8443
DEFAULT_POSTGRES_PORT=5432
NETWORK_NAME="supabase-network"
ORIGIN_REPO="https://raw.githubusercontent.com/ekky1328"

##########################################################################
# Helper Functions
##########################################################################
log() {
    echo -e "${2:-$NC}$1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

error() {
    log "$1" $RED >&2
    exit 1
}

check_dependencies() {
    log "Checking for dependencies..." $BLUE
    
    MISSING_DEPS=0;

    if ! command -v docker &> /dev/null; then
        error "Docker not installed. Please install Docker: https://docs.docker.com/engine/install/"
        MISSING_DEPS=1;
    fi
    
    if docker ps 2>&1 | grep -q "error during connect"; then
        error "Docker is not running. Please start docker deamon and try again."
        MISSING_DEPS=1;
    fi

    if ! command -v curl &> /dev/null; then
        error "curl not installed. Please install curl to continue."
        MISSING_DEPS=1;
    fi
    
    if [ $MISSING_DEPS -eq 1 ]; then
        exit 1;
    fi

    log "All dependencies satisfied." $GREEN
}

generate_random_string() {
    cat /dev/urandom | tr -dc "a-zA-Z0-9-_" | fold -w 64 | head -n 1
}

display_logo() {
    echo -e "....................${GREEN}.${NC}....................";
    echo -e "..................${GREEN},ol${NC}....................";
    echo -e ".................${GREEN}:dxl${NC}....................";
    echo -e "...............${GREEN},lxxxl${NC}....................";
    echo -e "..............${GREEN}:dxxxxl${NC}....................";
    echo -e ".............${GREEN}lxxxxxxo${NC}....................";
    echo -e "...........${GREEN}:dxxxxxxxl${NC}....${GREEN}SUPABASE${NC}........";
    echo -e "..........${GREEN}lxxxxxxxxxl${NC}....................";
    echo -e "........${GREEN};oxxxxxxxxxxo${NC}....................";
    echo -e ".......${GREEN}ldxxxxxxxxxxxdc:ccclllooodddxxl${NC}...";
    echo -e ".....${GREEN};oxxxxxxxxxxxxxdc:cclllooodddddc${NC}....";
    echo -e "....${GREEN}cdxxxxxxxxxxxxxxdlccllloooodddo;${NC}.....";
    echo -e "...${GREEN}llllllllllllllllccclllooooddddc${NC}.......";
    echo -e ".....................${GREEN}:lllloooddo;${NC}........";
    echo -e ".....................${GREEN}:llloooodc${NC}..........";
    echo -e ".....................${GREEN}:llooooo;${NC}...........";
    echo -e ".....................${GREEN}:lloooc${NC}.............";
    echo -e ".....................${GREEN}:oool;${NC}..............";
    echo -e ".....................${GREEN}:ooc${NC}................";
    echo -e ".....................${GREEN}cl;${NC}.................";
    echo -e ".....................${GREEN},${NC}...................";
    echo -e "";
    log "Supabase Setup Assistant" $BOLD
}

prompt_user() {
    local prompt_text="$1"
    local required="$2"
    local is_password="$3"
    local default_value="${4:-}"
    local input=""
    
    local prompt_str
    if [[ -n "$default_value" ]]; then
        prompt_str="$prompt_text (Default: $default_value): "
    else
        prompt_str="$prompt_text: "
    fi
    
    if [[ "$is_password" == "true" ]]; then
        read -sp "$prompt_str" input
        echo ""
    else
        read -p "$prompt_str" input
    fi
    
    if [[ -z "$input" && -n "$default_value" ]]; then
        input="$default_value"
    fi
    
    if [[ -z "$input" && "$required" == "true" ]]; then
        while [[ -z "$input" ]]; do
            if [[ "$is_password" == "true" ]]; then
                read -sp "   Required field, please enter a value: " input
                echo ""
            else
                read -p "   Required field, please enter a value: " input
            fi
        done
    fi
    
    echo "$input"
}

##########################################################################
# Main Script Execution
##########################################################################
# Start logging
echo "" > "$log_file"
log "Starting Supabase setup script - $(date)" $BLUE

# Check dependencies
check_dependencies

# Display logo and welcome message
display_logo

log "Let's get started. We need a few details from you." $GREEN

##########################################################################
# Gather User Input
##########################################################################
SCRIPT_DIR=$(prompt_user "1. Enter an installation directory" "true" "false" "$DEFAULT_INSTALL_DIR")
mkdir -p "$SCRIPT_DIR" || error "Failed to create installation directory"

POSTGRES_PASSWORD=$(prompt_user "2. Enter a password for your Postgres Database (leave blank for auto-generate)" "false" "true")
if [ -z "$POSTGRES_PASSWORD" ]; then
    POSTGRES_PASSWORD=$(generate_random_string)
    log "Generated random Postgres password" $YELLOW
fi

JWT_SECRET=$(prompt_user "3. Enter a JWT Secret (leave blank for auto-generate)" "false" "true")
if [ -z "$JWT_SECRET" ]; then
    JWT_SECRET=$(generate_random_string)
    log "Generated random JWT Secret" $YELLOW
fi

domain=$(prompt_user "4. Enter the domain you will use to access Supabase Studio" "true" "false")

enable_email_signup=$(prompt_user "5. Do you wish to enable Email Signups? [y/n]" "true" "false" "n")

if [[ $enable_email_signup == "Y" || $enable_email_signup == "y" ]]; then
    ENABLE_EMAIL_SIGNUP=true
    
    ENABLE_EMAIL_AUTOCONFIRM=$(prompt_user "   Do you wish to enable Email Auto Confirmation? [y/n]" "false" "false" "n")
    if [[ "$ENABLE_EMAIL_AUTOCONFIRM" == "y" || "$ENABLE_EMAIL_AUTOCONFIRM" == "Y" ]]; then
        ENABLE_EMAIL_AUTOCONFIRM="true"
    else
        ENABLE_EMAIL_AUTOCONFIRM="false"
    fi
    
    SMTP_HOST=$(prompt_user "   Enter your SMTP Host" "true" "false")
    SMTP_PORT=$(prompt_user "   Enter your SMTP Port" "true" "false")
    SMTP_USER=$(prompt_user "   Enter your SMTP Username" "true" "false")
    SMTP_PASS=$(prompt_user "   Enter your SMTP Password" "true" "true")
    SMTP_SENDER_NAME=$(prompt_user "   Enter your SMTP Sender Name" "true" "false")
    SMTP_ADMIN_EMAIL="$SMTP_USER"
else
    ENABLE_EMAIL_SIGNUP=false
    ENABLE_EMAIL_AUTOCONFIRM=false
    SMTP_ADMIN_EMAIL="no-reply@example.com"
    SMTP_HOST="smtp.example.com"
    SMTP_PORT=587
    SMTP_USER="no-reply@example.com"
    SMTP_PASS="placeholder-password"
    SMTP_SENDER_NAME="Supabase"
fi

##########################################################################
# JWT Key Generation
##########################################################################
log "Generating JWT keys..." $BLUE

base64_encode() {
    declare input=${1:-$(</dev/stdin)}
    printf '%s' "${input}" | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'
}

json() {
    declare input=${1:-$(</dev/stdin)}
    printf '%s' "${input}"
}

hmacsha256_sign() {
    declare input=${1:-$(</dev/stdin)}
    printf '%s' "${input}" | openssl dgst -binary -sha256 -hmac "${JWT_SECRET}"
}

header='{"alg": "HS256","typ": "JWT"}'
anon_payload='{"role": "anon","iss": "supabase","iat": 1643806800,"exp": 1801573200}'
service_role_payload='{"role": "service_role","iss": "supabase","iat": 1643806800,"exp": 1801573200}'

header_base64=$(echo "${header}" | json | base64_encode)

anon_payload_base64=$(echo "${anon_payload}" | json | base64_encode)
anon_header_payload=$(echo "${header_base64}.${anon_payload_base64}")
anon_signature=$(echo "${anon_header_payload}" | hmacsha256_sign | base64_encode)

service_role_payload_base64=$(echo "${service_role_payload}" | json | base64_encode)
service_role_header_payload=$(echo "${header_base64}.${service_role_payload_base64}")
service_role_signature=$(echo "${service_role_header_payload}" | hmacsha256_sign | base64_encode)

ANON_KEY="${anon_header_payload}.${anon_signature}"
SERVICE_ROLE_KEY="${service_role_header_payload}.${service_role_signature}"

##########################################################################
# File Setup
##########################################################################
log "Setting up configuration files..." $BLUE

if [[ $flag == '--reset' ]]; then
    log "Resetting existing volumes..." $YELLOW
    rm -rf "${SCRIPT_DIR}/volumes" 2>/dev/null
fi

if [[ ! -d "${SCRIPT_DIR}/volumes/db" && ! -d "${SCRIPT_DIR}/volumes/api" ]]; then
    log "Creating directory structure..." $BLUE
    mkdir -p "${SCRIPT_DIR}/volumes/db/init" 2>/dev/null
    mkdir -p "${SCRIPT_DIR}/volumes/api" 2>/dev/null
    mkdir -p "${SCRIPT_DIR}/volumes/storage" 2>/dev/null
    
    log "Downloading configuration files..." $BLUE
    curl -s "${ORIGIN_REPO}/docker-cli-supabase/main/volumes/db/init/00-initial-schema.sql" > "${SCRIPT_DIR}/volumes/db/init/00-initial-schema.sql"
    curl -s "${ORIGIN_REPO}/docker-cli-supabase/main/volumes/db/init/01-auth-schema.sql" > "${SCRIPT_DIR}/volumes/db/init/01-auth-schema.sql"
    curl -s "${ORIGIN_REPO}/docker-cli-supabase/main/volumes/db/init/02-storage-schema.sql" > "${SCRIPT_DIR}/volumes/db/init/02-storage-schema.sql"
    curl -s "${ORIGIN_REPO}/docker-cli-supabase/main/volumes/db/init/03-post-setup.sql" > "${SCRIPT_DIR}/volumes/db/init/03-post-setup.sql"
    curl -s "${ORIGIN_REPO}/docker-cli-supabase/main/volumes/api/kong.yml" > "${SCRIPT_DIR}/volumes/api/kong.yml"
fi

# Update Kong configuration with JWT keys
sed -i "s/anon-role-replace/${ANON_KEY}/" "${SCRIPT_DIR}/volumes/api/kong.yml" 2>/dev/null
sed -i "s/service-role-replace/${SERVICE_ROLE_KEY}/" "${SCRIPT_DIR}/volumes/api/kong.yml" 2>/dev/null

##########################################################################
# Docker Containers Setup
##########################################################################
log "Setting up Docker containers..." $BLUE

# Reset if requested
if [[ $flag == '--reset' ]]; then
    log "Cleaning up existing containers..." $YELLOW
    
    # Stop and remove containers
    docker rm -f supabase-meta supabase-storage supabase-rest supabase-auth \
               supabase-studio supabase-realtime supabase-db supabase-kong 2>/dev/null
    
    # Remove network
    docker network rm $NETWORK_NAME 2>/dev/null
    
    log "Cleanup complete" $GREEN
fi

# Create network
log "Creating Docker network: $NETWORK_NAME..." $BLUE
docker network inspect $NETWORK_NAME &>/dev/null || docker network create $NETWORK_NAME &>/dev/null

# Setup PostgreSQL
log "Setting up PostgreSQL database..." $BLUE
docker run -d \
    --name=supabase-db \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_DB=supabase \
    -v ${SCRIPT_DIR}/volumes/db/data:/var/lib/postgresql/data \
    -v ${SCRIPT_DIR}/volumes/db/init:/docker-entrypoint-initdb.d \
    -p $DEFAULT_POSTGRES_PORT:5432 \
    --restart unless-stopped \
    --network $NETWORK_NAME \
    supabase/postgres:latest &>/dev/null || error "Failed to start PostgreSQL container"

log "Waiting for database initialization (this may take a few minutes)..." $YELLOW
sleep 30
for i in {1..9}; do
    log "Database initialization in progress... ($i/9)" $YELLOW
    sleep 10
done
log "Database initialization complete" $GREEN

# Setup Studio
log "Setting up Supabase Studio..." $BLUE
docker run -d \
    --name=supabase-studio \
    -e SUPABASE_URL="https://$domain" \
    -e STUDIO_PG_META_URL="http://supabase-meta:8080" \
    -e SUPABASE_ANON_KEY=$ANON_KEY \
    -e SUPABASE_SERVICE_KEY=$SERVICE_ROLE_KEY \
    -p $DEFAULT_STUDIO_PORT:3000 \
    --restart unless-stopped \
    --network $NETWORK_NAME \
    supabase/studio:latest &>/dev/null || error "Failed to start Studio container"

# Setup Kong API Gateway
log "Setting up Kong API Gateway..." $BLUE
docker run -d \
    --name=supabase-kong \
    -e KONG_DATABASE="off" \
    -e KONG_DECLARATIVE_CONFIG="/var/lib/kong/kong.yml" \
    -e KONG_DNS_ORDER="LAST,A,CNAME" \
    -e KONG_PLUGINS="request-transformer,cors,key-auth,acl" \
    -v ${SCRIPT_DIR}/volumes/api/kong.yml:/var/lib/kong/kong.yml \
    -p $DEFAULT_KONG_HTTP_PORT:8000 \
    -p $DEFAULT_KONG_HTTPS_PORT:8443 \
    --restart unless-stopped \
    --network $NETWORK_NAME \
    kong:latest &>/dev/null || error "Failed to start Kong container"

# Setup Auth Service
log "Setting up Authentication Service..." $BLUE
docker run -d \
    --name=supabase-auth \
    -e GOTRUE_API_HOST=0.0.0.0 \
    -e GOTRUE_API_PORT=9999 \
    -e GOTRUE_DB_DRIVER="postgres" \
    -e GOTRUE_DB_DATABASE_URL="postgres://postgres:$POSTGRES_PASSWORD@supabase-db:5432/supabase?search_path=auth" \
    -e GOTRUE_SITE_URL="https://$domain" \
    -e GOTRUE_DISABLE_SIGNUP=false \
    -e GOTRUE_JWT_SECRET=$JWT_SECRET \
    -e GOTRUE_JWT_EXP=3600 \
    -e GOTRUE_JWT_DEFAULT_GROUP_NAME="authenticated" \
    -e GOTRUE_EXTERNAL_EMAIL_ENABLED=$ENABLE_EMAIL_SIGNUP \
    -e GOTRUE_MAILER_AUTOCONFIRM=$ENABLE_EMAIL_AUTOCONFIRM \
    -e GOTRUE_SMTP_ADMIN_EMAIL=$SMTP_ADMIN_EMAIL \
    -e GOTRUE_SMTP_HOST=$SMTP_HOST \
    -e GOTRUE_SMTP_PORT=$SMTP_PORT \
    -e GOTRUE_SMTP_USER=$SMTP_USER \
    -e GOTRUE_SMTP_PASS=$SMTP_PASS \
    -e GOTRUE_SMTP_SENDER_NAME=$SMTP_SENDER_NAME \
    -e GOTRUE_MAILER_URLPATHS_INVITE="/auth/v1/verify" \
    -e GOTRUE_MAILER_URLPATHS_CONFIRMATION="/auth/v1/verify" \
    -e GOTRUE_MAILER_URLPATHS_RECOVERY="/auth/v1/verify" \
    -e GOTRUE_MAILER_URLPATHS_EMAIL_CHANGE="/auth/v1/verify" \
    -e GOTRUE_EXTERNAL_PHONE_ENABLED=false \
    -e GOTRUE_SMS_AUTOCONFIRM=false \
    --restart unless-stopped \
    --network $NETWORK_NAME \
    supabase/gotrue:latest &>/dev/null || error "Failed to start Auth container"

# Setup REST API
log "Setting up REST API..." $BLUE
docker run -d \
    --name=supabase-rest \
    -e PGRST_DB_URI="postgres://postgres:$POSTGRES_PASSWORD@supabase-db:5432/supabase" \
    -e PGRST_DB_SCHEMA="public,storage" \
    -e PGRST_DB_ANON_ROLE="anon" \
    -e PGRST_JWT_SECRET=$JWT_SECRET \
    -e PGRST_DB_USE_LEGACY_GUCS="false" \
    --restart unless-stopped \
    --network $NETWORK_NAME \
    postgrest/postgrest:latest &>/dev/null || error "Failed to start REST container"

# Setup Realtime
log "Setting up Realtime Service..." $BLUE
docker run -d \
    --name=supabase-realtime \
    -e DB_HOST="supabase-db" \
    -e DB_PORT=5432 \
    -e DB_NAME=supabase \
    -e DB_USER=postgres \
    -e DB_PASSWORD=$POSTGRES_PASSWORD \
    -e DB_SSL="false" \
    -e PORT=4000 \
    -e JWT_SECRET=$JWT_SECRET \
    -e REPLICATION_MODE="RLS" \
    -e REPLICATION_POLL_INTERVAL=100 \
    -e SECURE_CHANNELS="true" \
    -e SLOT_NAME="supabase_realtime_rls" \
    -e TEMPORARY_SLOT="true" \
    --restart unless-stopped \
    --network $NETWORK_NAME \
    supabase/realtime:latest &>/dev/null || error "Failed to start Realtime container"

log "Initializing Realtime service..." $YELLOW
sleep 10
docker exec supabase-realtime bash -c './prod/rel/realtime/bin/realtime eval Realtime.Release.migrate && ./prod/rel/realtime/bin/realtime start' &>/dev/null

# Setup Storage
log "Setting up Storage Service..." $BLUE
docker run -d \
    --name=supabase-storage \
    -e ANON_KEY=$ANON_KEY \
    -e SERVICE_KEY=$SERVICE_ROLE_KEY \
    -e POSTGREST_URL="http://supabase-rest:3000" \
    -e PGRST_JWT_SECRET=$JWT_SECRET \
    -e DATABASE_URL="postgres://postgres:$POSTGRES_PASSWORD@supabase-db:5432/supabase" \
    -e PGOPTIONS="-c search_path=storage,public" \
    -e FILE_SIZE_LIMIT=52428800 \
    -e STORAGE_BACKEND="file" \
    -e FILE_STORAGE_BACKEND_PATH="/var/lib/storage" \
    -e TENANT_ID="stub" \
    -e REGION="stub" \
    -e GLOBAL_S3_BUCKET="stub" \
    --restart unless-stopped \
    --network $NETWORK_NAME \
    -v ${SCRIPT_DIR}/volumes/storage:/var/lib/storage \
    supabase/storage-api:latest &>/dev/null || error "Failed to start Storage container"

# Setup Meta
log "Setting up Meta Service..." $BLUE
docker run -d \
    --name=supabase-meta \
    -e PG_META_PORT=8080 \
    -e PG_META_DB_HOST="supabase-db" \
    -e PG_META_DB_PASSWORD=$POSTGRES_PASSWORD \
    --restart unless-stopped \
    --network $NETWORK_NAME \
    supabase/postgres-meta:latest &>/dev/null || error "Failed to start Meta container"

##########################################################################
# Generate Docker Compose File
##########################################################################
log "Generating docker-compose.yml for future reference..." $BLUE

cat > "${SCRIPT_DIR}/${COMPOSE_FILE}" << EOF
version: '3'
services:
  db:
    image: supabase/postgres:latest
    container_name: supabase-db
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: $POSTGRES_PASSWORD
      POSTGRES_USER: postgres
      POSTGRES_DB: supabase
    volumes:
      - ./volumes/db/data:/var/lib/postgresql/data
      - ./volumes/db/init:/docker-entrypoint-initdb.d
    ports:
      - "$DEFAULT_POSTGRES_PORT:5432"
    networks:
      - supabase

  studio:
    image: supabase/studio:latest
    container_name: supabase-studio
    restart: unless-stopped
    environment:
      SUPABASE_URL: "https://$domain"
      STUDIO_PG_META_URL: "http://meta:8080"
      SUPABASE_ANON_KEY: $ANON_KEY
      SUPABASE_SERVICE_KEY: $SERVICE_ROLE_KEY
    ports:
      - "$DEFAULT_STUDIO_PORT:3000"
    networks:
      - supabase
    depends_on:
      - db
      - meta

  kong:
    image: kong:latest
    container_name: supabase-kong
    restart: unless-stopped
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: "/var/lib/kong/kong.yml"
      KONG_DNS_ORDER: "LAST,A,CNAME"
      KONG_PLUGINS: "request-transformer,cors,key-auth,acl"
    volumes:
      - ./volumes/api/kong.yml:/var/lib/kong/kong.yml
    ports:
      - "$DEFAULT_KONG_HTTP_PORT:8000"
      - "$DEFAULT_KONG_HTTPS_PORT:8443"
    networks:
      - supabase

  auth:
    image: supabase/gotrue:latest
    container_name: supabase-auth
    restart: unless-stopped
    environment:
      GOTRUE_API_HOST: 0.0.0.0
      GOTRUE_API_PORT: 9999
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_DATABASE_URL: "postgres://postgres:$POSTGRES_PASSWORD@db:5432/supabase?search_path=auth"
      GOTRUE_SITE_URL: "https://$domain"
      GOTRUE_DISABLE_SIGNUP: "false"
      GOTRUE_JWT_SECRET: $JWT_SECRET
      GOTRUE_JWT_EXP: 3600
      GOTRUE_JWT_DEFAULT_GROUP_NAME: "authenticated"
      GOTRUE_EXTERNAL_EMAIL_ENABLED: $ENABLE_EMAIL_SIGNUP
      GOTRUE_MAILER_AUTOCONFIRM: $ENABLE_EMAIL_AUTOCONFIRM
      GOTRUE_SMTP_ADMIN_EMAIL: $SMTP_ADMIN_EMAIL
      GOTRUE_SMTP_HOST: $SMTP_HOST
      GOTRUE_SMTP_PORT: $SMTP_PORT
      GOTRUE_SMTP_USER: $SMTP_USER
      GOTRUE_SMTP_PASS: $SMTP_PASS
      GOTRUE_SMTP_SENDER_NAME: $SMTP_SENDER_NAME
      GOTRUE_MAILER_URLPATHS_INVITE: "/auth/v1/verify"
      GOTRUE_MAILER_URLPATHS_CONFIRMATION: "/auth/v1/verify"
      GOTRUE_MAILER_URLPATHS_RECOVERY: "/auth/v1/verify"
      GOTRUE_MAILER_URLPATHS_EMAIL_CHANGE: "/auth/v1/verify"
      GOTRUE_EXTERNAL_PHONE_ENABLED: "false"
      GOTRUE_SMS_AUTOCONFIRM: "false"
    networks:
      - supabase
    depends_on:
      - db

  rest:
    image: postgrest/postgrest:latest
    container_name: supabase-rest
    restart: unless-stopped
    environment:
      PGRST_DB_URI: "postgres://postgres:$POSTGRES_PASSWORD@db:5432/supabase"
      PGRST_DB_SCHEMA: "public,storage"
      PGRST_DB_ANON_ROLE: "anon"
      PGRST_JWT_SECRET: $JWT_SECRET
      PGRST_DB_USE_LEGACY_GUCS: "false"
    networks:
      - supabase
    depends_on:
      - db

  realtime:
    image: supabase/realtime:latest
    container_name: supabase-realtime
    restart: unless-stopped
    environment:
      DB_HOST: db
      DB_PORT: 5432
      DB_NAME: supabase
      DB_USER: postgres
      DB_PASSWORD: $POSTGRES_PASSWORD
      DB_SSL: "false"
      PORT: 4000
      JWT_SECRET: $JWT_SECRET
      REPLICATION_MODE: "RLS"
      REPLICATION_POLL_INTERVAL: 100
      SECURE_CHANNELS: "true"
      SLOT_NAME: "supabase_realtime_rls"
      TEMPORARY_SLOT: "true"
    networks:
      - supabase
    depends_on:
      - db

  storage:
    image: supabase/storage-api:latest
    container_name: supabase-storage
    restart: unless-stopped
    environment:
      ANON_KEY: $ANON_KEY
      SERVICE_KEY: $SERVICE_ROLE_KEY
      POSTGREST_URL: "http://rest:3000"
      PGRST_JWT_SECRET: $JWT_SECRET
      DATABASE_URL: "postgres://postgres:$POSTGRES_PASSWORD@db:5432/supabase"
      PGOPTIONS: "-c search_path=storage,public"
      FILE_SIZE_LIMIT: 52428800
      STORAGE_BACKEND: "file"
      FILE_STORAGE_BACKEND_PATH: "/var/lib/storage"
      TENANT_ID: "stub"
      REGION: "stub"
      GLOBAL_S3_BUCKET: "stub"
    volumes:
      - ./volumes/storage:/var/lib/storage
    networks:
      - supabase
    depends_on:
      - db
      - rest

  meta:
    image: supabase/postgres-meta:latest
    container_name: supabase-meta
    restart: unless-stopped
    environment:
      PG_META_PORT: 8080
      PG_META_DB_HOST: db
      PG_META_DB_PASSWORD: $POSTGRES_PASSWORD
    networks:
      - supabase
    depends_on:
      - db

networks:
  supabase:
    name: $NETWORK_NAME
EOF

##########################################################################
# Final Output
##########################################################################
log "Setup complete! Here are your Supabase details:" $GREEN
echo ""
echo -e "---------------------------------------------------------------------------"
echo -e "${GREEN}SUCCESS: Your Supabase instance is now ready!${NC}"
echo -e "---------------------------------------------------------------------------"
echo -e "Supabase Studio URL:       https://$domain:$DEFAULT_STUDIO_PORT"
echo -e "REST API URL:              http://$domain:$DEFAULT_KONG_HTTP_PORT"
echo -e "PostgreSQL Connection:     postgresql://postgres:${POSTGRES_PASSWORD}@$domain:$DEFAULT_POSTGRES_PORT/supabase"
echo -e ""
echo -e "${BLUE}Important Credentials${NC}"
echo -e "---------------------------------------------------------------------------"
echo -e "Postgres Password:         ${POSTGRES_PASSWORD}"
echo -e "JWT Secret:                ${JWT_SECRET}"
echo -e "Anon Key:                  ${ANON_KEY}"
echo -e "Service Role Key:          ${SERVICE_ROLE_KEY}"
echo -e ""
echo -e "${YELLOW}A summary of this installation has been saved to:${NC}"
echo -e "$SCRIPT_DIR/supabase_credentials.txt"
echo -e "$SCRIPT_DIR/${COMPOSE_FILE}"
echo -e "---------------------------------------------------------------------------"

# Save credentials to a file
cat > "${SCRIPT_DIR}/supabase_credentials.txt" << EOF
# Supabase Credentials - KEEP SECURE!
# Generated on: $(date)

INSTALLATION_DIRECTORY: $SCRIPT_DIR
POSTGRES_PASSWORD: $POSTGRES_PASSWORD
JWT_SECRET: $JWT_SECRET
ANON_KEY: $ANON_KEY
SERVICE_ROLE_KEY: $SERVICE_ROLE_KEY

SUPABASE_URL: https://$domain
POSTGRES_CONNECTION: postgresql://postgres:${POSTGRES_PASSWORD}@$domain:$DEFAULT_POSTGRES_PORT/supabase

# To stop all services: docker stop \$(docker ps -q --filter network=$NETWORK_NAME)
# To start all services: docker start \$(docker ps -a -q --filter network=$NETWORK_NAME)
# To reset and start over: bash supabase.sh --reset
EOF

chmod 600 "${SCRIPT_DIR}/supabase_credentials.txt"

log "Setup completed
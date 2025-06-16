# Supabase Docker CLI Setup

A "simplified" Docker setup script to deploy a local Supabase stack with minimal configuration.

I just made this for fun, and to get a better understanding of Bash scripting.

![Preview](./preview.gif)

## Security Notes

⚠️ Do not use this in production unless you know what you are doing.
- ⚠️ All credentials are saved to `supabase_credentials.txt` with restricted permissions (chmod 600)
- This is not for production use, consider additional security measures if you are planning to do this.
- Keep your JWT secrets and API keys secure, refer to tools like 1Password for Developers or other Secret Handlers.

## Overview

This script automates the deployment of a complete Supabase stack using Docker containers. It sets up:

- PostgreSQL DB
- Supabase Studio (Admin UI)
- GoTrue (Auth)
- PostgREST (RESTful API)
- Realtime (Websocket API)
- Storage API
- Kong API Gateway

## Requirements

- docker ce
- curl
- bash shell

## Quick Start

```bash
# Basic usage
./supabase.sh

# Reset existing setup and start fresh
./supabase.sh --reset
```

## Features

- Interactive setup with random defaults
- Auto-generation of secure passwords and JWT secrets
- Email authentication setup with SMTP configuration
- Automated JWT key generation for API security
- Complete Docker Compose configuration generated for reference
- Secure credentials storage

## Configuration Options

1. **Installation Directory** - Where to store configuration and data
2. **PostgreSQL Password** - Optional, auto-generated if not provided
3. **JWT Secret** - Optional, auto-generated if not provided
4. **Domain** - Required for service configuration
5. **Email Signup** - Optional SMTP configuration for authentication emails

## Access Your Supabase Services

After installation, you can access:

- **Supabase Studio**: `https://yourdomain:3000`
- **REST API**: `http://yourdomain:8000`
- **PostgreSQL**: `postgresql://postgres:password@yourdomain:5432/supabase`

## Managing Your Installation

```bash
# Stop all services
docker stop $(docker ps -q --filter network=supabase-network)

# Start all services
docker start $(docker ps -a -q --filter network=supabase-network)

# Reset and start over
./supabase.sh --reset
```

## Troubleshooting

Check the log file `supabase_setup.log` for details of the output process.

## License

See [LICENSE](./LICENSE) for more information.
# Squid Proxy Docker Image

A Dockerized version of the Squid proxy server with automatic user management using environment variables.

## Features

- Automated Squid proxy installation
- User authentication with environment variables
- Easy deployment with Docker Compose
- Persistent configuration storage

## Quick Start

### Using Docker Compose (Recommended)

1. Copy the environment file:
   ```bash
   cp env.example .env
   ```

2. Edit the `.env` file with your desired credentials:
   ```bash
   SQUID_USERNAME=your_username
   SQUID_PASSWORD=your_password
   SQUID_PORT=3128
   ```

3. Build and run the container:
   ```bash
   docker-compose up -d
   ```

### Using Docker directly

1. Build the image:
   ```bash
   docker build -t squid-proxy .
   ```

2. Run the container:
   ```bash
   docker run -d \
     --name squid-proxy \
     -p 3128:3128 \
     -e SQUID_USERNAME=your_username \
     -e SQUID_PASSWORD=your_password \
     squid-proxy
   ```

## Environment Variables

- `SQUID_USERNAME`: Username for proxy authentication (default: proxyuser)
- `SQUID_PASSWORD`: Password for proxy authentication (default: proxypass)
- `SQUID_PORT`: Port for the proxy server (default: 3128)

## Usage

Once the container is running, you can use the proxy with:

- **Proxy Server**: `your_server_ip:3128`
- **Username**: Value of `SQUID_USERNAME`
- **Password**: Value of `SQUID_PASSWORD`

### Example curl usage:
```bash
curl -x http://username:password@your_server_ip:3128 http://example.com
```

### Browser Configuration:
Configure your browser to use the proxy server with the credentials from your `.env` file.

## Managing Users

To add additional users or change passwords, you can:

1. Access the running container:
   ```bash
   docker exec -it squid-proxy bash
   ```

2. Add a new user:
   ```bash
   /usr/bin/htpasswd -b /etc/squid/passwd newuser newpassword
   ```

3. Reload Squid:
   ```bash
   systemctl reload squid
   ```

## Stopping the Service

```bash
docker-compose down
```

## Troubleshooting

- Check container logs: `docker-compose logs squid-proxy`
- Verify the proxy is running: `docker exec squid-proxy systemctl status squid`
- Test connectivity: `curl -x http://username:password@localhost:3128 http://httpbin.org/ip`

# Edge Reverse Proxy (Traefik v3)

ThingLarp uses **Traefik v3** as its unified ingress and TLS termination point. It sits between public networks and internal Docker containers, managing SSL/TLS certificates automatically via Let's Encrypt.

---

## Port Allocation & Routing Rules

```
Traefik Ingress
├── :80    (HTTP)   -> Redirect to HTTPS & ACME challenge validation
├── :443   (HTTPS)  -> FastAPI Gateway (Host: api.example.com) & WebSockets
├── :8883  (MQTTS)  -> Mosquitto TCP listener (:1883) with TLS termination
└── :8080  (Admin)  -> Traefik Dashboard (Internal / Protected)
```

---

## Configuration Details

### Static Configuration (`traefik/traefik.yml`)

```yaml
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https

  websecure:
    address: ":443"

  mqtts:
    address: ":8883"

certificatesResolvers:
  letsencrypt:
    acme:
      email: ${ACME_EMAIL}
      storage: /etc/traefik/acme/acme.json
      httpChallenge:
        entryPoint: web

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: edge
```

---

## Docker Compose Labels

Services dynamically register with Traefik using Docker labels in `docker-compose.yml`:

### FastAPI Gateway Registration
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.api.rule=Host(`${API_DOMAIN}`)"
  - "traefik.http.routers.api.entrypoints=websecure"
  - "traefik.http.routers.api.tls.certresolver=letsencrypt"
  - "traefik.http.services.api.loadbalancer.server.port=8000"
```

### Mosquitto MQTTS (TCP TLS) Registration
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.tcp.routers.mqtt.rule=HostSNI(`${MQTT_DOMAIN}`)"
  - "traefik.tcp.routers.mqtt.entrypoints=mqtts"
  - "traefik.tcp.routers.mqtt.tls.certresolver=letsencrypt"
  - "traefik.tcp.services.mqtt.loadbalancer.server.port=1883"
```

---

## Local Development vs. Production

- **Local / LAN Testing:** In local environments without a public domain name, devices connect directly to port `1883` (plain MQTT) and port `8000` (FastAPI HTTP).
- **Production Deployment:** In production, Traefik routes all traffic through TLS ports `443` and `8883`, ensuring hardware devices and client dashboards are encrypted end-to-end.

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
          permanent: true

  websecure:
    address: ":443"

  mqtts:
    address: ":8883"

certificatesResolvers:
  letsencrypt:
    acme:
      storage: "/letsencrypt/acme.json"
      httpChallenge:
        entryPoint: "web"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: "iot_edge"
```

> [!NOTE]
> Traefik receives the Let's Encrypt account email dynamically via command flag in `docker-compose.yml`:
> `command: ["--certificatesresolvers.letsencrypt.acme.email=${ACME_EMAIL}"]`

---

## Docker Compose Labels & Routing

Services dynamically register with Traefik using Docker labels in `docker-compose.yml`:

### 1. FastAPI Gateway Registration
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.docker.network=iot_edge"
  - "traefik.http.routers.api.rule=Host(`${API_DOMAIN}`)"
  - "traefik.http.routers.api.entrypoints=websecure"
  - "traefik.http.routers.api.tls.certresolver=letsencrypt"
  - "traefik.http.services.api.loadbalancer.server.port=8000"
```

### 2. Mosquitto WebSockets (WSS on Port 443)
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.docker.network=iot_edge"
  - "traefik.http.routers.mqtt-ws.rule=Host(`${MQTT_DOMAIN}`) && PathPrefix(`/mqtt`)"
  - "traefik.http.routers.mqtt-ws.entrypoints=websecure"
  - "traefik.http.routers.mqtt-ws.tls.certresolver=letsencrypt"
  - "traefik.http.services.mqtt-ws.loadbalancer.server.port=9001"
```

### 3. Mosquitto MQTTS (TCP TLS on Port 8883)
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.docker.network=iot_edge"
  - "traefik.tcp.routers.mqtt-tls.rule=HostSNI(`${MQTT_DOMAIN}`)"
  - "traefik.tcp.routers.mqtt-tls.entrypoints=mqtts"
  - "traefik.tcp.routers.mqtt-tls.tls.certresolver=letsencrypt"
  - "traefik.tcp.services.mqtt-tls.loadbalancer.server.port=1883"
```

---

## Complete Isolation (Production Standard)

ThingLarp implements complete edge isolation:
- Raw backend ports `1883` (Mosquitto), `8000` (FastAPI), and `5432` (TimescaleDB) are **never bound to the host**.
- Traefik is the **exclusive ingress point** handling `:80` (HTTP redirect), `:443` (HTTPS & WSS), and `:8883` (MQTTS).
- The Traefik dashboard (`:8080`) is strictly bound to `127.0.0.1:8080` or private VPN interfaces (e.g. Tailscale), preventing public exposure.

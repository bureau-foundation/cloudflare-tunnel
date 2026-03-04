# cloudflare-tunnel

Cloudflare Tunnel template for [Bureau](https://github.com/bureau-foundation/bureau).
Routes external traffic into the Bureau service mesh via Cloudflare's global
network.

## What this provides

A Nix flake that packages `cloudflared` as a Bureau template. The template
runs in connector-token mode: all routing is configured in the Cloudflare
dashboard, with zero config files inside the sandbox.

cloudflared natively supports Unix socket origins, so it connects directly to
Bureau service sockets mounted via `RequiredServicesOverride` — no bridge
process needed.

## Architecture

```
External traffic ──▶ Cloudflare Edge ──tunnel──▶ cloudflared (Bureau sandbox)
                                                      │
                                        /run/bureau/service/<role>.sock
                                                      │
                                              Bureau service
```

## Deployment

### 1. Create a Cloudflare Tunnel

Via the [Cloudflare Zero Trust dashboard](https://one.dash.cloudflare.com/):

1. Navigate to Networks > Tunnels
2. Create a tunnel (type: Cloudflared)
3. Copy the tunnel token
4. Add a public hostname entry:
   - **Subdomain**: your choice (e.g., `webhooks`)
   - **Domain**: your domain
   - **Service**: `unix:/run/bureau/service/<role>.sock` (the service socket
     mounted into the sandbox)

### 2. Publish the template

```bash
bureau template publish --flake github:bureau-foundation/cloudflare-tunnel \
    --room <your-template-room>
```

This evaluates the flake's `bureauTemplate` output and publishes it as a Matrix
state event. The command path resolves to a full `/nix/store/...` path. The
daemon prefetches missing store paths from the binary cache before creating the
sandbox.

### 3. Deploy the service

```bash
bureau service create bureau/template:cloudflare-tunnel \
    --machine machine/<your-machine> \
    --name service/tunnel/cloudflare \
    --credential-file ./creds \
    --extra-credential "TUNNEL_TOKEN=<your-tunnel-token>"
```

The template declares `TUNNEL_TOKEN` as a secret binding. The `--extra-credential`
flag adds it to the age-encrypted credential bundle published to the machine's
config room. The launcher decrypts the bundle at sandbox creation time and injects
the token as an environment variable — the plaintext value never appears in Matrix
state events.

To mount service sockets into the tunnel's sandbox (e.g., for routing traffic to
a forge service), set `required_services_override` on the principal assignment:

```json
{
    "required_services_override": ["forge/github:http"]
}
```

The template has no default RequiredServices — the operator configures this per
deployment based on which services the tunnel routes to.

### 4. Configure Cloudflare ingress

In the Cloudflare dashboard, set the origin service to the Unix socket path
that corresponds to the mounted service. cloudflared's ingress rules support
`unix:/path` origins directly:

| Hostname | Service |
|----------|---------|
| `webhooks.example.com` | `unix:/run/bureau/service/forge/github-http.sock` |

### 5. Verify

```bash
bureau observe service/tunnel/cloudflare
curl https://webhooks.example.com/
```

## Binary cache

This flake is configured to use Bureau's R2 binary cache at
`cache.infra.bureau.foundation`. CI pushes signed closures on every merge to
main, so `nix build` and `bureau template publish --flake` fetch pre-built
binaries rather than compiling from source.

## Development

```bash
# Build cloudflared
nix build

# Evaluate the template output
nix eval --json .#bureauTemplate.x86_64-linux | jq .

# Run cloudflared directly (for local testing)
nix run -- tunnel --help
```

## License

Apache-2.0. See [LICENSE](LICENSE).

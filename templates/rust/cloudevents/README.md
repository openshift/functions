# Rust Events Function

Welcome to your new Rust function project! The boilerplate
[actix](https://actix.rs/) web server is in
[`src/main.rs`](./src/main.rs). It's configured to invoke the `handle`
function in [`src/handler.rs`](./src/handler.rs) in response to a POST
request containing a valid `CloudEvent`. You should put your desired
behavior inside that `handle` function. In case you need to configure
some resources for your function, you can do that in the [`configure` function](./src/config.rs).

The app will expose three endpoints:

  * `/` Triggers the `handle` function for a POST method
  * `/health/readiness` The endpoint for a readiness health check
  * `/health/liveness` The endpoint for a liveness health check

You may use any of the available [actix
features](https://actix.rs/docs/) to fulfill the requests at those
endpoints.

## Development

This is a fully self-contained application, so you can develop it as
you would any other Rust application, e.g.

```shell script
cargo build
cargo test
cargo run
```

Once running, the function is available at <http://localhost:8080> and
the health checks are at <http://localhost:8080/health/readiness> and
<http://localhost:8080/health/liveness>. To POST an event to the
function, a utility such as `curl` may be used:

```console
curl -v -d '{"name": "Bootsy"}' \
  -H'content-type: application/json' \
  -H'ce-specversion: 1.0' \
  -H'ce-id: 1' \
  -H'ce-source: https://cloudevents.io' \
  -H'ce-type: dev.knative.example' \
  http://localhost:8080
```

## Deployment

Use `func` to containerize your application, publish it to a registry
and deploy it as a Knative Service in your Kubernetes cluster:

```shell script
func deploy --registry=docker.io/<YOUR_ACCOUNT>
```

You can omit the `--registry` option by setting the `FUNC_REGISTRY`
environment variable. And if you forget, you'll be prompted.

The output from a successful deploy should show the URL for the
service, which you can also get via `func info`, e.g.

```console
curl -v -d '{"name": "Bootsy"}' \
  -H'content-type: application/json' \
  -H'ce-specversion: 1.0' \
  -H'ce-id: 1' \
  -H'ce-source: https://cloudevents.io' \
  -H'ce-type: dev.knative.example' \
  $(func info -o url)
```

Have fun!

### Use Private Cargo Registries
If you want to use crates from a private Cargo registry,
you can do it by mounting Cargo configuration and credentials files.

This is done by setting the `build.volumes` property in the `func.yaml` config file.

#### pack
For the `pack` builder, mount your Cargo configuration files into the build container:
```yaml
# $schema: https://raw.githubusercontent.com/knative/func/refs/heads/main/schema/func_yaml-schema.json
specVersion: 0.36.0
name: rust-fn
runtime: rust
created: 2025-03-17T02:02:34.196208671+01:00
build:
  volumes:
    - hostPath: /home/jdoe/.cargo/config.toml
      path: /home/cnb/.cargo/config.toml
    - hostPath: /home/jdoe/.cargo/credentials.toml
      path: /home/cnb/.cargo/credentials.toml
```

#### s2i
For the `s2i` builder, mount your Cargo configuration files into the source directory:
```yaml
# $schema: https://raw.githubusercontent.com/knative/func/refs/heads/main/schema/func_yaml-schema.json
specVersion: 0.36.0
name: rust-fn
runtime: rust
created: 2025-03-17T02:02:34.196208671+01:00
build:
  volumes:
    - hostPath: /home/jdoe/.cargo/config.toml
      path: /opt/app-root/src/.cargo/config.toml
    - hostPath: /home/jdoe/.cargo/credentials.toml
      path: /opt/app-root/src/.cargo/credentials.toml
```

For more, see [the complete documentation]('https://github.com/knative/func/tree/main/docs')

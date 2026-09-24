# Function project

Welcome to your new Quarkus function project!

This sample project contains a single function: `functions.Function.function()`,
the function just returns its argument.

## Local execution
Make sure that `Java 11 SDK` is installed.

To start server locally run `./mvnw quarkus:dev`.
The command starts http server and automatically watches for changes of source code.
If source code changes the change will be propagated to running server. It also opens debugging port `5005`
so debugger can be attached if needed.

To run test locally run `./mvnw test`.

## The `func` CLI

It's recommended to set `FUNC_REGISTRY` environment variable.
```shell script
# replace ~/.bashrc by your shell rc file
# replace docker.io/johndoe with your registry
export FUNC_REGISTRY=docker.io/johndoe
echo "export FUNC_REGISTRY=docker.io/johndoe" >> ~/.bashrc
```

### Building

This command builds OCI image for the function.

```shell script
func build
```

By default, JVM build is used.
To enable native build set following environment variables to `func.yaml`:
```yaml
buildEnvs:
  - name: BP_NATIVE_IMAGE
    value: "true"
```

### Running

This command runs the function locally in a container
using the image created above.
```shell script
func run
```

### Deploying

This commands will build and deploy the function into cluster.

```shell script
func deploy # also triggers build
```

## Function invocation

Do not forget to set `URL` variable to the route of your function.

You get the route by following command.
```shell script
func info
```

### cURL

```shell script
URL=http://localhost:8080/
curl -v ${URL} \
  -H "Content-Type:application/json" \
  -H "Ce-Id:1" \
  -H "Ce-Source:cloud-event-example" \
  -H "Ce-Type:dev.knative.example" \
  -H "Ce-Specversion:1.0" \
  -d "{\"message\": \"$(whoami)\"}\""
```

### HTTPie

```shell script
URL=http://localhost:8080/
http -v ${URL} \
  Content-Type:application/json \
  Ce-Id:1 \
  Ce-Source:cloud-event-example \
  Ce-Type:dev.knative.example \
  Ce-Specversion:1.0 \
  message=$(whoami)
```

### Use Private Maven Repositories
If you want to use dependencies from a private Maven repository,
you can do it by mounting a Maven `settings.xml` file with your repository credentials.

This is done by setting the `build.volumes` and `build.buildEnvs` properties in the `func.yaml` config file.

#### pack
For the `pack` builder, use [paketo bindings](https://github.com/paketo-buildpacks/maven?tab=readme-ov-file#bindings) to provide Maven settings:
```yaml
# $schema: https://raw.githubusercontent.com/knative/func/refs/heads/main/schema/func_yaml-schema.json
specVersion: 0.36.0
name: quarkus-fn
runtime: quarkus
created: 2025-03-17T02:02:34.196208671+01:00
build:
  buildEnvs:
    - name: SERVICE_BINDING_ROOT
      value: /bindings
  volumes:
    - hostPath: /tmp/maven-settings
      path: /bindings/maven-settings
```
The binding directory (`/tmp/maven-settings`) should contain a `type` file with the value `maven` and your `settings.xml` file.

#### s2i
For the `s2i` builder, mount your `settings.xml` file directly:
```yaml
# $schema: https://raw.githubusercontent.com/knative/func/refs/heads/main/schema/func_yaml-schema.json
specVersion: 0.36.0
name: quarkus-fn
runtime: quarkus
created: 2025-03-17T02:02:34.196208671+01:00
build:
  volumes:
    - hostPath: /home/jdoe/.m2/settings.xml
      path: /opt/app-root/src/.m2/settings.xml
```

For more, see [the complete documentation]('https://github.com/knative/func/tree/main/docs')

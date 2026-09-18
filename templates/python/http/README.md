# Python HTTP Function

Welcome to your new Python Function! A minimal Function implementation can
be found in `./function/func.py`.

For more, run `func --help` or read the [Python Functions doc](https://github.com/knative/func/blob/main/docs/function-templates/python.md)

## Usage

Knative Functions allow for the deployment of your source code directly to a
Kubernetes cluster with Knative installed.

### Function Structure

Python functions must implement a `new()` method that returns a function
instance. The function class can optionally implement:
- `handle()` - Process HTTP requests
- `start()` - Initialize the function with configuration
- `stop()` - Clean up resources when the function stops
- `alive()` / `ready()` - Health and readiness checks

See the default implementation in `./function/func.py`

### Running Locally

Use `func run` to test your Function locally before deployment.
For development environments where Python is installed, it's suggested to use
the `host` builder as follows:

```bash
# Run function on the host (outside of a container)
func run --builder=host
```

### Deploying

Use `func deploy` to deploy your Function to a Knative-enabled cluster:

```bash
# Deploy with interactive prompts (recommended for first deployment)
func deploy --registry ghcr.io/myuser
```

Functions are automatically built, containerized, and pushed to a registry
before deployment. Subsequent deployments will update the existing function.

## Roadmap

Our project roadmap can be found: https://github.com/orgs/knative/projects/49


### Install Private Python Packages
If you want to install packages from a private Python package index,
you can do it by mounting credentials and by setting appropriate environment variable.

This is done by setting the `build.volumes` and `build.buildEnvs` properties in the `func.yaml` config file.

#### pack
For the `pack` builder, set the private index URL and mount a `pip.conf` file with credentials:
```yaml
# $schema: https://raw.githubusercontent.com/knative/func/refs/heads/main/schema/func_yaml-schema.json
specVersion: 0.36.0
name: python-fn
runtime: python
created: 2025-03-17T02:02:34.196208671+01:00
build:
  buildEnvs:
    - name: PIP_EXTRA_INDEX_URL
      value: https://pypi.example.com/simple/
  volumes:
    - hostPath: /home/jdoe/pip.conf
      path: /home/cnb/.config/pip/pip.conf
```

#### s2i
For the `s2i` builder, set the private index URL and mount a `pip.conf` file with credentials:
```yaml
# $schema: https://raw.githubusercontent.com/knative/func/refs/heads/main/schema/func_yaml-schema.json
specVersion: 0.36.0
name: python-fn
runtime: python
created: 2025-03-17T02:02:34.196208671+01:00
build:
  buildEnvs:
    - name: PIP_EXTRA_INDEX_URL
      value: https://pypi.example.com/simple/
  volumes:
    - hostPath: /home/jdoe/pip.conf
      path: /opt/app-root/src/.config/pip/pip.conf
```

For more, see [the complete documentation]('https://github.com/knative/func/tree/main/docs')

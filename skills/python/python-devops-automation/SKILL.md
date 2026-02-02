---
name: python-devops-automation
description: |
  DevOps automation with Python. Use this skill when automating infrastructure, 
  working with AWS (boto3), building CLIs (click/typer), managing subprocesses, or 
  working with Docker/Kubernetes from Python. Covers boto3 patterns, CLI design, 
  subprocess management, and infrastructure automation.
---

# Python DevOps Automation

Automation patterns for infrastructure, cloud, and operational tasks.

## Core Principles

1. **Idempotent operations** - Safe to run multiple times
2. **Error handling first** - Anticipate failures
3. **Logging over print** - Structured, searchable logs
4. **Configuration external** - Environment variables, config files

## CLI Development with Click

**Use click for command-line tools**

```python
import click

@click.command()
@click.option('--count', default=1, help='Number of times to run')
@click.option('--verbose', is_flag=True, help='Verbose output')
@click.argument('name')
def greet(count, verbose, name):
    """Simple CLI tool."""
    for _ in range(count):
        if verbose:
            click.echo(f'Greeting: Hello {name}!')
        else:
            click.echo(f'Hello {name}!')

if __name__ == '__main__':
    greet()
```

See [cli-patterns.md](references/cli-patterns.md) for:
- Command groups
- Progress bars
- File handling
- Click vs Typer

## AWS Automation with Boto3

**Use boto3 for AWS operations**

```python
import boto3

# S3 operations
s3 = boto3.client('s3')
s3.upload_file('local.txt', 'bucket-name', 'remote.txt')

# EC2 operations
ec2 = boto3.resource('ec2')
instances = ec2.instances.filter(
    Filters=[{'Name': 'tag:Environment', 'Values': ['production']}]
)
```

See [boto3-patterns.md](references/boto3-patterns.md) for:
- Resource vs client
- Pagination
- Error handling
- Credential management

## Subprocess Management

**Use subprocess for external commands**

```python
import subprocess

# Run command, capture output
result = subprocess.run(
    ['ls', '-la'],
    capture_output=True,
    text=True,
    check=True
)
print(result.stdout)

# Stream output in real-time
process = subprocess.Popen(
    ['long-running-command'],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True
)

for line in process.stdout:
    print(line, end='')

returncode = process.wait()
```

See [subprocess-patterns.md](references/subprocess-patterns.md) for:
- Error handling
- Timeouts
- Shell=True dangers
- Environment variables

## Docker Automation

**Use docker-py for container management**

```python
import docker

client = docker.from_env()

# Run container
container = client.containers.run(
    "ubuntu:latest",
    "echo hello world",
    detach=True
)

# Wait for completion
container.wait()
print(container.logs().decode())
```

See [docker-patterns.md](references/docker-patterns.md).

## Configuration Management

```python
import os
from pathlib import Path
from dataclasses import dataclass
import tomli

@dataclass
class Config:
    api_key: str
    region: str
    debug: bool = False
    
    @classmethod
    def from_env(cls):
        """Load from environment variables."""
        return cls(
            api_key=os.environ['API_KEY'],
            region=os.getenv('AWS_REGION', 'us-east-1'),
            debug=os.getenv('DEBUG', 'false').lower() == 'true'
        )
    
    @classmethod
    def from_file(cls, path: Path):
        """Load from TOML config file."""
        with open(path, 'rb') as f:
            data = tomli.load(f)
        return cls(**data)
```

See [config-patterns.md](references/config-patterns.md).

## Logging Best Practices

```python
import logging
from pathlib import Path

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('app.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

def deploy_app():
    logger.info("Starting deployment")
    try:
        # Deployment logic
        logger.debug("Uploading files...")
        logger.info("Deployment successful")
    except Exception as e:
        logger.error(f"Deployment failed: {e}", exc_info=True)
        raise
```

See [logging-patterns.md](references/logging-patterns.md).

source: DevOps with Python

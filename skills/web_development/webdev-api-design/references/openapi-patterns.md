# OpenAPI Patterns Reference

Patterns for designing OpenAPI 3.1 specifications, reusable schemas, path organization, and code generation workflows.

---

## OpenAPI 3.1 Document Structure

```yaml
openapi: "3.1.0"
info:
  title: Example API
  description: A well-structured REST API
  version: "1.0.0"
  contact:
    name: API Support
    email: api-support@example.com
    url: https://developer.example.com/support
  license:
    name: MIT
    url: https://opensource.org/licenses/MIT

servers:
  - url: https://api.example.com/v1
    description: Production
  - url: https://staging-api.example.com/v1
    description: Staging
  - url: http://localhost:3000/v1
    description: Local development

tags:
  - name: Users
    description: User account management
  - name: Orders
    description: Order lifecycle operations

security:
  - bearerAuth: []

paths:
  /users:
    $ref: "./paths/users.yaml"
  /users/{user_id}:
    $ref: "./paths/users-by-id.yaml"

components:
  $ref: "./components/index.yaml"
```

---

## Path Definitions

### Collection Endpoint

```yaml
# paths/users.yaml
get:
  tags: [Users]
  operationId: listUsers
  summary: List all users
  description: Returns a paginated list of users. Supports filtering and sorting.
  parameters:
    - $ref: "../components/parameters/LimitParam.yaml"
    - $ref: "../components/parameters/CursorParam.yaml"
    - name: status
      in: query
      description: Filter by account status
      schema:
        type: string
        enum: [active, inactive, suspended]
    - name: sort
      in: query
      description: "Sort field (prefix with - for descending)"
      schema:
        type: string
        default: "-created_at"
        examples: ["-created_at", "name", "-email"]
  responses:
    "200":
      description: Successful response
      content:
        application/json:
          schema:
            $ref: "../components/schemas/UserListResponse.yaml"
    "400":
      $ref: "../components/responses/BadRequest.yaml"
    "401":
      $ref: "../components/responses/Unauthorized.yaml"
    "429":
      $ref: "../components/responses/TooManyRequests.yaml"

post:
  tags: [Users]
  operationId: createUser
  summary: Create a new user
  requestBody:
    required: true
    content:
      application/json:
        schema:
          $ref: "../components/schemas/CreateUserRequest.yaml"
        examples:
          basic:
            summary: Basic user creation
            value:
              name: "Jane Park"
              email: "jane@example.com"
          with_role:
            summary: User with admin role
            value:
              name: "Alex Chen"
              email: "alex@example.com"
              role: "admin"
  responses:
    "201":
      description: User created
      headers:
        Location:
          description: URL of the created user
          schema:
            type: string
            format: uri
      content:
        application/json:
          schema:
            $ref: "../components/schemas/UserResponse.yaml"
    "409":
      $ref: "../components/responses/Conflict.yaml"
    "422":
      $ref: "../components/responses/ValidationError.yaml"
```

### Instance Endpoint

```yaml
# paths/users-by-id.yaml
parameters:
  - name: user_id
    in: path
    required: true
    description: Unique user identifier
    schema:
      type: string
      pattern: "^usr_[a-zA-Z0-9]+$"
      example: "usr_a1b2c3"

get:
  tags: [Users]
  operationId: getUser
  summary: Get a user by ID
  responses:
    "200":
      description: Successful response
      headers:
        ETag:
          schema:
            type: string
      content:
        application/json:
          schema:
            $ref: "../components/schemas/UserResponse.yaml"
    "404":
      $ref: "../components/responses/NotFound.yaml"

patch:
  tags: [Users]
  operationId: updateUser
  summary: Partially update a user
  parameters:
    - name: If-Match
      in: header
      description: ETag for optimistic concurrency control
      schema:
        type: string
  requestBody:
    required: true
    content:
      application/merge-patch+json:
        schema:
          $ref: "../components/schemas/UpdateUserRequest.yaml"
  responses:
    "200":
      description: User updated
      content:
        application/json:
          schema:
            $ref: "../components/schemas/UserResponse.yaml"
    "409":
      description: Conflict -- ETag mismatch
      content:
        application/problem+json:
          schema:
            $ref: "../components/schemas/ProblemDetail.yaml"
    "422":
      $ref: "../components/responses/ValidationError.yaml"

delete:
  tags: [Users]
  operationId: deleteUser
  summary: Delete a user
  responses:
    "204":
      description: User deleted
    "404":
      $ref: "../components/responses/NotFound.yaml"
```

---

## Reusable Components

### Schemas

```yaml
# components/schemas/User.yaml
type: object
required: [id, name, email, created_at]
properties:
  id:
    type: string
    pattern: "^usr_[a-zA-Z0-9]+$"
    description: Unique user identifier
    example: "usr_a1b2c3"
  name:
    type: string
    minLength: 1
    maxLength: 200
    example: "Jane Park"
  email:
    type: string
    format: email
    example: "jane@example.com"
  role:
    type: string
    enum: [user, admin, moderator]
    default: user
  status:
    type: string
    enum: [active, inactive, suspended]
    default: active
  created_at:
    type: string
    format: date-time
    readOnly: true
  updated_at:
    type: string
    format: date-time
    readOnly: true
```

### Wrapper Schemas for Responses

```yaml
# components/schemas/UserResponse.yaml
type: object
required: [data, meta]
properties:
  data:
    $ref: "./User.yaml"
  meta:
    $ref: "./ResponseMeta.yaml"

# components/schemas/UserListResponse.yaml
type: object
required: [data, pagination, meta]
properties:
  data:
    type: array
    items:
      $ref: "./User.yaml"
  pagination:
    $ref: "./CursorPagination.yaml"
  meta:
    $ref: "./ResponseMeta.yaml"

# components/schemas/ResponseMeta.yaml
type: object
properties:
  request_id:
    type: string
    example: "req_x7k9m2"
  processing_time_ms:
    type: integer
    example: 42
```

### Reusable Parameters

```yaml
# components/parameters/LimitParam.yaml
name: limit
in: query
description: Maximum number of items to return
schema:
  type: integer
  minimum: 1
  maximum: 100
  default: 20

# components/parameters/CursorParam.yaml
name: cursor
in: query
description: Opaque cursor for pagination
schema:
  type: string
```

### Reusable Error Responses

```yaml
# components/responses/ValidationError.yaml
description: Validation error
content:
  application/problem+json:
    schema:
      allOf:
        - $ref: "../schemas/ProblemDetail.yaml"
        - type: object
          properties:
            errors:
              type: array
              items:
                $ref: "../schemas/FieldError.yaml"

# components/schemas/ProblemDetail.yaml (RFC 7807)
type: object
required: [type, title, status]
properties:
  type:
    type: string
    format: uri
    description: URI identifying the problem type
  title:
    type: string
    description: Short human-readable summary
  status:
    type: integer
    description: HTTP status code
  detail:
    type: string
    description: Human-readable explanation
  instance:
    type: string
    description: URI identifying the specific occurrence
```

### Security Schemes

```yaml
# components/securitySchemes
bearerAuth:
  type: http
  scheme: bearer
  bearerFormat: JWT
  description: JWT token obtained from /auth/token

apiKeyAuth:
  type: apiKey
  in: header
  name: X-API-Key

oauth2Auth:
  type: oauth2
  flows:
    authorizationCode:
      authorizationUrl: https://auth.example.com/authorize
      tokenUrl: https://auth.example.com/token
      scopes:
        read:users: Read user profiles
        write:users: Create and update users
        admin: Full administrative access
```

---

## Code Generation Workflows

### Generating Client SDKs

```bash
# Generate TypeScript client
npx @openapitools/openapi-generator-cli generate \
  -i openapi.yaml \
  -g typescript-fetch \
  -o ./generated/client \
  --additional-properties=supportsES6=true,npmName=@example/api-client

# Generate Python client
openapi-generator-cli generate \
  -i openapi.yaml \
  -g python \
  -o ./generated/python-client

# Generate Go client
openapi-generator-cli generate \
  -i openapi.yaml \
  -g go \
  -o ./generated/go-client
```

### Generating Server Stubs

```bash
# Generate Express server stub
openapi-generator-cli generate \
  -i openapi.yaml \
  -g nodejs-express-server \
  -o ./generated/server

# Generate Spring Boot server
openapi-generator-cli generate \
  -i openapi.yaml \
  -g spring \
  -o ./generated/spring-server
```

### Linting and Validation

```bash
# Validate spec with Spectral
npx @stoplight/spectral-cli lint openapi.yaml

# Custom ruleset (.spectral.yaml)
# extends: ["spectral:oas"]
# rules:
#   operation-operationId: error
#   operation-description: warn
#   oas3-valid-media-example: error
```

---

## Spec Organization for Large APIs

```
api/
  openapi.yaml              # Root document
  paths/
    users.yaml
    users-by-id.yaml
    orders.yaml
    orders-by-id.yaml
  components/
    index.yaml
    schemas/
      User.yaml
      Order.yaml
      ProblemDetail.yaml
      CursorPagination.yaml
    parameters/
      LimitParam.yaml
      CursorParam.yaml
    responses/
      BadRequest.yaml
      NotFound.yaml
      ValidationError.yaml
    securitySchemes/
      BearerAuth.yaml
  examples/
    user-basic.yaml
    user-admin.yaml
```

Use `$ref` to reference shared components across paths. Bundle the spec for publishing with `swagger-cli bundle openapi.yaml -o dist/openapi.yaml`.

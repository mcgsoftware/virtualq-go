---
inclusion: always
---

# Go Server Technology Stack

This document defines the technology stack and implementation guidelines for the VirtualQ REST API server.

## VirtualQ REST API Stack

### Core Technologies
- **Language**: Go 1.21+
- **Web Framework**: Gin (github.com/gin-gonic/gin)
- **Database**: PostgreSQL 17+ (Neon-hosted)
- **Database Access**: sqlc for type-safe SQL generation
- **Database Driver**: pgx (github.com/jackc/pgx/v5)
- **Migrations**: golang-migrate (github.com/golang-migrate/migrate)
- **UUID Generation**: github.com/google/uuid (with v7 support)
- **Configuration**: Environment variables with validation
- **Logging**: log/slog (Go standard library structured logging)
- **Testing**: Go standard testing + testify (github.com/stretchr/testify)

### Additional Libraries
- **Validation**: go-playground/validator for request validation
- **CORS**: Gin CORS middleware
- **OpenAPI**: Generate server stubs from openapi.yaml
- **Redis**: go-redis (github.com/redis/go-redis) for caching and pub/sub

## Project Structure

```
virtualq-api/
├── cmd/
│   └── server/
│       └── main.go              # Application entry point
├── internal/
│   ├── api/
│   │   ├── handlers/            # HTTP handlers (controllers)
│   │   ├── middleware/          # Custom middleware
│   │   └── routes.go            # Route definitions
│   ├── config/
│   │   └── config.go            # Configuration management
│   ├── db/
│   │   ├── migrations/          # SQL migration files
│   │   ├── queries/             # sqlc query definitions
│   │   └── sqlc/                # Generated sqlc code
│   ├── models/                  # Domain models
│   ├── services/                # Business logic layer
│   └── repository/              # Data access layer
├── pkg/                         # Public packages (if any)
├── scripts/                     # Build and deployment scripts
├── openapi.yaml                 # OpenAPI specification
├── sqlc.yaml                    # sqlc configuration
├── go.mod
├── go.sum
└── README.md
```

## Implementation Guidelines

### Logging with log/slog
- Use structured logging throughout the application
- Log levels: Debug, Info, Warn, Error
- Include request IDs for tracing
- Log tenant context for multi-tenant operations
- Example:
```go
slog.Info("ticket created",
    "ticket_id", ticketID,
    "tenant_id", tenantID,
    "queue_id", queueID,
)
```

### Database Access with sqlc
- Write SQL queries in `internal/db/queries/*.sql`
- Generate type-safe Go code with sqlc
- Use transactions for state transitions
- Leverage PostgreSQL JSONB for custom_data fields
- Use UUID v7 for all external identifiers

### API Handler Pattern
- Handlers parse and validate requests
- Delegate business logic to service layer
- Services coordinate between repositories
- Repositories handle database operations
- Return consistent error responses

### Multi-Tenant Isolation
- Extract tenant context from X-Tenant-ID header or tenant_id parameter
- Validate tenant access in middleware
- Scope all database queries to tenant_id
- Return 403 Forbidden for unauthorized access

### State Machine Validation
- Load TypeDefinition.fsm_schema from database
- Validate transitions before applying
- Record all transitions in TicketStateHistory
- Return 400 Bad Request with valid transitions on error

### Error Handling
- Use custom error types for domain errors
- Map errors to appropriate HTTP status codes
- Return consistent error response format:
```json
{
  "error": "error_code",
  "message": "Human-readable message",
  "details": {}
}
```

### Testing Strategy
- Unit tests for services and handlers
- Integration tests with test database
- Use testify for assertions and mocking
- Table-driven tests for multiple scenarios
- Test multi-tenant isolation thoroughly

## Configuration

### Environment Variables
- `PORT` - Server port (default: 8080)
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string
- `LOG_LEVEL` - Logging level (debug, info, warn, error)
- `ENV` - Environment (development, staging, production)
- `CORS_ORIGINS` - Allowed CORS origins

### Development Setup
```bash
# Install dependencies
go mod download

# Run migrations
migrate -path internal/db/migrations -database $DATABASE_URL up

# Generate sqlc code
sqlc generate

# Run server
go run cmd/server/main.go
```

## Performance Considerations
- Use connection pooling for PostgreSQL
- Implement Redis caching for frequently accessed data
- Use prepared statements via sqlc
- Optimize queries with proper indexes
- Monitor query performance with pg_stat_statements

## Security
- Validate all input with go-playground/validator
- Use parameterized queries (sqlc handles this)
- Implement rate limiting middleware
- Sanitize error messages (no SQL details in production)
- Use HTTPS in production (TLS termination at load balancer)

## Observability
- Structured logging with log/slog
- Request ID middleware for tracing
- Log all state transitions
- Monitor database connection pool metrics
- Track API response times

# Using sqlc for Type-Safe Database Access

## What is sqlc?

sqlc generates type-safe Go code from SQL queries. You write SQL, sqlc generates Go functions with proper types, parameter binding, and error handling.

## Project Structure for sqlc

```
internal/
├── db/
│   ├── migrations/           # Database migrations
│   │   ├── 000001_init.up.sql
│   │   └── 000001_init.down.sql
│   ├── queries/              # SQL query definitions
│   │   ├── tenants.sql
│   │   ├── tickets.sql
│   │   ├── queues.sql
│   │   └── type_definitions.sql
│   ├── schema.sql            # Complete schema (for sqlc)
│   └── sqlc/                 # Generated Go code (gitignored)
│       ├── db.go
│       ├── models.go
│       ├── tenants.sql.go
│       └── tickets.sql.go
sqlc.yaml                     # sqlc configuration
```

## sqlc.yaml Configuration

```yaml
version: "2"
sql:
  - engine: "postgresql"
    queries: "internal/db/queries"
    schema: "internal/db/schema.sql"
    gen:
      go:
        package: "db"
        out: "internal/db/sqlc"
        sql_package: "pgx/v5"
        emit_json_tags: true
        emit_prepared_queries: false
        emit_interface: true
        emit_exact_table_names: false
        emit_empty_slices: true
        overrides:
          - db_type: "uuid"
            go_type: "github.com/google/uuid.UUID"
          - db_type: "jsonb"
            go_type: "json.RawMessage"
```

## Example SQL Query File

**internal/db/queries/tickets.sql:**

```sql
-- name: GetTicket :one
SELECT * FROM tickets
WHERE id = $1 AND tenant_id = $2;

-- name: ListTicketsByQueue :many
SELECT * FROM tickets
WHERE queue_id = $1 
  AND tenant_id = $2
  AND current_state = ANY($3::text[])
ORDER BY created_at ASC
LIMIT $4 OFFSET $5;

-- name: CreateTicket :one
INSERT INTO tickets (
    extid,
    queue_id,
    type_definition_id,
    tenant_id,
    customer_id,
    current_state,
    custom_data,
    estimated_wait_minutes
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8
)
RETURNING *;

-- name: UpdateTicketState :one
UPDATE tickets
SET current_state = $1,
    employee_id = $2,
    updated_at = NOW()
WHERE id = $3 AND tenant_id = $4
RETURNING *;

-- name: CountTicketsByState :one
SELECT COUNT(*) FROM tickets
WHERE queue_id = $1
  AND tenant_id = $2
  AND current_state = $3;
```

## Running sqlc

```bash
# Install sqlc
go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest

# Generate Go code from SQL queries
sqlc generate

# Verify generated code
ls internal/db/sqlc/
```

## Makefile for Common Tasks

```makefile
.PHONY: sqlc migrate-up migrate-down db-reset

# Generate sqlc code
sqlc:
	sqlc generate

# Run database migrations up
migrate-up:
	migrate -path internal/db/migrations -database "$(DATABASE_URL)" up

# Run database migrations down
migrate-down:
	migrate -path internal/db/migrations -database "$(DATABASE_URL)" down

# Reset database (down + up)
db-reset:
	migrate -path internal/db/migrations -database "$(DATABASE_URL)" down
	migrate -path internal/db/migrations -database "$(DATABASE_URL)" up
	
# Generate sqlc after schema changes
db-gen: migrate-up sqlc

# Full database setup for new developers
db-setup:
	createdb virtualq_dev
	make migrate-up
	make sqlc
```

## Using Generated sqlc Code

```go
// internal/repository/ticket_repository.go
package repository

import (
    "context"
    "log/slog"
    
    "github.com/google/uuid"
    "github.com/yourorg/virtualq/internal/db/sqlc"
    "github.com/yourorg/virtualq/internal/errors"
)

type TicketRepository struct {
    queries *db.Queries
    logger  *slog.Logger
}

func NewTicketRepository(queries *db.Queries, logger *slog.Logger) *TicketRepository {
    return &TicketRepository{
        queries: queries,
        logger:  logger,
    }
}

// GetByID uses sqlc-generated GetTicket function
func (r *TicketRepository) GetByID(ctx context.Context, tenantID, ticketID int64) (*Ticket, error) {
    // sqlc generated function with type-safe parameters
    ticket, err := r.queries.GetTicket(ctx, db.GetTicketParams{
        ID:       ticketID,
        TenantID: tenantID,
    })
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            return nil, errors.NewNotFoundError("ticket", ticketID)
        }
        r.logger.ErrorContext(ctx, "failed to get ticket",
            "tenant_id", tenantID,
            "ticket_id", ticketID,
            "error", err,
        )
        return nil, errors.NewInternalError(err)
    }
    
    return mapTicketFromDB(ticket), nil
}

// Create uses sqlc-generated CreateTicket function
func (r *TicketRepository) Create(ctx context.Context, params CreateTicketParams) (*Ticket, error) {
    extid := uuid.Must(uuid.NewV7()) // Generate UUID v7
    
    ticket, err := r.queries.CreateTicket(ctx, db.CreateTicketParams{
        Extid:               extid,
        QueueID:             params.QueueID,
        TypeDefinitionID:    params.TypeDefinitionID,
        TenantID:            params.TenantID,
        CustomerID:          params.CustomerID,
        CurrentState:        params.InitialState,
        CustomData:          params.CustomData,
        EstimatedWaitMinutes: params.EstimatedWaitMinutes,
    })
    if err != nil {
        r.logger.ErrorContext(ctx, "failed to create ticket",
            "tenant_id", params.TenantID,
            "queue_id", params.QueueID,
            "error", err,
        )
        return nil, errors.NewInternalError(err)
    }
    
    return mapTicketFromDB(ticket), nil
}
```

## Development Workflow

1. **Update schema**: Edit `internal/db/schema.sql` or create migration
2. **Run migrations**: `make migrate-up` (applies schema changes)
3. **Write queries**: Add SQL to `internal/db/queries/*.sql`
4. **Generate code**: `make sqlc` (generates type-safe Go code)
5. **Use in repository**: Import and use generated functions
6. **Compile**: Go compiler catches type mismatches immediately

## Benefits

- **Type Safety**: Compile-time errors for SQL/Go type mismatches
- **No ORM Magic**: Plain SQL, no hidden queries or N+1 problems
- **Performance**: Prepared statements, efficient query execution
- **Maintainability**: SQL changes trigger compile errors in Go code
- **Testability**: Easy to mock `db.Queries` interface

# Multi-Tenant Context Propagation

## Why Context for Tenant ID?

In multi-tenant systems, tenant_id is the most critical piece of security and operational data. We use Go's `context.Context` to propagate tenant_id through all layers for several architectural reasons:

### 1. Security by Design
- Prevents accidental cross-tenant data access
- Makes tenant isolation explicit at every layer
- Enables audit trails for compliance (GDPR, SOC2, HIPAA)
- Allows detection of tenant mismatch attacks

### 2. Observability
- Every log statement can include tenant_id automatically
- Distributed tracing can track requests across services by tenant
- Metrics can be segmented by tenant for billing and monitoring
- Debugging production issues requires knowing which tenant

### 3. Operational Benefits
- Query filtering by tenant at database level
- Rate limiting per tenant
- Feature flags per tenant
- Performance monitoring per tenant
- Incident response (isolate affected tenants)

### 4. Architectural Clarity
- Explicit parameter passing makes data flow obvious
- No hidden global state or thread-local variables
- Testable (mock context with test tenant_id)
- Forces developers to think about multi-tenancy

## Why Not Global Variables or Thread-Local Storage?

- Go's concurrency model (goroutines) makes thread-local storage unreliable
- Global state is untestable and creates hidden dependencies
- Context makes the dependency explicit in function signatures
- Context cancellation propagates through the call stack

## Implementation Pattern

Multi-tenant context (tenant_id, request_id) is stored in `context.Context` and flows through all layers:

```go
// internal/middleware/tenant.go
type contextKey string

const (
    tenantIDKey  contextKey = "tenant_id"
    requestIDKey contextKey = "request_id"
)

// Middleware extracts tenant_id and adds to context
func TenantContext() gin.HandlerFunc {
    return func(c *gin.Context) {
        // Extract from header or query param
        tenantIDStr := c.GetHeader("X-Tenant-ID")
        if tenantIDStr == "" {
            tenantIDStr = c.Query("tenant_id")
        }
        
        if tenantIDStr == "" {
            c.JSON(400, ErrorResponse{
                Error:   "validation_error",
                Message: "tenant_id required",
            })
            c.Abort()
            return
        }
        
        tenantID, err := strconv.ParseInt(tenantIDStr, 10, 64)
        if err != nil {
            c.JSON(400, ErrorResponse{
                Error:   "validation_error",
                Message: "invalid tenant_id",
            })
            c.Abort()
            return
        }
        
        // Verify user has access to this tenant (authorization check)
        userID := c.GetInt64("user_id") // From auth middleware
        if !hasAccessToTenant(userID, tenantID) {
            c.JSON(403, ErrorResponse{
                Error:   "forbidden",
                Message: "Access denied to tenant",
            })
            c.Abort()
            return
        }
        
        // Add to context for downstream use
        ctx := context.WithValue(c.Request.Context(), tenantIDKey, tenantID)
        c.Request = c.Request.WithContext(ctx)
        
        c.Next()
    }
}

// Helper to extract tenant_id from context
func GetTenantID(ctx context.Context) (int64, bool) {
    tenantID, ok := ctx.Value(tenantIDKey).(int64)
    return tenantID, ok
}

// Helper to extract request_id from context
func GetRequestID(ctx context.Context) string {
    requestID, _ := ctx.Value(requestIDKey).(string)
    return requestID
}

// MustGetTenantID panics if tenant_id not in context (should never happen after middleware)
func MustGetTenantID(ctx context.Context) int64 {
    tenantID, ok := GetTenantID(ctx)
    if !ok {
        panic("tenant_id not found in context")
    }
    return tenantID
}
```

## Context Flow Through Layers

```
HTTP Request with X-Tenant-ID: 456
    ↓
[Middleware] Extract tenant_id → Add to context.Context
    ↓
[Handler] Extract from context → Pass to service
    ↓
[Service] Use tenant_id for:
    - Business logic validation
    - Logging with tenant context
    - Pass to repository
    ↓
[Repository] Use tenant_id for:
    - SQL WHERE tenant_id = $1 clauses
    - Logging with tenant context
    - Data isolation enforcement
    ↓
[Database] Query scoped to tenant_id
```

## Example: Context Flow in Practice

### Handler Layer
```go
// Handler extracts from context
func (h *TicketHandler) GetTicket(c *gin.Context) {
    ctx := c.Request.Context()
    tenantID := middleware.MustGetTenantID(ctx) // From context
    ticketID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
    
    // Pass context down (contains tenant_id, request_id, cancellation)
    ticket, err := h.ticketService.GetTicket(ctx, tenantID, ticketID)
    if err != nil {
        h.logger.ErrorContext(ctx, "failed to get ticket",
            "tenant_id", tenantID,  // Explicit for clarity
            "ticket_id", ticketID,
        )
        c.JSON(mapError(err))
        return
    }
    
    c.JSON(200, ticket)
}
```

### Service Layer
```go
// Service uses tenant_id for validation and logging
func (s *TicketService) GetTicket(ctx context.Context, tenantID, ticketID int64) (*Ticket, error) {
    // Context carries tenant_id, request_id, and cancellation signals
    ticket, err := s.ticketRepo.GetByID(ctx, tenantID, ticketID)
    if err != nil {
        return nil, err
    }
    
    // Verify tenant ownership (defense in depth)
    if ticket.TenantID != tenantID {
        s.logger.WarnContext(ctx, "tenant mismatch detected",
            "requested_tenant_id", tenantID,
            "ticket_tenant_id", ticket.TenantID,
            "ticket_id", ticketID,
        )
        return nil, apperrors.NewForbiddenError("Access denied")
    }
    
    return ticket, nil
}
```

### Repository Layer
```go
// Repository enforces tenant isolation at database level
func (r *TicketRepository) GetByID(ctx context.Context, tenantID, ticketID int64) (*Ticket, error) {
    // SQL query MUST include tenant_id in WHERE clause
    ticket, err := r.queries.GetTicketByIDAndTenant(ctx, db.GetTicketByIDAndTenantParams{
        ID:       ticketID,
        TenantID: tenantID,  // Enforces data isolation
    })
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            r.logger.DebugContext(ctx, "ticket not found",
                "tenant_id", tenantID,
                "ticket_id", ticketID,
            )
            return nil, apperrors.NewNotFoundError("ticket", ticketID)
        }
        r.logger.ErrorContext(ctx, "database error",
            "tenant_id", tenantID,
            "ticket_id", ticketID,
            "error", err,
        )
        return nil, apperrors.NewInternalError(err)
    }
    
    return mapToTicket(ticket), nil
}
```

## Why Pass tenant_id Explicitly AND in Context?

We pass `tenant_id` as an explicit parameter even though it's in context because:

1. **Function Signature Clarity** - Makes tenant requirement obvious
2. **Type Safety** - Compile-time checking vs runtime context extraction
3. **Testing** - Easier to mock and test without context setup
4. **Documentation** - Self-documenting code
5. **Defense in Depth** - Multiple validation points prevent bugs

Context is still used for:
- Request cancellation propagation
- Distributed tracing spans
- Request-scoped values (request_id)
- Logging context enrichment

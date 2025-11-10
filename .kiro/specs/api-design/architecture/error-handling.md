# Error Handling and Logging Best Practices

## Error Handling Strategy

All errors are logged with structured logging using `log/slog` at the layer where they occur, with context propagating up through the stack.

## Domain Error Types

Define custom error types in `internal/errors/errors.go`:

```go
package errors

import "fmt"

type ErrorType string

const (
    ErrorTypeValidation      ErrorType = "validation_error"
    ErrorTypeNotFound        ErrorType = "not_found"
    ErrorTypeUnauthorized    ErrorType = "unauthorized"
    ErrorTypeForbidden       ErrorType = "forbidden"
    ErrorTypeConflict        ErrorType = "conflict"
    ErrorTypeInternal        ErrorType = "internal_error"
)

type AppError struct {
    Type    ErrorType
    Message string
    Details map[string]interface{}
    Err     error // Wrapped error for logging
}

func (e *AppError) Error() string {
    if e.Err != nil {
        return fmt.Sprintf("%s: %s: %v", e.Type, e.Message, e.Err)
    }
    return fmt.Sprintf("%s: %s", e.Type, e.Message)
}

func (e *AppError) Unwrap() error {
    return e.Err
}

// Constructor functions
func NewValidationError(message string, details map[string]interface{}) *AppError {
    return &AppError{Type: ErrorTypeValidation, Message: message, Details: details}
}

func NewNotFoundError(resource string, id interface{}) *AppError {
    return &AppError{
        Type:    ErrorTypeNotFound,
        Message: fmt.Sprintf("%s not found", resource),
        Details: map[string]interface{}{"id": id},
    }
}

func NewForbiddenError(message string) *AppError {
    return &AppError{Type: ErrorTypeForbidden, Message: message}
}

func NewConflictError(message string, details map[string]interface{}) *AppError {
    return &AppError{Type: ErrorTypeConflict, Message: message, Details: details}
}

func NewInternalError(err error) *AppError {
    return &AppError{
        Type:    ErrorTypeInternal,
        Message: "Internal server error",
        Err:     err,
    }
}
```

## Error Logging by Layer

### Repository Layer

Log database errors with query context:

```go
func (r *TicketRepository) GetByID(ctx context.Context, tenantID, ticketID int64) (*Ticket, error) {
    ticket, err := r.queries.GetTicket(ctx, db.GetTicketParams{
        ID:       ticketID,
        TenantID: tenantID,
    })
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            // Don't log "not found" as error - it's expected
            r.logger.DebugContext(ctx, "ticket not found", 
                "tenant_id", tenantID,
                "ticket_id", ticketID,
                "operation", "GetByID",
            )
            return nil, apperrors.NewNotFoundError("ticket", ticketID)
        }
        
        // Log unexpected database errors
        r.logger.ErrorContext(ctx, "database query failed",
            "error", err,
            "tenant_id", tenantID,
            "ticket_id", ticketID,
            "operation", "GetByID",
            "query", "GetTicket",
        )
        return nil, apperrors.NewInternalError(err)
    }
    
    return mapToTicket(ticket), nil
}
```

### Service Layer

Log business logic errors with context:

```go
func (s *TicketService) TransitionTicket(ctx context.Context, tenantID, ticketID int64, transition string, employeeID int64) (*Ticket, error) {
    // Get ticket
    ticket, err := s.ticketRepo.GetByID(ctx, tenantID, ticketID)
    if err != nil {
        // Error already logged in repository
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
    
    // Get type definition for FSM validation
    typeDef, err := s.typeDefRepo.GetByID(ctx, ticket.TypeDefinitionID)
    if err != nil {
        s.logger.ErrorContext(ctx, "failed to get type definition",
            "error", err,
            "tenant_id", tenantID,
            "ticket_id", ticketID,
            "type_definition_id", ticket.TypeDefinitionID,
        )
        return nil, err
    }
    
    // Validate state transition
    valid, nextState, validTransitions := s.validateTransition(typeDef.FSMSchema, ticket.CurrentState, transition)
    if !valid {
        s.logger.WarnContext(ctx, "invalid state transition attempted",
            "tenant_id", tenantID,
            "ticket_id", ticketID,
            "current_state", ticket.CurrentState,
            "transition", transition,
            "valid_transitions", validTransitions,
            "employee_id", employeeID,
        )
        return nil, apperrors.NewConflictError("Invalid state transition", map[string]interface{}{
            "current_state":        ticket.CurrentState,
            "attempted_transition": transition,
            "valid_transitions":    validTransitions,
        })
    }
    
    // Perform transition in transaction
    updatedTicket, err := s.ticketRepo.UpdateState(ctx, tenantID, ticketID, nextState, employeeID)
    if err != nil {
        s.logger.ErrorContext(ctx, "failed to update ticket state",
            "error", err,
            "tenant_id", tenantID,
            "ticket_id", ticketID,
            "from_state", ticket.CurrentState,
            "to_state", nextState,
        )
        return nil, err
    }
    
    // Log successful transition
    s.logger.InfoContext(ctx, "ticket state transitioned",
        "tenant_id", tenantID,
        "ticket_id", ticketID,
        "from_state", ticket.CurrentState,
        "to_state", nextState,
        "transition", transition,
        "employee_id", employeeID,
    )
    
    // Publish event
    s.publishStateChangeEvent(ctx, tenantID, ticketID, ticket.CurrentState, nextState)
    
    return updatedTicket, nil
}
```

### Handler Layer

Map errors to HTTP responses and log request failures:

```go
func (h *TicketHandler) TransitionTicket(c *gin.Context) {
    ticketID, err := strconv.ParseInt(c.Param("id"), 10, 64)
    if err != nil {
        c.JSON(400, ErrorResponse{
            Error:   "validation_error",
            Message: "Invalid ticket ID",
        })
        return
    }
    
    var req TransitionRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, ErrorResponse{
            Error:   "validation_error",
            Message: err.Error(),
        })
        return
    }
    
    ctx := c.Request.Context()
    tenantID := middleware.MustGetTenantID(ctx)
    requestID := middleware.GetRequestID(ctx)
    
    ticket, err := h.ticketService.TransitionTicket(ctx, tenantID, ticketID, req.Transition, req.EmployeeID)
    if err != nil {
        // Map domain errors to HTTP responses
        statusCode, errResp := h.mapErrorToResponse(err)
        
        // Log handler-level context
        h.logger.ErrorContext(ctx, "request failed",
            "error", err,
            "request_id", requestID,
            "tenant_id", tenantID,
            "ticket_id", ticketID,
            "transition", req.Transition,
            "status_code", statusCode,
            "path", c.Request.URL.Path,
            "method", c.Request.Method,
        )
        
        c.JSON(statusCode, errResp)
        return
    }
    
    // Log successful request
    h.logger.InfoContext(ctx, "request completed",
        "request_id", requestID,
        "tenant_id", tenantID,
        "ticket_id", ticketID,
        "status_code", 200,
        "path", c.Request.URL.Path,
        "method", c.Request.Method,
    )
    
    c.JSON(200, ticket)
}

func (h *TicketHandler) mapErrorToResponse(err error) (int, ErrorResponse) {
    var appErr *apperrors.AppError
    if errors.As(err, &appErr) {
        switch appErr.Type {
        case apperrors.ErrorTypeValidation:
            return 400, ErrorResponse{
                Error:   string(appErr.Type),
                Message: appErr.Message,
                Details: appErr.Details,
            }
        case apperrors.ErrorTypeNotFound:
            return 404, ErrorResponse{
                Error:   string(appErr.Type),
                Message: appErr.Message,
                Details: appErr.Details,
            }
        case apperrors.ErrorTypeForbidden:
            return 403, ErrorResponse{
                Error:   string(appErr.Type),
                Message: appErr.Message,
            }
        case apperrors.ErrorTypeConflict:
            return 409, ErrorResponse{
                Error:   string(appErr.Type),
                Message: appErr.Message,
                Details: appErr.Details,
            }
        case apperrors.ErrorTypeInternal:
            // Don't expose internal error details to client
            return 500, ErrorResponse{
                Error:   "internal_error",
                Message: "An internal error occurred",
            }
        }
    }
    
    // Unknown error type
    return 500, ErrorResponse{
        Error:   "internal_error",
        Message: "An unexpected error occurred",
    }
}
```

## Middleware Error Logging

### Recovery Middleware

Log panics with full context:

```go
func Recovery(logger *slog.Logger) gin.HandlerFunc {
    return func(c *gin.Context) {
        defer func() {
            if err := recover(); err != nil {
                logger.Error("panic recovered",
                    "error", err,
                    "request_id", c.GetString("request_id"),
                    "path", c.Request.URL.Path,
                    "method", c.Request.Method,
                    "stack", string(debug.Stack()),
                )
                
                c.JSON(500, ErrorResponse{
                    Error:   "internal_error",
                    Message: "An internal error occurred",
                })
                c.Abort()
            }
        }()
        c.Next()
    }
}
```

### Request Logging Middleware

Log all requests with timing:

```go
func Logger(logger *slog.Logger) gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        path := c.Request.URL.Path
        
        c.Next()
        
        duration := time.Since(start)
        statusCode := c.Writer.Status()
        
        logLevel := slog.LevelInfo
        if statusCode >= 500 {
            logLevel = slog.LevelError
        } else if statusCode >= 400 {
            logLevel = slog.LevelWarn
        }
        
        logger.Log(c.Request.Context(), logLevel, "request completed",
            "request_id", c.GetString("request_id"),
            "method", c.Request.Method,
            "path", path,
            "status", statusCode,
            "duration_ms", duration.Milliseconds(),
            "tenant_id", c.GetInt64("tenant_id"),
            "client_ip", c.ClientIP(),
        )
    }
}
```

## HTTP Status Codes

- `200 OK` - Successful operation
- `201 Created` - Resource created
- `400 Bad Request` - Invalid request/validation error
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Resource not found
- `409 Conflict` - State transition conflict
- `429 Too Many Requests` - Rate limit exceeded
- `500 Internal Server Error` - Server error

## Error Response Structure

All errors include:
- `error` - Error type code
- `message` - Human-readable description
- `details` - Additional context (optional)

```go
type ErrorResponse struct {
    Error   string                 `json:"error"`
    Message string                 `json:"message"`
    Details map[string]interface{} `json:"details,omitempty"`
}
```

## Structured Logging Best Practices

### 1. Always Include Context

- `request_id` - For request tracing across services
- `tenant_id` - **CRITICAL** for multi-tenant operations (debugging, auditing, security)
- Resource IDs - ticket_id, queue_id, employee_id, etc.
- Operation context - What was being attempted

### 2. Use Appropriate Log Levels

- `Debug`: Detailed flow information (not found queries, cache hits/misses)
- `Info`: Successful operations, state changes, business events
- `Warn`: Invalid requests, business rule violations, tenant access attempts
- `Error`: System errors, database failures, panics, unexpected conditions

### 3. Log at the Source

Log errors where they occur, not just at handler:
- Repository: Database errors with query context
- Service: Business logic errors with domain context
- Handler: Request/response errors with HTTP context

### 4. Multi-Tenant Logging Requirements

- Pass `tenant_id` through all layers (handler → service → repository)
- Include `tenant_id` in every log statement for tenant-scoped operations
- Log tenant mismatches as security warnings
- Use tenant_id for log filtering and auditing

### 5. Sanitize Sensitive Data

Never log passwords, tokens, API keys, or PII:
- Redact email addresses in production logs
- Mask credit card numbers or payment info
- Don't log full custom_data if it contains sensitive fields

### 6. Use Structured Fields

Not string concatenation:
- ✅ `logger.Info("ticket created", "tenant_id", tenantID, "ticket_id", ticketID)`
- ❌ `logger.Info(fmt.Sprintf("ticket %d created for tenant %d", ticketID, tenantID))`

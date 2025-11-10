# API Design Document

## Overview

The VirtualQ REST API provides comprehensive queue management capabilities through a metadata-driven architecture. The API supports multi-tenant isolation, configurable workflows, and real-time state management.

## Architecture

### API Design Principles
- **RESTful**: Standard HTTP methods and status codes
- **Multi-tenant**: Tenant context required for data isolation
- **Metadata-driven**: Behavior controlled by TypeDefinition configurations
- **Real-time**: Webhook support for immediate updates
- **Consistent**: Uniform error handling and response formats

### Base URL Structure
```
https://api.virtualqueue.example.com/v1
```

### Authentication
- Bearer token authentication
- API key support for service-to-service calls
- Tenant context via X-Tenant-ID header or query parameter

### Technology Stack
- **Language**: Go 1.21+
- **Web Framework**: Gin
- **Database**: PostgreSQL 17+ (Neon-hosted) with sqlc for type-safe queries
- **Cache/Queue**: Redis for pub/sub and caching
- **Logging**: log/slog (structured logging)
- **Identifiers**: UUID v7 for time-sortable GUIDs

## Core Resource Hierarchy
```
Account (billing entity)
├── Tenant (business location)
│   ├── Queue (virtual line)
│   │   └── Ticket (queue item)
│   │       └── TicketItem (components)
│   ├── Employee (staff)
│   └── TypeDefinition (metadata)
└── Customer (end users)
```

## Detailed Documentation

### Architecture & Implementation
- **#[[file:architecture/layers.md]]** - Layered architecture, dependency injection, and initialization
- **#[[file:architecture/context-flow.md]]** - Multi-tenant context propagation and security
- **#[[file:architecture/error-handling.md]]** - Error handling patterns and logging best practices
- **#[[file:architecture/sqlc-guide.md]]** - Database access with sqlc (setup, queries, workflow)

### API Specifications
- **#[[file:rest-api.md]]** - Complete REST API endpoint reference
- **#[[file:openapi.yaml]]** - OpenAPI 3.0 specification for code generation

### Diagrams & Flows
- **#[[file:diagrams/sequence-diagrams.md]]** - Request flow diagrams for key use cases

## Data Models

### Core Endpoints Summary

#### Accounts API
- `GET /accounts` - List accounts
- `POST /accounts` - Create account
- `GET /accounts/{id}` - Get account details

#### Tenants API  
- `GET /tenants` - List all tenants (Requirement 6)
- `POST /tenants` - Create tenant
- `GET /tenants/{id}` - Get tenant details

#### Queues API
- `POST /queues` - Create queue
- `GET /queues` - List queues
- `GET /queues/{id}` - Get queue details

#### Tickets API
- `POST /tickets` - Create ticket
- `GET /tickets` - Search tickets
- `POST /tickets/{id}/transition` - State transition
- `POST /tickets/{id}/assign` - Assign employee

See **#[[file:rest-api.md]]** for complete endpoint documentation.

## Testing Strategy

### API Testing Approach
- **Unit Tests**: Individual endpoint validation
- **Integration Tests**: Multi-resource workflows
- **Contract Tests**: OpenAPI specification compliance
- **Performance Tests**: Response time and throughput
- **Security Tests**: Authentication and authorization

### Test Scenarios
- Multi-tenant data isolation
- State transition validation
- Webhook delivery
- Rate limiting behavior
- Error handling consistency

## Development Workflow

### Initial Setup
```bash
# Clone repository
git clone <repo-url>
cd virtualq-api

# Install dependencies
go mod download

# Setup database
make db-setup

# Generate sqlc code
make sqlc

# Run server
go run cmd/server/main.go
```

### Development Cycle
1. Update schema: Edit migrations or schema.sql
2. Run migrations: `make migrate-up`
3. Write SQL queries: Add to `internal/db/queries/*.sql`
4. Generate code: `make sqlc`
5. Implement business logic in services
6. Add handlers and routes
7. Test with integration tests

See **#[[file:architecture/sqlc-guide.md]]** for detailed sqlc workflow.

## Migration Plan

### Phase 1: Core Resources (Current)
- Accounts, Tenants, Customers, Employees
- TypeDefinitions with FSM validation
- Queues with basic configuration

### Phase 2: Queue Operations
- Ticket creation and state transitions
- Employee assignment and queue forwarding
- Basic search and filtering

### Phase 3: Advanced Features
- TicketItems with independent state machines
- Webhook notifications
- Advanced search and analytics
- Rate limiting and caching

### Phase 4: Production Readiness
- Performance optimization
- Monitoring and observability
- Load testing and scaling
- Security hardening

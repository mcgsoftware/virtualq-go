# API Design Specification

This directory contains the complete API design specification for the VirtualQ REST API, organized into modular documents for better maintainability.

## Core Specification Files

- **[requirements.md](requirements.md)** - User stories and acceptance criteria (EARS format)
- **[design.md](design.md)** - High-level architecture overview with references to detailed docs
- **[tasks.md](tasks.md)** - Implementation task checklist
- **[openapi.yaml](openapi.yaml)** - OpenAPI 3.0 specification for code generation

## Detailed Documentation

### Architecture
- **[architecture/layers.md](architecture/layers.md)** - Layered architecture, dependency injection, and initialization patterns
- **[architecture/context-flow.md](architecture/context-flow.md)** - Multi-tenant context propagation and security
- **[architecture/error-handling.md](architecture/error-handling.md)** - Error handling patterns and structured logging
- **[architecture/sqlc-guide.md](architecture/sqlc-guide.md)** - Database access with sqlc (setup, queries, workflow)

### API Reference
- **[rest-api.md](rest-api.md)** - Complete REST API endpoint reference with examples
- **[diagrams/sequence-diagrams.md](diagrams/sequence-diagrams.md)** - Mermaid sequence diagrams for key use cases

## Document Organization

The specification follows a modular structure:

```
.kiro/specs/api-design/
├── README.md                    # This file
├── requirements.md              # What we're building (user stories)
├── design.md                    # How we're building it (high-level)
├── tasks.md                     # Implementation checklist
├── openapi.yaml                 # Machine-readable API spec
├── rest-api.md                  # Human-readable API reference
├── architecture/                # Detailed architecture docs
│   ├── layers.md               # Layered architecture & DI
│   ├── context-flow.md         # Multi-tenant context
│   ├── error-handling.md       # Error patterns & logging
│   └── sqlc-guide.md           # Database access guide
└── diagrams/                    # Visual documentation
    └── sequence-diagrams.md    # Request flow diagrams
```

## How to Use This Spec

### For Implementation
1. Start with **requirements.md** to understand what needs to be built
2. Read **design.md** for the high-level architecture
3. Follow **tasks.md** for step-by-step implementation
4. Reference **architecture/** docs for implementation details
5. Use **openapi.yaml** for code generation

### For API Consumers
1. Start with **rest-api.md** for endpoint documentation
2. Use **openapi.yaml** to generate client libraries
3. Reference **diagrams/sequence-diagrams.md** to understand request flows

### For Code Review
1. Check **requirements.md** for acceptance criteria
2. Verify implementation matches **architecture/** patterns
3. Ensure error handling follows **architecture/error-handling.md**
4. Confirm multi-tenant isolation per **architecture/context-flow.md**

## Key Design Principles

- **Multi-Tenant**: Tenant isolation at every layer
- **Type-Safe**: sqlc for compile-time SQL validation
- **Fail-Fast**: Verify dependencies during startup
- **Observable**: Structured logging with tenant_id everywhere
- **Testable**: Dependency injection, no global state
- **RESTful**: Standard HTTP methods and status codes

## Related Documentation

- **Database Schema**: See `database/` directory for schema and migrations
- **Steering Files**: See `.kiro/steering/` for project-wide guidelines
- **Solution Overview**: See `.kiro/steering/solution-overview.md` for system architecture

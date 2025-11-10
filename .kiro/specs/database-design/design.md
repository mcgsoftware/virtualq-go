# Database Design Document

## Overview

The VirtualQ database uses a multi-tenant PostgreSQL schema with metadata-driven ticket types and configurable state machines. The design prioritizes performance for real-time queue operations while supporting extensive customization per tenant.

## Architecture

### Multi-Tenant Hierarchy
```
Account (billing entity)
└── Tenant (business location)
    └── Queue (virtual line)
        └── Ticket (queue items)
            └── TicketItem (components)
```

### Metadata-Driven Design
- **TypeDefinition** table defines available ticket types
- **fsm_schema** JSONB field stores state machine definitions
- **custom_fields_schema** JSONB field defines validation rules
- Tickets reference TypeDefinition for behavior and validation

## Components and Interfaces

### Core Tables

#### Account & Tenant Tables
- **Account**: Top-level billing and procurement entity
- **Tenant**: Business location with custom configuration
- **Queue**: Virtual queue within a tenant

#### Metadata Tables
- **TypeDefinition**: Defines ticket types and state machines
- Supports both system-defined and tenant-specific types
- Contains JSON Schema for custom field validation
- Stores finite state machine definitions

#### Operational Tables
- **Ticket**: Generic queue items with configurable states
- **TicketItem**: Components within tickets
- **Customer**: Queue participants
- **Employee**: Staff who fulfill tickets
- **TicketStateHistory**: Audit trail of state transitions

### State Machine Implementation

Based on [jakesgordon/javascript-state-machine](https://github.com/jakesgordon/javascript-state-machine/blob/master/docs/states-and-transitions.md) format:

```json
{
  "init": "received",
  "states": ["received", "in_progress", "ready", "completed"],
  "transitions": [
    {"name": "start", "from": "received", "to": "in_progress"},
    {"name": "complete", "from": "in_progress", "to": "ready"},
    {"name": "pickup", "from": "ready", "to": "completed"}
  ]
}
```

#### State Validation Process
1. Ticket state change requested
2. Load TypeDefinition.fsm_schema for ticket type
3. Validate transition from current_state to new_state
4. Update Ticket.current_state if valid
5. Record transition in TicketStateHistory
6. Throw error if invalid transition

## Data Models

### Key Entities

#### TypeDefinition
```sql
CREATE TABLE TypeDefinition (
    id serial PRIMARY KEY,
    extid UUID UNIQUE NOT NULL,
    tenant_id integer REFERENCES Tenant(id),  -- NULL = system-defined
    type_code varchar(32) NOT NULL,
    type_name varchar(100) NOT NULL,
    custom_fields_schema jsonb,  -- JSON Schema validation
    fsm_schema jsonb,            -- State machine definition
    is_system_defined boolean DEFAULT false
);
```

#### Ticket
```sql
CREATE TABLE Ticket (
    id serial PRIMARY KEY,
    extid UUID UNIQUE NOT NULL,
    queue_id integer NOT NULL REFERENCES Queue(id),
    type_definition_id integer NOT NULL REFERENCES TypeDefinition(id),
    current_state varchar(32) NOT NULL,  -- Validated against fsm_schema
    customer_id integer REFERENCES Customer(uid),
    employee_id integer REFERENCES Employee(id),
    custom_data jsonb,  -- Validated against custom_fields_schema
    estimated_wait_minutes integer,
    ttl_minutes integer,
    created_at timestamptz NOT NULL DEFAULT now()
);
```

### Indexing Strategy

#### Performance-Critical Indexes
```sql
-- Queue monitoring (most frequent queries)
CREATE INDEX idx_ticket_queue_state_created 
ON Ticket(queue_id, current_state, created_at DESC);

-- Employee dashboard
CREATE INDEX idx_ticket_employee_state 
ON Ticket(employee_id, current_state);

-- Multi-tenant isolation
CREATE INDEX idx_ticket_tenant_via_queue 
ON Ticket(queue_id) INCLUDE (type_definition_id);

-- JSONB custom data queries
CREATE INDEX idx_ticket_custom_data 
ON Ticket USING gin(custom_data);
```

## Error Handling

### State Transition Validation
- Invalid transitions throw constraint violations
- State machine schema validation on TypeDefinition updates
- Orphaned state handling for schema changes

### Multi-Tenant Isolation
- Row-level security policies (future enhancement)
- Application-level tenant filtering
- Foreign key constraints prevent cross-tenant references

### Data Integrity
- UUID uniqueness across all tables
- Referential integrity with cascading deletes where appropriate
- JSON Schema validation for custom fields

## Testing Strategy

### Unit Tests
- State machine validation logic
- JSON Schema validation
- UUID generation and uniqueness
- Multi-tenant data isolation

### Integration Tests
- Complete ticket lifecycle workflows
- Cross-tenant isolation verification
- Performance benchmarks for queue queries
- State transition audit trail accuracy

### Performance Tests
- Queue monitoring query performance (< 100ms for 1000 tickets)
- Concurrent state transition handling
- Database connection pooling under load
- Index effectiveness measurement
# Database Design Requirements

## Introduction

This spec defines the database schema design for VirtualQ's multi-tenant virtual queue management system. The database must support configurable ticket types, state machines, and tenant isolation while maintaining high performance for real-time queue operations.

## Glossary

- **VirtualQ_System**: The complete virtual queue management platform
- **Tenant**: A business location with custom configuration using the platform
- **Queue**: A virtual line within a tenant for managing tickets
- **Ticket**: A generic queue item (order, reservation, service request, etc.)
- **TypeDefinition**: Metadata defining ticket types and their state machines
- **State_Machine**: Configurable workflow defining valid state transitions

## Requirements

### Requirement 1

**User Story:** As a platform administrator, I want to support multiple tenants with isolated data, so that different businesses can use the same system without data conflicts.

#### Acceptance Criteria

1. WHEN a new tenant is created, THE VirtualQ_System SHALL isolate all tenant data from other tenants
2. THE VirtualQ_System SHALL support hierarchical tenancy with Account → Tenant relationships
3. THE VirtualQ_System SHALL prevent cross-tenant data access through database constraints
4. THE VirtualQ_System SHALL support tenant-specific customizations via JSONB fields
5. THE VirtualQ_System SHALL maintain referential integrity within tenant boundaries

### Requirement 2

**User Story:** As a tenant administrator, I want to define custom ticket types with different workflows, so that my business processes are properly modeled.

#### Acceptance Criteria

1. WHEN defining a ticket type, THE VirtualQ_System SHALL support custom field schemas via JSON Schema validation
2. THE VirtualQ_System SHALL allow configurable state machines per ticket type
3. THE VirtualQ_System SHALL validate state transitions against the defined state machine
4. THE VirtualQ_System SHALL support both system-defined and tenant-specific ticket types
5. THE VirtualQ_System SHALL maintain audit trails of all state transitions

### Requirement 3

**User Story:** As a queue operator, I want real-time access to ticket data, so that customers receive immediate status updates.

#### Acceptance Criteria

1. WHEN querying active tickets, THE VirtualQ_System SHALL return results within 100ms for up to 1000 tickets
2. THE VirtualQ_System SHALL support efficient filtering by queue, state, and tenant
3. THE VirtualQ_System SHALL provide optimized views for common monitor queries
4. THE VirtualQ_System SHALL use appropriate indexes for queue performance
5. THE VirtualQ_System SHALL support time-based queries for wait time calculations

### Requirement 4

**User Story:** As a system integrator, I want globally unique identifiers, so that data can be merged across systems without conflicts.

#### Acceptance Criteria

1. THE VirtualQ_System SHALL use UUID v7 for all primary external identifiers
2. THE VirtualQ_System SHALL ensure time-sortable ordering of identifiers
3. THE VirtualQ_System SHALL support efficient UUID storage and indexing
4. THE VirtualQ_System SHALL maintain both internal integer IDs and external UUIDs
5. THE VirtualQ_System SHALL prevent UUID collisions across all entities

### Requirement 5

**User Story:** As a business analyst, I want comprehensive audit trails, so that I can analyze queue performance and troubleshoot issues.

#### Acceptance Criteria

1. THE VirtualQ_System SHALL record all ticket state transitions with timestamps
2. THE VirtualQ_System SHALL track which employee performed each state change
3. THE VirtualQ_System SHALL maintain created_at and updated_at timestamps on all entities
4. THE VirtualQ_System SHALL support querying historical state changes
5. THE VirtualQ_System SHALL preserve audit data even when tickets are completed
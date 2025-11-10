# API Design Requirements

## Introduction

This spec defines the REST API requirements for VirtualQ's multi-tenant virtual queue management system. The API must support real-time queue operations, configurable workflows, and multi-tenant data isolation.

## Glossary

- **VirtualQ_API**: The REST API for the virtual queue management system
- **Tenant_Context**: Request scoping to isolate tenant data
- **State_Transition**: Validated change from one ticket state to another
- **Metadata_Driven**: API behavior controlled by TypeDefinition configurations

## Requirements

### Requirement 1

**User Story:** As an API consumer, I want consistent multi-tenant data isolation, so that tenant data remains secure and separated.

#### Acceptance Criteria

1. THE VirtualQ_API SHALL require tenant context for all tenant-scoped operations
2. THE VirtualQ_API SHALL support tenant context via X-Tenant-ID header or tenant_id parameter
3. THE VirtualQ_API SHALL prevent cross-tenant data access through API validation
4. THE VirtualQ_API SHALL return 403 Forbidden for unauthorized tenant access
5. THE VirtualQ_API SHALL scope all queries to the authenticated tenant context

### Requirement 2

**User Story:** As a queue management system, I want validated state transitions, so that ticket workflows remain consistent and predictable.

#### Acceptance Criteria

1. WHEN a state transition is requested, THE VirtualQ_API SHALL validate against TypeDefinition.fsm_schema
2. THE VirtualQ_API SHALL return 400 Bad Request for invalid state transitions
3. THE VirtualQ_API SHALL include valid transitions in error responses
4. THE VirtualQ_API SHALL record all state changes in TicketStateHistory
5. THE VirtualQ_API SHALL support both ticket-level and item-level state transitions

### Requirement 3

**User Story:** As a real-time application, I want efficient queue queries, so that monitors and apps can display current status without delays.

#### Acceptance Criteria

1. THE VirtualQ_API SHALL support filtering tickets by queue_id, current_state, and tenant_id
2. THE VirtualQ_API SHALL return queue queries within 200ms for up to 1000 active tickets
3. THE VirtualQ_API SHALL support pagination with configurable page sizes
4. THE VirtualQ_API SHALL provide ticket count endpoints for dashboard statistics
5. THE VirtualQ_API SHALL support real-time updates via webhooks

### Requirement 4

**User Story:** As a mobile application developer, I want comprehensive ticket management, so that customers can track their queue position and status.

#### Acceptance Criteria

1. THE VirtualQ_API SHALL support creating tickets with custom_data validation
2. THE VirtualQ_API SHALL provide ticket history with complete state transition logs
3. THE VirtualQ_API SHALL support ticket forwarding between queues
4. THE VirtualQ_API SHALL allow ticket position reordering for priority handling
5. THE VirtualQ_API SHALL support ticket cancellation with proper state transitions

### Requirement 5

**User Story:** As an integration developer, I want OpenAPI specification, so that I can generate client libraries and documentation automatically.

#### Acceptance Criteria

1. THE VirtualQ_API SHALL provide complete OpenAPI 3.0 specification
2. THE VirtualQ_API SHALL include request/response schemas for all endpoints
3. THE VirtualQ_API SHALL document authentication and authorization requirements
4. THE VirtualQ_API SHALL include example requests and responses
5. THE VirtualQ_API SHALL support code generation for multiple programming languages

### Requirement 6

**User Story:** As an account administrator, I want to retrieve all tenants for my account, so that I can view and manage all business locations.

#### Acceptance Criteria

1. THE VirtualQ_API SHALL provide a GET /tenants endpoint
2. THE VirtualQ_API SHALL return all tenants accessible to the authenticated user
3. THE VirtualQ_API SHALL support filtering tenants by account_id parameter
4. THE VirtualQ_API SHALL return tenant details including id, extid, name, location information, and active status
5. THE VirtualQ_API SHALL support pagination for tenant lists with configurable page sizes
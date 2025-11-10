# Request Flow Sequence Diagrams

This document contains Mermaid sequence diagrams showing how requests flow through the VirtualQ API for key use cases.

## Use Case 1: GET /tenants - List All Tenants

```mermaid
sequenceDiagram
    participant Client
    participant API as API Server
    participant Auth as Auth Middleware
    participant Handler as Tenants Handler
    participant Service as Tenant Service
    participant Repo as Tenant Repository
    participant DB as PostgreSQL

    Client->>API: GET /tenants?account_id=123
    API->>Auth: Validate Bearer Token
    Auth->>Auth: Extract User Context
    Auth->>Handler: Request + User Context
    Handler->>Handler: Parse Query Params
    Handler->>Service: GetTenants(accountID, page, limit)
    Service->>Service: Validate Access Permissions
    Service->>Repo: FindTenantsByAccount(accountID, page, limit)
    Repo->>DB: SELECT * FROM tenants WHERE account_id=$1
    DB-->>Repo: Tenant Rows
    Repo-->>Service: []Tenant
    Service->>Repo: CountTenants(accountID)
    Repo->>DB: SELECT COUNT(*) FROM tenants WHERE account_id=$1
    DB-->>Repo: Total Count
    Repo-->>Service: Count
    Service-->>Handler: TenantList + Pagination
    Handler-->>API: JSON Response (200 OK)
    API-->>Client: {"data": [...], "pagination": {...}}
```

## Use Case 2: POST /tickets - Create New Ticket

```mermaid
sequenceDiagram
    participant Client
    participant API as API Server
    participant Auth as Auth Middleware
    participant Handler as Tickets Handler
    participant Service as Ticket Service
    participant TypeDefRepo as TypeDef Repository
    participant QueueRepo as Queue Repository
    participant TicketRepo as Ticket Repository
    participant DB as PostgreSQL
    participant Redis

    Client->>API: POST /tickets<br/>{queue_id, type_def_id, custom_data}
    API->>Auth: Validate Token + X-Tenant-ID
    Auth->>Handler: Request + Tenant Context
    Handler->>Handler: Validate Request Body
    Handler->>Service: CreateTicket(tenantID, ticketData)
    
    Service->>TypeDefRepo: GetTypeDefinition(typeDefID)
    TypeDefRepo->>DB: SELECT * FROM type_definitions WHERE id=$1
    DB-->>TypeDefRepo: TypeDefinition + fsm_schema
    TypeDefRepo-->>Service: TypeDefinition
    
    Service->>Service: Validate custom_data against JSON Schema
    
    Service->>QueueRepo: GetQueue(queueID)
    QueueRepo->>DB: SELECT * FROM queues WHERE id=$1
    DB-->>QueueRepo: Queue
    QueueRepo-->>Service: Queue
    
    Service->>Service: Verify queue allows ticket type
    Service->>Service: Calculate initial state from fsm_schema
    Service->>Service: Generate UUID v7 for extid
    
    Service->>TicketRepo: CreateTicket(ticket)
    TicketRepo->>DB: INSERT INTO tickets (...)
    DB-->>TicketRepo: Ticket ID
    TicketRepo-->>Service: Created Ticket
    
    Service->>Redis: PUBLISH ticket.created event
    Redis-->>Service: OK
    
    Service-->>Handler: Created Ticket
    Handler-->>API: JSON Response (201 Created)
    API-->>Client: {"id": 1001, "extid": "...", ...}
```

## Use Case 3: POST /tickets/{id}/transition - State Transition

```mermaid
sequenceDiagram
    participant Client
    participant API as API Server
    participant Auth as Auth Middleware
    participant Handler as Tickets Handler
    participant Service as Ticket Service
    participant TicketRepo as Ticket Repository
    participant TypeDefRepo as TypeDef Repository
    participant HistoryRepo as History Repository
    participant DB as PostgreSQL
    participant Redis

    Client->>API: POST /tickets/1001/transition<br/>{transition: "start_preparation"}
    API->>Auth: Validate Token + Tenant Context
    Auth->>Handler: Request + Tenant Context
    Handler->>Service: TransitionTicket(ticketID, transition, employeeID)
    
    Service->>TicketRepo: GetTicket(ticketID)
    TicketRepo->>DB: SELECT * FROM tickets WHERE id=$1
    DB-->>TicketRepo: Ticket
    TicketRepo-->>Service: Ticket (current_state: "received")
    
    Service->>Service: Verify tenant_id matches
    
    Service->>TypeDefRepo: GetTypeDefinition(typeDefID)
    TypeDefRepo->>DB: SELECT * FROM type_definitions WHERE id=$1
    DB-->>TypeDefRepo: TypeDefinition + fsm_schema
    TypeDefRepo-->>Service: fsm_schema
    
    Service->>Service: Validate Transition<br/>("received" -> "start_preparation" -> "in_progress")
    
    alt Valid Transition
        Service->>DB: BEGIN TRANSACTION
        
        Service->>TicketRepo: UpdateTicketState(ticketID, "in_progress", employeeID)
        TicketRepo->>DB: UPDATE tickets SET current_state=$1, employee_id=$2
        DB-->>TicketRepo: OK
        
        Service->>HistoryRepo: RecordTransition(ticketID, from, to, transition)
        HistoryRepo->>DB: INSERT INTO ticket_state_history (...)
        DB-->>HistoryRepo: OK
        
        Service->>DB: COMMIT TRANSACTION
        
        Service->>Redis: PUBLISH ticket.state_changed event
        Redis-->>Service: OK
        
        Service-->>Handler: Updated Ticket
        Handler-->>API: JSON Response (200 OK)
        API-->>Client: {"id": 1001, "current_state": "in_progress", ...}
    else Invalid Transition
        Service-->>Handler: ValidationError
        Handler-->>API: JSON Response (400 Bad Request)
        API-->>Client: {"error": "validation_error", "details": {...}}
    end
```

## Key Patterns Illustrated

### Multi-Tenant Context Flow
All diagrams show how tenant_id flows through:
1. Extracted from X-Tenant-ID header in middleware
2. Passed explicitly to service layer
3. Used in repository for SQL WHERE clauses
4. Logged at every layer for observability

### Error Handling
The state transition diagram shows both success and error paths, demonstrating:
- Validation before database operations
- Transaction management for consistency
- Proper error responses with details

### Event Publishing
Both create and transition flows show Redis pub/sub for real-time updates to:
- Wall monitors
- Mobile apps
- Other services

### Defense in Depth
Multiple validation points:
- Middleware: Authentication and tenant access
- Handler: Request validation
- Service: Business logic validation (tenant ownership, FSM transitions)
- Repository: SQL-level tenant isolation

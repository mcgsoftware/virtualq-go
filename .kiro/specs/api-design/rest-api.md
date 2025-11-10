# Virtual Queue System - REST API Reference

## Overview

The Virtual Queue System provides a comprehensive REST API for managing virtual queues across multiple tenants and locations. The API is designed around a metadata-driven architecture where ticket types, workflows, and state machines are configurable through the TypeDefinitions resource.

**Base URL**: `https://api.virtualqueue.example.com/v1`

**Key Features**:
- Multi-tenant architecture (Account → Tenant → Queue hierarchy)
- Metadata-driven ticket types with configurable state machines
- Flexible composition (tickets can contain items with independent states)
- Workflow chaining (tickets can reference other tickets)
- Real-time state transitions with validation

---

## Authentication

All API requests require authentication via API key or Bearer token.

**Header**:
```
Authorization: Bearer YOUR_API_TOKEN
```

**Tenant Context**:
Most endpoints require a `tenant_id` parameter or header to scope operations to a specific tenant.

---

## Accounts API

Accounts represent the top-level billing entity. One account can have multiple tenants (locations).

| P | HTTP Method | Endpoint | Description |
|---|-------------|----------|-------------|
| | GET | `/accounts` | List all accounts accessible to the authenticated user |
| | GET | `/accounts/{id}` | Get detailed information about a specific account |
| | POST | `/accounts` | Create a new account (admin only) |
| | PUT | `/accounts/{id}` | Update account details |
| | GET | `/accounts/{id}/tenants` | List all tenants belonging to this account |

**Example: Get Account Details**
```http
GET /accounts/123
```

**Response**:
```json
{
  "id": 123,
  "extid": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Coffee Chain Corp",
  "billing_email": "billing@coffeechain.com",
  "is_active": true,
  "created_at": "2025-01-15T10:00:00Z"
}
```

---

## Tenants API

Tenants represent unique product implementations for specific locations or business units (e.g., "Downtown Seattle Coffee", "Seattle DMV Office").

**Note**: In the competitor's model, these are called "Locations."

| P | HTTP Method | Endpoint | Description |
|---|-------------|----------|-------------|
| | GET | `/tenants` | List all tenants for the authenticated account |
| | GET | `/tenants/{id}` | Get detailed information about a specific tenant |
| | POST | `/tenants` | Create a new tenant |
| | PUT | `/tenants/{id}` | Update tenant details |
| | DELETE | `/tenants/{id}` | Deactivate a tenant (soft delete) |
| | GET | `/tenants/{id}/queues` | Get all queues for this tenant |
| | GET | `/tenants/{id}/employees` | Get all employees for this tenant |
| | GET | `/tenants/{id}/type-definitions` | Get ticket type definitions for this tenant |

**Example: Create Tenant**
```http
POST /tenants
```

**Request Body**:
```json
{
  "account_id": 123,
  "name": "Downtown Seattle Coffee",
  "location_name": "Downtown Seattle Store",
  "location_address": "123 Pike St, Seattle, WA 98101",
  "location_coordinates": {
    "latitude": 47.6062,
    "longitude": -122.3321
  },
  "config": {
    "theme": "coffee-light",
    "show_wait_times": true
  }
}
```

**Response**:
```json
{
  "id": 456,
  "extid": "650e8400-e29b-41d4-a716-446655440001",
  "account_id": 123,
  "name": "Downtown Seattle Coffee",
  "location_name": "Downtown Seattle Store",
  "location_address": "123 Pike St, Seattle, WA 98101",
  "is_active": true,
  "created_at": "2025-01-15T10:30:00Z"
}
```

---

## TypeDefinitions API

TypeDefinitions define the metadata for ticket types, including state machines, custom fields schemas, and composition rules. This is a key differentiator from simpler queue systems.

**Note**: This resource does not exist in the competitor's model.

| P | HTTP Method | Endpoint | Description |
|---|-------------|----------|-------------|
| | POST | `/type-definitions` | Create a new ticket type definition |
| | GET | `/type-definitions` | List all type definitions (system + tenant-specific) |
| | GET | `/type-definitions/{id}` | Get detailed information about a type definition |
| | PUT | `/type-definitions/{id}` | Update a type definition |
| | DELETE | `/type-definitions/{id}` | Deactivate a type definition |

**Example: Create Ticket Type Definition**
```http
POST /type-definitions
```

**Request Body**:
```json
{
  "tenant_id": 456,
  "type_code": "food_order",
  "type_name": "Food Order",
  "description": "Customer food and beverage order",
  "doc": "# Food Order Workflow\n\nHandles mobile and in-store orders...",
  "custom_fields_schema": {
    "type": "object",
    "properties": {
      "order_type": {
        "type": "string",
        "enum": ["mobile", "in-store", "drive-thru"]
      },
      "total_amount": {
        "type": "number"
      }
    }
  },
  "fsm_schema": {
    "init": "received",
    "states": ["received", "in_progress", "ready", "picked_up", "cancelled"],
    "transitions": [
      {"name": "start_preparation", "from": "received", "to": "in_progress"},
      {"name": "mark_ready", "from": "in_progress", "to": "ready"},
      {"name": "pickup", "from": "ready", "to": "picked_up"}
    ]
  },
  "item_definition_ids": [789]
}
```

**Response**:
```json
{
  "id": 101,
  "extid": "750e8400-e29b-41d4-a716-446655440002",
  "tenant_id": 456,
  "type_code": "food_order",
  "type_name": "Food Order",
  "fsm_schema": { ... },
  "is_active": true,
  "created_at": "2025-01-15T11:00:00Z"
}
```

---

## Queues API

Queues represent virtual waiting lines within a tenant. Each queue can accept specific ticket types.

**Note**: In the competitor's model, these are called "Lines."

| P | HTTP Method | Endpoint | Description |
|---|-------------|----------|-------------|
| | POST | `/queues` | Create a new queue |
| | GET | `/queues` | List all queues (filterable by tenant) |
| | GET | `/queues/{id}` | Get detailed information about a specific queue |
| | PUT | `/queues/{id}` | Update queue settings |
| | POST | `/queues/{id}/enable` | Enable a disabled queue |
| | POST | `/queues/{id}/disable` | Disable a queue (no new tickets accepted) |
| | DELETE | `/queues/{id}` | Archive/delete a queue |
| | GET | `/queues/{id}/tickets` | Get all active tickets in this queue |

**Example: Create Queue**
```http
POST /queues
```

**Request Body**:
```json
{
  "tenant_id": 456,
  "name": "Main Queue",
  "description": "Main ordering queue for mobile and in-store",
  "allowed_type_definition_ids": [101],
  "wait_estimation_method": "average_recent_3",
  "show_wait_time": true,
  "max_wait_minutes": 60,
  "display_order": 1
}
```

**Response**:
```json
{
  "id": 201,
  "extid": "850e8400-e29b-41d4-a716-446655440003",
  "tenant_id": 456,
  "name": "Main Queue",
  "allowed_type_definition_ids": [101],
  "wait_estimation_method": "average_recent_3",
  "is_active": true,
  "created_at": "2025-01-15T11:30:00Z"
}
```

**Example: Disable Queue**
```http
POST /queues/201/disable
```

**Response**:
```json
{
  "id": 201,
  "is_active": false,
  "updated_at": "2025-01-15T12:00:00Z"
}
```

---

## Employees API

Employees represent staff members who fulfill tickets. Each employee is scoped to a specific tenant.

**Note**: In the competitor's model, these are called "Users."

| P | HTTP Method | Endpoint | Description |
|---|-------------|----------|-------------|
| | POST | `/employees` | Create a new employee |
| | GET | `/employees` | List all employees (filterable by tenant) |
| | GET | `/employees/{id}` | Get detailed information about an employee |
| | PUT | `/employees/{id}` | Update employee details |
| | DELETE | `/employees/{id}` | Deactivate an employee |
| | POST | `/employees/{id}/assign-queues` | Assign employee to specific queues |
| | GET | `/employees/{id}/tickets` | Get tickets assigned to this employee |

**Example: Create Employee**
```http
POST /employees
```

**Request Body**:
```json
{
  "tenant_id": 456,
  "fname": "Sarah",
  "lname": "Johnson",
  "email": "sarah.j@coffee-seattle.com",
  "role": "barista"
}
```

**Response**:
```json
{
  "id": 301,
  "extid": "950e8400-e29b-41d4-a716-446655440004",
  "tenant_id": 456,
  "fname": "Sarah",
  "lname": "Johnson",
  "email": "sarah.j@coffee-seattle.com",
  "role": "barista",
  "is_active": true,
  "created_at": "2025-01-15T12:30:00Z"
}
```

**Example: Assign Employee to Queues**
```http
POST /employees/301/assign-queues
```

**Request Body**:
```json
{
  "queue_ids": [201, 202]
}
```

---

## Tickets API

Tickets represent individual queue entries (e.g., customer orders, service requests). Tickets are metadata-driven with states defined by their TypeDefinition.

| P | HTTP Method | Endpoint | Description |
|---|-------------|----------|-------------|
| | POST | `/tickets` | Create a new ticket (add to queue) |
| | GET | `/tickets` | Search/list tickets with filters |
| | POST | `/tickets/count` | Count tickets matching criteria |
| | GET | `/tickets/{id}` | Get detailed information about a ticket |
| | PUT | `/tickets/{id}` | Update ticket data (custom_data, etc.) |
| | POST | `/tickets/{id}/transition` | Trigger a state transition (e.g., call, serve) |
| | POST | `/tickets/{id}/assign` | Assign ticket to an employee |
| | POST | `/tickets/{id}/unassign` | Remove employee assignment |
| | POST | `/tickets/{id}/forward` | Forward ticket to another queue |
| | POST | `/tickets/{id}/reorder` | Change ticket position in queue |
| | DELETE | `/tickets/{id}` | Remove ticket from queue (cancel) |
| | GET | `/tickets/{id}/history` | Get state transition history |
| | GET | `/tickets/{id}/items` | Get all items within this ticket |

**Example: Create Ticket**
```http
POST /tickets
```

**Request Body**:
```json
{
  "queue_id": 201,
  "type_definition_id": 101,
  "customer_id": 501,
  "custom_data": {
    "order_type": "mobile",
    "total_amount": 15.50,
    "special_instructions": "Extra hot"
  },
  "estimated_wait_minutes": 10
}
```

**Response**:
```json
{
  "id": 1001,
  "extid": "a50e8400-e29b-41d4-a716-446655440005",
  "queue_id": 201,
  "type_definition_id": 101,
  "current_state": "received",
  "customer_id": 501,
  "custom_data": {
    "order_type": "mobile",
    "total_amount": 15.50
  },
  "estimated_wait_minutes": 10,
  "created_at": "2025-01-15T13:00:00Z"
}
```

**Example: Trigger State Transition**
```http
POST /tickets/1001/transition
```

**Request Body**:
```json
{
  "transition": "start_preparation",
  "employee_id": 301
}
```

**Response**:
```json
{
  "id": 1001,
  "current_state": "in_progress",
  "employee_id": 301,
  "started_at": "2025-01-15T13:05:00Z",
  "previous_state": "received"
}
```

**Example: Search Tickets**
```http
GET /tickets?queue_id=201&current_state=in_progress&limit=10
```

**Response**:
```json
{
  "tickets": [
    {
      "id": 1001,
      "extid": "a50e8400-e29b-41d4-a716-446655440005",
      "current_state": "in_progress",
      "customer_id": 501,
      "created_at": "2025-01-15T13:00:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "limit": 10
}
```

**Example: Forward Ticket to Another Queue**
```http
POST /tickets/1001/forward
```

**Request Body**:
```json
{
  "target_queue_id": 202,
  "reason": "Customer requested express pickup"
}
```

**Example: Count Tickets**
```http
POST /tickets/count
```

**Request Body**:
```json
{
  "queue_id": 201,
  "current_state": "received"
}
```

**Response**:
```json
{
  "count": 5
}
```

---

## TicketItems API

TicketItems represent individual components within a ticket (e.g., drinks and food items in a food order). Items can have their own state machines independent of the parent ticket.

**Note**: This resource does not exist in the competitor's model and is unique to this metadata-driven architecture.

| P | HTTP Method | Endpoint | Description |
|---|-------------|----------|-------------|
| | POST | `/tickets/{ticketId}/items` | Add a new item to a ticket |
| | GET | `/tickets/{ticketId}/items` | List all items in a ticket |
| | GET | `/items/{id}` | Get detailed information about a specific item |
| | PUT | `/items/{id}` | Update item details |
| | POST | `/items/{id}/transition` | Trigger item state transition |
| | DELETE | `/items/{id}` | Remove item from ticket |

**Example: Add Item to Ticket**
```http
POST /tickets/1001/items
```

**Request Body**:
```json
{
  "item_type_definition_id": 789,
  "external_item_id": "menu-item-uuid-123",
  "external_item_name": "Venti Latte",
  "quantity": 1,
  "unit_price": 5.25,
  "custom_data": {
    "customizations": ["extra hot", "oat milk"]
  }
}
```

**Response**:
```json
{
  "id": 5001,
  "extid": "b50e8400-e29b-41d4-a716-446655440006",
  "ticket_id": 1001,
  "item_type_definition_id": 789,
  "current_state": "pending",
  "external_item_name": "Venti Latte",
  "quantity": 1,
  "unit_price": 5.25,
  "custom_data": {
    "customizations": ["extra hot", "oat milk"]
  },
  "created_at": "2025-01-15T13:00:00Z"
}
```

**Example: Transition Item State**
```http
POST /items/5001/transition
```

**Request Body**:
```json
{
  "transition": "start_item"
}
```

**Response**:
```json
{
  "id": 5001,
  "current_state": "in_progress",
  "previous_state": "pending",
  "started_at": "2025-01-15T13:05:00Z"
}
```

**Example: Get All Items in Ticket**
```http
GET /tickets/1001/items
```

**Response**:
```json
{
  "items": [
    {
      "id": 5001,
      "current_state": "in_progress",
      "external_item_name": "Venti Latte",
      "quantity": 1
    },
    {
      "id": 5002,
      "current_state": "pending",
      "external_item_name": "Chocolate Croissant",
      "quantity": 1
    }
  ]
}
```

---

## Customers API

Customers represent end users who create tickets in virtual queues.

| P | HTTP Method | Endpoint | Description |
|---|-------------|----------|-------------|
| | POST | `/customers` | Create a new customer |
| | GET | `/customers` | List all customers |
| | GET | `/customers/{id}` | Get customer details |
| | PUT | `/customers/{id}` | Update customer information |
| | GET | `/customers/{id}/tickets` | Get all tickets for this customer |

**Example: Create Customer**
```http
POST /customers
```

**Request Body**:
```json
{
  "fname": "John",
  "lname": "Smith",
  "email": "john.smith@email.com",
  "phone": "555-0101"
}
```

**Response**:
```json
{
  "uid": 501,
  "extid": "c50e8400-e29b-41d4-a716-446655440007",
  "fname": "John",
  "lname": "Smith",
  "email": "john.smith@email.com",
  "phone": "555-0101",
  "is_active": true,
  "created_at": "2025-01-15T12:00:00Z"
}
```

---

## Common Patterns

### Multi-Tenancy

Most resources require tenant context:

**Query Parameter**:
```http
GET /tickets?tenant_id=456
```

**Header** (alternative):
```http
X-Tenant-ID: 456
```

### State Transitions

State transitions are validated against the ticket type's `fsm_schema`:

**Valid Transition**:
```http
POST /tickets/1001/transition
{
  "transition": "start_preparation"
}
```

**Invalid Transition** (returns 400):
```http
POST /tickets/1001/transition
{
  "transition": "pickup"
}
// Error: Cannot transition from 'received' to 'pickup'
```

### Pagination

List endpoints support pagination:

```http
GET /tickets?page=1&limit=20
```

**Response**:
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "total_pages": 8
  }
}
```

### Filtering

Common filters across resources:

- `tenant_id` - Filter by tenant
- `is_active` - Filter by active status
- `created_after` / `created_before` - Date range filters

**Example**:
```http
GET /tickets?tenant_id=456&current_state=ready&created_after=2025-01-15T00:00:00Z
```

### Workflow Chaining

Tickets can reference other tickets via `references_ticket_id`:

```http
POST /tickets
{
  "queue_id": 202,
  "type_definition_id": 150,
  "references_ticket_id": 1001,
  "custom_data": {
    "delivery_address": "123 Main St"
  }
}
```

---

## Error Responses

All errors follow a consistent format:

**400 Bad Request**:
```json
{
  "error": "validation_error",
  "message": "Invalid state transition: cannot transition from 'received' to 'picked_up'",
  "details": {
    "transition": "pickup",
    "current_state": "received",
    "valid_transitions": ["start_preparation", "cancel_new"]
  }
}
```

**404 Not Found**:
```json
{
  "error": "not_found",
  "message": "Ticket with id 9999 not found"
}
```

**403 Forbidden**:
```json
{
  "error": "forbidden",
  "message": "Insufficient permissions to access this tenant"
}
```

---

## Webhooks

The system supports webhooks for real-time notifications:

**Events**:
- `ticket.created`
- `ticket.state_changed`
- `ticket.assigned`
- `ticket.completed`
- `item.state_changed`
- `queue.enabled`
- `queue.disabled`

**Webhook Payload Example** (`ticket.state_changed`):
```json
{
  "event": "ticket.state_changed",
  "timestamp": "2025-01-15T13:05:00Z",
  "data": {
    "ticket_id": 1001,
    "queue_id": 201,
    "previous_state": "received",
    "new_state": "in_progress",
    "employee_id": 301
  }
}
```

---

## Rate Limits

- **Standard**: 100 requests per minute per API key
- **Burst**: 200 requests per minute (short bursts)
- **Rate limit headers included in all responses**:
  - `X-RateLimit-Limit`
  - `X-RateLimit-Remaining`
  - `X-RateLimit-Reset`

---

## See Also

- [Database Design](database-design.md) - Complete schema documentation
- [Starbucks Example](../schema/starbucks-example-data.sql) - Sample data for coffee shop use case
- [DMV Example](../schema/dmv-example-data.sql) - Sample data for DMV office use case

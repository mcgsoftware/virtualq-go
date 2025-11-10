---
inclusion: always
---

# System Architecture

## Core Domain Model

The system tracks tickets through configurable state machines:
- Default: `received` → `in-progress` → `ready` → `completed`
- Tenant-customizable via TypeDefinition.fsm_schema

Key entities:
- **Ticket**: Generic queue item (orders, reservations, service requests)
- **TicketItem**: Individual components within tickets
- **Queue**: Virtual line within a tenant
- **Tenant**: Business location with custom configuration

## Service Architecture

### Core Services
- **POS API**: Ticket management and processing (Java/Spring Boot)
- **Status Monitor API**: Real-time status updates (Go/Gin)
- **Customer App**: Ticket creation and tracking (React Native)
- **Employee App**: Ticket fulfillment workflow (React Native)
- **Wall Monitor**: Public status display (React)

### Infrastructure
- **Database**: PostgreSQL with multi-tenant schema
- **Cache/Queue**: Redis for real-time events and caching
- **API Pattern**: RESTful services with event-driven updates 

## Core Workflows

### Customer Journey
1. **Join Queue**: Create ticket via app or kiosk
2. **Track Status**: Monitor position and estimated wait time
3. **Receive Notifications**: Get alerts when service is ready
4. **Complete Service**: Fulfill ticket and exit queue

### Employee Workflow
1. **View Queue**: See pending tickets sorted by priority
2. **Start Ticket**: Begin fulfillment (state transition)
3. **Complete Ticket**: Mark as ready/complete
4. **Manage Queue**: Handle priorities and timing

### Status Broadcasting
- Real-time updates via Redis pub/sub
- Wall monitor displays current queue status
- Push notifications for status changes

## Technology Stack

### Backend Services
- **POS API**: Java 21, Spring Boot 3.5.7, Maven
- **Status Monitor API**: Go, Gin, sqlc
- **Database**: PostgreSQL 17+ (Neon-hosted)
- **Cache/Queue**: Redis
- **Identifiers**: UUID v7 for time-sortable GUIDs

### Frontend Applications
- **Web Monitor**: React
- **Mobile Apps**: React Native
- **Push Notifications**: TBD

## Development Constraints

- SDD tools work best on focused, single-service implementations
- Complex multi-service projects need to be partitioned for effective AI assistance
- Prioritize working features over comprehensive system coverage 
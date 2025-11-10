# Tenant Use Cases

This document provides detailed examples of how VirtualQ will be used by different types of businesses.

## Starbucks-Style Coffee Shop

### Overview
Coffee shops need to manage order queues for mobile and in-store customers, providing real-time status updates on order preparation.

### Key Features
- Order status tracking: received → in-progress → ready
- Wall-mounted status monitors
- Mobile app notifications
- Barista workflow management

### Workflow
1. Customer places order (mobile app or in-store)
2. Order appears in barista queue
3. Barista "pulls ticket" to start preparation
4. Status updates broadcast to monitors and mobile apps
5. Customer notified when order is ready

### Special Considerations
- Drive-thru orders excluded from public monitors
- Multiple baristas can work simultaneously
- Partial order completion handling
- Ticket pulling training requirements

For detailed analysis, see: [Starbucks Case Study](../docs/starbucks-case-study.md)

## DMV Service Center

### Overview
Government service centers managing multiple service types with long wait times and complex workflows.

### Key Features
- Multiple queue types: Registration, Licenses, Testing, Other
- Pre-validation workflows
- Employee assignment by specialization
- Estimated wait times

### Configuration
- Account: DMV State Services (North Florida)
- 27 locations with identical queue configurations
- Custom ticket types per service area
- Integration with existing DMV systems

### Workflow
1. Citizen selects service type and joins queue
2. System validates required documentation
3. Pre-check determines readiness status
4. Employee pulls ticket when ready
5. Service completion updates system

### Special Considerations
- Citizens can leave and return without losing position
- Complex state validation requirements
- Integration with legacy DMV systems
- Compliance and audit trail requirements

## Cruise Ship Restaurant

### Overview
Shipboard dining with limited space and captive audience requiring efficient queue management.

### Key Features
- Table reservations and food orders
- Cabin number integration
- Dietary restriction tracking
- Multi-language support

### Configuration
- Tenant per restaurant/dining venue
- Mixed queue types (reservations + orders)
- Passenger identification via cabin numbers
- Shore excursion coordination

## Implementation Priority

1. **Phase 1**: Coffee shop use case (simpler workflow)
2. **Phase 2**: DMV use case (complex multi-queue)
3. **Phase 3**: Specialized use cases (cruise ship, etc.)

Each use case will serve as a validation point for the platform's flexibility and multi-tenant capabilities.
---
inclusion: always
---

# Database State Machine Pattern

## Core Principle

Use metadata-driven state machines stored in the database to enable tenant-customizable workflows without hardcoding business logic.

## Implementation Pattern

- **TypeDefinition.fsm_schema**: JSONB field storing state machine definition
- **Ticket.current_state**: Current state value validated against fsm_schema
- **State transitions**: Validated at API level, not in workflow engine
- **External systems**: Handle business logic, call API for state changes

## State Machine Format

Use [jakesgordon/javascript-state-machine](https://github.com/jakesgordon/javascript-state-machine) JSON format:

```json
{
  "init": "received",
  "states": ["received", "in_progress", "ready"],
  "transitions": [
    {"name": "start", "from": "received", "to": "in_progress"},
    {"name": "complete", "from": "in_progress", "to": "ready"}
  ]
}
```

## Design Benefits

- **Tenant customization**: Each ticket type can have unique workflows
- **Validation**: Prevents invalid state transitions
- **Audit trail**: All transitions recorded in TicketStateHistory
- **Flexibility**: External systems handle business logic, database ensures consistency

For detailed implementation, see: `#[[file:.kiro/specs/database-design/design.md]]` 
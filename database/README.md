# Database Schema

This directory contains the database schema and related database artifacts for VirtualQ.

## Files

- `schema.sql` - Complete PostgreSQL schema with tables, indexes, views, and triggers
- `example-data.sql` - Sample data for testing (accounts, tenants, tickets, etc.)
- `migrations/` - Database migration scripts (future)
- `seeds/` - Additional seed data files (future)

## Database instance notes 
This will be using a 3rd party hosted PostgreSQL instance. 

Neon Website: https://neon.tech/
A hosted postgres db with vectors.

I used brianaingineer@gmail.com as my Neon account.

I used Schema render tool for ER Diagrams: https://schemaspy.sourceforge.net/sample/

## Schema Overview

The database uses a multi-tenant architecture with the following key tables:

### Core Hierarchy
- **Account** - Top-level billing entity
- **Tenant** - Business location/configuration
- **Queue** - Virtual queue within a tenant
- **TypeDefinition** - Configurable ticket types and state machines

### Operational Tables
- **Ticket** - Items in virtual queues
- **TicketItem** - Components within tickets
- **Subject** - Queue participants (people associated with tickets)
- **Employee** - Staff who fulfill tickets

### Features
- UUID v7 identifiers for global uniqueness
- JSONB for tenant customization
- Configurable state machines via TypeDefinition.fsm_schema
- Multi-tenant data isolation
- Optimized indexes for queue performance

## Usage

```bash
# Create database and run schema
psql -c "CREATE DATABASE virtualq_dev;"
psql -d virtualq_dev -f schema.sql

# Optionally load example data for testing
psql -d virtualq_dev -f example-data.sql
```

The `example-data.sql` file includes comprehensive sample data for testing multiple tenant scenarios:
- Coffee shops (Downtown Seattle, Bellevue)
- DMV office (Seattle)
- Cruise ship restaurant
- Sample tickets in various states (received, in_progress, ready)
- Employees and subjects (customers)

## Neon hosted database

- https://console.neon.tech/

- Use brianaiengineer@gmail.com

### Creating connections for code

1. Navigate to Neon database in their app
2. Navigate to the 'Console'
3. Click on the 'Connect' button
4. Copy the snippet shown below for connection string to use. Remove the 'psql' command part of conn string. 

## Install schema and load example dataset
```
psql -d virtualq_dev -f schema.sql          # Create schema only
psql -d virtualq_dev -f example-data.sql    # Load test data
```



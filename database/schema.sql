-- PostgreSQL schema for Multi-Tenant Virtual Queue System
-- Supports various use cases: food orders, table reservations, service desks,
-- DMV queues, hotel check-ins, and custom queue types
-- Based on the multitenancy design document

-- Create database and enable extensions
CREATE DATABASE virtualq;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- ENUM TYPES
-- ============================================================================

-- Wait time estimation method enum
CREATE TYPE wait_estimation_method_enum AS ENUM (
    'average_recent_3',     -- Average of last 3 tickets of same type
    'average_recent_5',     -- Average of last 5 tickets of same type
    'rolling_average',      -- Rolling average over time window
    'manual',               -- Manually set by staff
    'custom',               -- Custom function defined by tenant
    'none'                  -- No estimation shown
);


-- ============================================================================
-- CORE FOUNDATION TABLES
-- ============================================================================

-- Account table - top-level billing and procurement entity
CREATE TABLE Account (
    id serial PRIMARY KEY,
    extid UUID UNIQUE NOT NULL,
    name varchar(100) NOT NULL,
    billing_email varchar(100),
    billing_address text,
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT (now()),
    updated_at timestamptz
);

-- Tenant table - represents a unique product implementation for a customer
CREATE TABLE Tenant (
    id serial PRIMARY KEY,
    extid UUID UNIQUE NOT NULL,
    account_id integer NOT NULL REFERENCES Account(id),
    name varchar(100) NOT NULL,
    description text,
    location_name varchar(200),       -- e.g., "Downtown Seattle Store", "Ship Restaurant Deck 3"
    location_address text,
    location_coordinates point,       -- PostgreSQL point type for lat/lng
    config jsonb,                     -- Tenant-level configuration (UI, settings, etc.)
    ticket_schema jsonb,              -- JSON Schema for ticket extensions
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT (now()),
    updated_at timestamptz
);

-- ============================================================================
-- CORE - METAMODEL TABLES
-- ============================================================================
-- TypeDefinition table - defines available ticket types (system + tenant-specific)
CREATE TABLE TypeDefinition (
    id serial PRIMARY KEY,
    extid UUID UNIQUE NOT NULL DEFAULT uuid_generate_v4(),
    tenant_id integer REFERENCES Tenant(id),  -- NULL = system-defined type
    type_code varchar(32) NOT NULL,            -- 'food_order', 'dmv_registration', etc.
    type_name varchar(100) NOT NULL,           -- 'Food Order', 'Vehicle Registration'
    description varchar(255),
    doc text,                                  -- Documentation for ticket definition in markdown format
    custom_fields_schema jsonb,                -- JSON Schema for this ticket type's custom fields
    fsm_schema jsonb,                          -- State machine definition (states and transitions)
    item_definition_ids integer[],             -- Array of TicketDefinition IDs that can be items within this type
    is_system_defined boolean DEFAULT false,   -- True for built-in types
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT (now()),
    updated_at timestamptz,

    -- Each tenant can only have one ticket type with a given code
    -- System types (tenant_id=NULL) are globally unique
    UNIQUE(tenant_id, type_code)
);


-- ============================================================================
-- CORE - BASE TABLES
-- ============================================================================

-- Queue table - represents a virtual queue within a tenant
CREATE TABLE Queue (
    id serial PRIMARY KEY,
    extid UUID UNIQUE NOT NULL,
    tenant_id integer NOT NULL REFERENCES Tenant(id),
    name varchar(100) NOT NULL,      -- e.g., "Main Queue", "DMV Licenses", "Express Pickup"
    description text,
    allowed_type_definition_ids integer[],  -- Array of allowed type definition IDs for this line
    wait_estimation_method wait_estimation_method_enum DEFAULT 'average_recent_3',
    show_wait_time boolean DEFAULT true,  -- Whether to display wait times to customers
    max_wait_minutes integer,        -- Optional max wait time threshold for alerts
    is_active boolean DEFAULT true,
    display_order integer,           -- For sorting multiple lines in UI
    created_at timestamptz NOT NULL DEFAULT (now()),
    updated_at timestamptz
);





-- Subject table
-- A subject is the person (usually a customer) associated with a ticket.
-- Example: the subject (person) who ordered the food that is in the order virtual queue.
-- Example: The subject (person) who wants to stand in the DMV virtual queue
CREATE TABLE Subject (
    uid serial PRIMARY KEY,
    extid UUID UNIQUE NOT NULL,
    fname varchar(40), -- use fname if there is only 1 name field used.
    lname varchar(40),
    email varchar(100),
    phone varchar(20),
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT (now()),
    updated_at timestamptz
);

-- Employee table - baristas and staff who work where the virtualq is deployed.
CREATE TABLE Employee (
    id serial PRIMARY KEY,
    extid UUID UNIQUE NOT NULL,
    tenant_id integer NOT NULL REFERENCES Tenant(id),
    fname varchar(40) NOT NULL,
    lname varchar(40) NOT NULL,
    email varchar(100) UNIQUE,
    role varchar(20),  -- e.g., 'barista', 'manager', 'supervisor'
    is_active boolean DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT (now()),
    updated_at timestamptz
);

-- Ticket table - generic virtual queue ticket (replaces Order table)
-- Represents items in a virtual queue: food orders, reservations, service requests, etc.
CREATE TABLE Ticket (
    id serial PRIMARY KEY,
    extid UUID UNIQUE NOT NULL,
    queue_id integer NOT NULL REFERENCES Queue(id),
    type_definition_id integer NOT NULL REFERENCES TypeDefinition(id),
    current_state varchar(32) NOT NULL,  -- Current state value (validated against TypeDefinition.fsm_schema)
    subject_id integer REFERENCES Subject(uid),  -- Optional: some tickets may not have a subject
    references_ticket_id integer REFERENCES Ticket(id),  -- Links to another ticket in a workflow chain (e.g., delivery references order)

    employee_id integer REFERENCES Employee(id),  -- Who is fulfilling the ticket

    -- Wait time tracking
    estimated_wait_minutes integer,  -- Estimated wait time when ticket created
    actual_wait_minutes integer,     -- Calculated when ticket completed

    -- TTL and escalation
    ttl_minutes integer,             -- Time-to-live before escalation/expiry
    escalated_at timestamptz,        -- When ticket was escalated
    expires_at timestamptz,          -- When ticket expires (calculated from ttl_minutes)

    -- Tenant customization - JSON document for tenant-specific fields
    custom_data jsonb,               -- Validated against TicketDefinition.custom_fields_schema

    -- State timestamps
    started_at timestamptz,          -- When work started on ticket
    ready_at timestamptz,            -- When ticket marked ready/complete
    picked_up_at timestamptz,        -- When customer picked up (for food orders, etc.)
    completed_at timestamptz,        -- When ticket fully completed

    created_at timestamptz NOT NULL DEFAULT (now()),
    updated_at timestamptz
);

-- TicketItem table - individual items/components/substates contained by a ticket
CREATE TABLE TicketItem (
    id serial PRIMARY KEY,
    extid UUID UNIQUE NOT NULL,
    ticket_id integer NOT NULL REFERENCES Ticket(id) ON DELETE CASCADE,
    item_type_definition_id integer NOT NULL REFERENCES TypeDefinition(id),
    current_state varchar(32),  -- Current state value (NULL if item type has no state machine)

    -- Generic external reference (e.g., MenuItem.extid, Product.extid)
    external_item_id UUID,         -- Optional: references external system item
    external_item_name varchar(100),  -- Snapshot of item name at creation time

    quantity integer NOT NULL DEFAULT 1,
    unit_price decimal(10,2),      -- Price per unit at order time

    -- Item-specific customization data
    custom_data jsonb,             -- Validated against TicketItemDefinition.custom_fields_schema

    started_at timestamptz,        -- When work started on this item
    completed_at timestamptz,      -- When item marked complete
    created_at timestamptz NOT NULL DEFAULT (now()),
    updated_at timestamptz
);

-- TicketStateHistory table - audit trail of ticket state transitions
CREATE TABLE TicketStateHistory (
    id serial PRIMARY KEY,
    ticket_id integer NOT NULL REFERENCES Ticket(id) ON DELETE CASCADE,
    previous_state varchar(32),  -- Previous state value (NULL for initial state)
    new_state varchar(32) NOT NULL,  -- New state value
    changed_by_employee_id integer REFERENCES Employee(id),
    notes text,
    created_at timestamptz NOT NULL DEFAULT (now())
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Account indexes
CREATE INDEX idx_account_extid ON Account(extid);
CREATE INDEX idx_account_active ON Account(is_active);

-- Tenant indexes
CREATE INDEX idx_tenant_extid ON Tenant(extid);
CREATE INDEX idx_tenant_account ON Tenant(account_id);
CREATE INDEX idx_tenant_active ON Tenant(is_active);

-- Queue indexes
CREATE INDEX idx_queue_extid ON Queue(extid);
CREATE INDEX idx_queue_tenant ON Queue(tenant_id);
CREATE INDEX idx_queue_active ON Queue(is_active);
CREATE INDEX idx_queue_display_order ON Queue(display_order);

-- TypeDefinition indexes
CREATE INDEX idx_type_def_extid ON TypeDefinition(extid);
CREATE INDEX idx_type_def_tenant ON TypeDefinition(tenant_id);
CREATE INDEX idx_type_def_type_code ON TypeDefinition(type_code);
CREATE INDEX idx_type_def_tenant_type ON TypeDefinition(tenant_id, type_code);
CREATE INDEX idx_type_def_active ON TypeDefinition(is_active);
CREATE INDEX idx_type_def_system ON TypeDefinition(is_system_defined);
CREATE INDEX idx_type_def_items ON TypeDefinition USING gin(item_definition_ids);

-- Subject indexes
CREATE INDEX idx_subject_extid ON Subject(extid);
CREATE INDEX idx_subject_email ON Subject(email);

-- Employee indexes (multi-tenant aware)
CREATE INDEX idx_employee_extid ON Employee(extid);
CREATE INDEX idx_employee_tenant ON Employee(tenant_id);
CREATE INDEX idx_employee_active ON Employee(is_active);
CREATE INDEX idx_employee_tenant_active ON Employee(tenant_id, is_active);

-- Ticket indexes (critical for virtual queue performance)
CREATE INDEX idx_ticket_extid ON Ticket(extid);
CREATE INDEX idx_ticket_queue ON Ticket(queue_id);
CREATE INDEX idx_ticket_type_definition ON Ticket(type_definition_id);
CREATE INDEX idx_ticket_current_state ON Ticket(current_state);
CREATE INDEX idx_ticket_subject ON Ticket(subject_id);
CREATE INDEX idx_ticket_created ON Ticket(created_at);
CREATE INDEX idx_ticket_employee ON Ticket(employee_id);
CREATE INDEX idx_ticket_references ON Ticket(references_ticket_id);

-- Compound indexes for virtual queue queries
CREATE INDEX idx_ticket_queue_state ON Ticket(queue_id, current_state);
CREATE INDEX idx_ticket_queue_state_created ON Ticket(queue_id, current_state, created_at DESC);
CREATE INDEX idx_ticket_state_created ON Ticket(current_state, created_at DESC);
CREATE INDEX idx_ticket_type_def_state ON Ticket(type_definition_id, current_state);

-- Employee dashboard - get open tickets assigned to them
CREATE INDEX idx_ticket_employee_state ON Ticket(employee_id, current_state);

-- TTL and escalation tracking
CREATE INDEX idx_ticket_expires_at ON Ticket(expires_at) WHERE expires_at IS NOT NULL;

-- JSONB index for custom_data queries (GIN index for flexible JSON queries)
CREATE INDEX idx_ticket_custom_data ON Ticket USING gin(custom_data);

-- TicketItem indexes
CREATE INDEX idx_ticketitem_ticket ON TicketItem(ticket_id);
CREATE INDEX idx_ticketitem_type_definition ON TicketItem(item_type_definition_id);
CREATE INDEX idx_ticketitem_current_state ON TicketItem(current_state);
CREATE INDEX idx_ticketitem_external_id ON TicketItem(external_item_id);
CREATE INDEX idx_ticketitem_custom_data ON TicketItem USING gin(custom_data);

-- TicketStateHistory indexes
CREATE INDEX idx_ticket_state_history_ticket ON TicketStateHistory(ticket_id);
CREATE INDEX idx_ticket_state_history_prev ON TicketStateHistory(previous_state);
CREATE INDEX idx_ticket_state_history_new ON TicketStateHistory(new_state);
CREATE INDEX idx_ticket_state_history_created ON TicketStateHistory(created_at);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to all tables with updated_at column
CREATE TRIGGER update_account_updated_at
    BEFORE UPDATE ON Account
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tenant_updated_at
    BEFORE UPDATE ON Tenant
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_queue_updated_at
    BEFORE UPDATE ON Queue
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_type_definition_updated_at
    BEFORE UPDATE ON TypeDefinition
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subject_updated_at
    BEFORE UPDATE ON Subject
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_employee_updated_at
    BEFORE UPDATE ON Employee
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ticket_updated_at
    BEFORE UPDATE ON Ticket
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ticketitem_updated_at
    BEFORE UPDATE ON TicketItem
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Optimized view for Virtual Queue Monitor display
-- Shows active tickets across all lines, tenant-aware
CREATE OR REPLACE VIEW v_monitor_tickets AS
SELECT
    t.extid as ticket_extid,
    td.type_code as ticket_type_code,
    td.type_name as ticket_type_name,
    t.current_state as ticket_state_code,
    t.estimated_wait_minutes,
    l.extid as line_extid,
    l.name as line_name,
    l.tenant_id,
    tn.name as tenant_name,
    CASE
        WHEN s.fname IS NOT NULL THEN s.fname || ' ' || LEFT(s.lname, 1) || '.'
        ELSE 'Guest'
    END as subject_display_name,
    t.created_at,
    t.started_at,
    t.ready_at,
    t.expires_at,
    t.custom_data,  -- Includes ticket-type-specific fields (e.g., order_type, total_amount for food orders)
    COUNT(ti.id) as item_count,
    ARRAY_AGG(ti.external_item_name) FILTER (WHERE ti.external_item_name IS NOT NULL) as item_names
FROM Ticket t
JOIN Queue l ON t.queue_id = l.id
JOIN Tenant tn ON l.tenant_id = tn.id
JOIN TypeDefinition td ON t.type_definition_id = td.id
LEFT JOIN Subject s ON t.subject_id = s.uid
LEFT JOIN TicketItem ti ON t.id = ti.ticket_id
WHERE l.is_active = true
  AND tn.is_active = true
GROUP BY t.id, t.extid, td.type_code, td.type_name, t.current_state,
         t.estimated_wait_minutes, l.extid, l.name, l.display_order,
         l.tenant_id, tn.name, s.fname, s.lname, t.created_at, t.started_at,
         t.ready_at, t.expires_at, t.custom_data
ORDER BY
    l.tenant_id,
    l.display_order NULLS LAST,
    t.created_at ASC;


-- ============================================================================
-- EXAMPLE DATA
-- ============================================================================
-- For sample/test data, see example-data.sql
-- Run after creating schema: psql -d virtualq -f example-data.sql

-- ============================================================================
-- COMMENTS
-- ============================================================================

-- Multi-tenancy tables
COMMENT ON TABLE Account IS 'Top-level billing and procurement entity. One account can have multiple tenants.';
COMMENT ON TABLE Tenant IS 'Unique product implementation for a customer. Contains configuration, settings, and customizations.';
COMMENT ON COLUMN Tenant.config IS 'JSONB field for tenant-level configuration (UI settings, branding, etc.)';
COMMENT ON COLUMN Tenant.ticket_schema IS 'JSON Schema definition for validating tenant-specific ticket extensions (deprecated - now in TypeDefinition)';
COMMENT ON TABLE Queue IS 'Virtual queue within a tenant. Represents a "line" for getting goods or services.';
COMMENT ON COLUMN Queue.allowed_type_definition_ids IS 'Array of TypeDefinition IDs that can be created in this queue';
COMMENT ON COLUMN Queue.wait_estimation_method IS 'Method used to calculate wait time estimates for this queue';

-- Type definition tables (metadata-driven)
COMMENT ON TABLE TypeDefinition IS 'Defines available ticket types (system-defined + tenant-specific). Each type has its own custom fields and state workflow (defined in fsm_schema).';
COMMENT ON COLUMN TypeDefinition.tenant_id IS 'NULL for system-defined types, otherwise tenant-specific';
COMMENT ON COLUMN TypeDefinition.type_code IS 'Unique code for this ticket type (e.g., food_order, dmv_registration)';
COMMENT ON COLUMN TypeDefinition.doc IS 'Documentation for this type definition in markdown format';
COMMENT ON COLUMN TypeDefinition.custom_fields_schema IS 'JSON Schema defining structure of custom_data for tickets of this type';
COMMENT ON COLUMN TypeDefinition.fsm_schema IS 'Finite state machine definition (JSONB) with states, transitions, and init state for this ticket type';
COMMENT ON COLUMN TypeDefinition.item_definition_ids IS 'Array of TypeDefinition IDs that can be items/components within tickets of this type. NULL if this definition does not contain items.';
COMMENT ON COLUMN TypeDefinition.is_system_defined IS 'True for built-in ticket types provided by system';

-- Core entity tables
COMMENT ON TABLE Subject IS 'Subjects (people) who create tickets in virtual queues';
COMMENT ON TABLE Employee IS 'Staff members who fulfill tickets. Scoped to a specific tenant.';

-- Ticket tables
COMMENT ON TABLE Ticket IS 'Generic virtual queue ticket. Type and state are metadata-driven via TypeDefinition.fsm_schema.';
COMMENT ON COLUMN Ticket.queue_id IS 'Which virtual queue this ticket is in';
COMMENT ON COLUMN Ticket.type_definition_id IS 'References TypeDefinition - determines ticket type and available states (from fsm_schema)';
COMMENT ON COLUMN Ticket.current_state IS 'Current state value (validated against TypeDefinition.fsm_schema)';
COMMENT ON COLUMN Ticket.subject_id IS 'References Subject - the person associated with this ticket';
COMMENT ON COLUMN Ticket.references_ticket_id IS 'Links to another ticket in a workflow chain (e.g., delivery_order references kitchen_order)';
COMMENT ON COLUMN Ticket.custom_data IS 'JSONB field validated against TypeDefinition.custom_fields_schema. Contains ticket-type-specific fields (e.g., order_type, total_amount for food_order tickets)';
COMMENT ON COLUMN Ticket.ttl_minutes IS 'Time-to-live before escalation or expiration';
COMMENT ON COLUMN Ticket.estimated_wait_minutes IS 'Estimated wait time when ticket was created';
COMMENT ON COLUMN Ticket.actual_wait_minutes IS 'Actual wait time (calculated when completed)';
COMMENT ON TABLE TicketItem IS 'Individual items/components within tickets. Type and state are metadata-driven via TypeDefinition.fsm_schema.';
COMMENT ON COLUMN TicketItem.item_type_definition_id IS 'References TypeDefinition - determines item type and available states from fsm_schema (must be in parent ticket''s item_definition_ids)';
COMMENT ON COLUMN TicketItem.current_state IS 'Current state value (validated against TypeDefinition.fsm_schema). NULL if item type has no state machine.';
COMMENT ON COLUMN TicketItem.external_item_id IS 'Optional reference to external system item (e.g., MenuItem.extid in POS, Product.extid in inventory)';
COMMENT ON COLUMN TicketItem.external_item_name IS 'Snapshot of item name at creation time (denormalized for performance and historical accuracy)';
COMMENT ON COLUMN TicketItem.custom_data IS 'JSONB field validated against TypeDefinition.custom_fields_schema. Contains item-type-specific fields (e.g., customizations for food items).';
COMMENT ON TABLE TicketStateHistory IS 'Audit trail of all ticket state transitions for troubleshooting';
COMMENT ON COLUMN TicketStateHistory.previous_state IS 'Previous state value (NULL for initial state)';
COMMENT ON COLUMN TicketStateHistory.new_state IS 'New state value after transition';

-- Views
COMMENT ON VIEW v_monitor_tickets IS 'Multi-tenant virtual queue monitor view showing active tickets across all queues.';
COMMENT ON VIEW v_monitor_orders IS 'Backward compatibility view for food orders. Filters by TypeDefinition.type_code = food_order.';

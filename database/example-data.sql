-- ============================================================================
-- EXAMPLE DATA FOR TESTING
-- ============================================================================
-- This file contains sample data for testing the VirtualQ system.
-- Run this after creating the schema with schema.sql
--
-- Usage: psql -d virtualq -f example-data.sql

-- Sample Accounts
INSERT INTO Account (extid, name, billing_email, is_active) VALUES
(uuid_generate_v4(), 'Coffee Chain Corp', 'billing@coffeechain.com', true),
(uuid_generate_v4(), 'DMV State Services', 'billing@dmv.state.gov', true),
(uuid_generate_v4(), 'Cruise Line Inc', 'billing@cruiseline.com', true);

-- Sample Tenants
-- Coffee shop tenant
INSERT INTO Tenant (extid, account_id, name, location_name, location_address, is_active) VALUES
(uuid_generate_v4(), 1, 'Downtown Seattle Coffee', 'Downtown Seattle Store', '123 Pike St, Seattle, WA 98101', true),
(uuid_generate_v4(), 1, 'Bellevue Coffee', 'Bellevue Square Store', '456 Bellevue Way, Bellevue, WA 98004', true);

-- DMV tenant
INSERT INTO Tenant (extid, account_id, name, location_name, location_address, is_active) VALUES
(uuid_generate_v4(), 2, 'Seattle DMV', 'Seattle DMV Office', '789 5th Ave, Seattle, WA 98104', true);

-- Cruise ship tenant
INSERT INTO Tenant (extid, account_id, name, location_name, is_active) VALUES
(uuid_generate_v4(), 3, 'Ship Deck 3 Restaurant', 'Deck 3 Main Dining', true);

-- Sample Ticket Definitions (system + tenant-specific)
-- System-defined ticket types (can be used by any tenant)
INSERT INTO TypeDefinition (tenant_id, type_code, type_name, description, is_system_defined, custom_fields_schema) VALUES
(NULL, 'generic', 'Generic Queue Ticket', 'General purpose queue ticket', true, '{"type": "object", "properties": {}}'),
(NULL, 'service_desk', 'Service Desk Request', 'Customer service request ticket', true, '{"type": "object", "properties": {"issue_type": {"type": "string"}, "priority": {"type": "string", "enum": ["low", "medium", "high"]}}}');

-- Tenant-specific ticket types
-- Coffee shops use food_order
INSERT INTO TypeDefinition (tenant_id, type_code, type_name, description, custom_fields_schema) VALUES
(1, 'food_order', 'Food Order', 'Customer food and beverage order', '{"type": "object", "properties": {"special_instructions": {"type": "string"}, "table_number": {"type": "integer"}}}'),
(2, 'food_order', 'Food Order', 'Customer food and beverage order', '{"type": "object", "properties": {"special_instructions": {"type": "string"}, "table_number": {"type": "integer"}}}');

-- DMV-specific ticket types
INSERT INTO TypeDefinition (tenant_id, type_code, type_name, description, custom_fields_schema) VALUES
(3, 'dmv_registration', 'Vehicle Registration', 'Vehicle registration and renewal', '{"type": "object", "properties": {"vin": {"type": "string", "maxLength": 17}, "make": {"type": "string"}, "model": {"type": "string"}, "year": {"type": "integer"}, "plate_number": {"type": "string"}}, "required": ["vin", "make", "model", "year"]}'),
(3, 'dmv_license', 'Driver License', 'Driver license application and renewal', '{"type": "object", "properties": {"license_number": {"type": "string"}, "dob": {"type": "string", "format": "date"}, "eye_color": {"type": "string"}, "restrictions": {"type": "array", "items": {"type": "string"}}}, "required": ["dob"]}'),
(3, 'dmv_test', 'Driver Testing', 'Written and road tests', '{"type": "object", "properties": {"test_type": {"type": "string", "enum": ["written", "road"]}, "attempt_number": {"type": "integer"}}}');

-- Ship restaurant ticket types
INSERT INTO TypeDefinition (tenant_id, type_code, type_name, description, custom_fields_schema) VALUES
(4, 'food_order', 'Food Order', 'Restaurant food order', '{"type": "object", "properties": {"table_number": {"type": "integer"}, "cabin_number": {"type": "string"}, "dietary_restrictions": {"type": "array", "items": {"type": "string"}}}}'),
(4, 'table_reservation', 'Table Reservation', 'Dining table reservation', '{"type": "object", "properties": {"party_size": {"type": "integer"}, "seating_preference": {"type": "string"}, "special_occasion": {"type": "string"}}}');

-- Sample Queues (Virtual Queues) - now reference type definition IDs
-- Coffee shop queues (allow food_order tickets - definition IDs 3 and 4)
INSERT INTO Queue (extid, tenant_id, name, description, allowed_type_definition_ids, wait_estimation_method, show_wait_time, is_active, display_order) VALUES
(uuid_generate_v4(), 1, 'Main Queue', 'Main ordering queue for mobile and in-store', ARRAY[3], 'average_recent_3', true, true, 1),
(uuid_generate_v4(), 2, 'Main Queue', 'Main ordering queue for mobile and in-store', ARRAY[4], 'average_recent_3', true, true, 1);

-- DMV queues (each allows specific ticket type)
INSERT INTO Queue (extid, tenant_id, name, description, allowed_type_definition_ids, wait_estimation_method, show_wait_time, is_active, display_order) VALUES
(uuid_generate_v4(), 3, 'Registration', 'Vehicle registration services', ARRAY[5], 'rolling_average', true, true, 1),
(uuid_generate_v4(), 3, 'Licenses', 'Driver license services', ARRAY[6], 'rolling_average', true, true, 2),
(uuid_generate_v4(), 3, 'Testing', 'Driver testing services', ARRAY[7], 'manual', true, true, 3);

-- Ship restaurant queue (allows both food orders and reservations)
INSERT INTO Queue (extid, tenant_id, name, description, allowed_type_definition_ids, wait_estimation_method, show_wait_time, is_active, display_order) VALUES
(uuid_generate_v4(), 4, 'Dining Queue', 'Main dining queue', ARRAY[8, 9], 'average_recent_5', true, true, 1);

-- Note: Menu items are stored in the POS database (see pos_schema.sql)

-- Sample Employees
INSERT INTO Employee (extid, tenant_id, fname, lname, email, role, is_active) VALUES
-- Downtown Seattle Coffee staff
(uuid_generate_v4(), 1, 'Sarah', 'Johnson', 'sarah.j@coffee-seattle.com', 'barista', true),
(uuid_generate_v4(), 1, 'Mike', 'Chen', 'mike.c@coffee-seattle.com', 'barista', true),
(uuid_generate_v4(), 1, 'Emma', 'Davis', 'emma.d@coffee-seattle.com', 'manager', true),
-- Bellevue Coffee staff
(uuid_generate_v4(), 2, 'Alex', 'Rodriguez', 'alex.r@coffee-bellevue.com', 'barista', true),
-- DMV staff
(uuid_generate_v4(), 3, 'Tom', 'Anderson', 'tom.a@dmv.state.gov', 'clerk', true),
(uuid_generate_v4(), 3, 'Lisa', 'Martinez', 'lisa.m@dmv.state.gov', 'examiner', true),
-- Ship restaurant staff
(uuid_generate_v4(), 4, 'Carlos', 'Garcia', 'carlos.g@cruiseline.com', 'chef', true);

-- Sample Subjects
INSERT INTO Subject (extid, fname, lname, email, phone, is_active) VALUES
(uuid_generate_v4(), 'John', 'Smith', 'john.smith@email.com', '555-0101', true),
(uuid_generate_v4(), 'Jane', 'Doe', 'jane.doe@email.com', '555-0102', true),
(uuid_generate_v4(), 'Bob', 'Wilson', 'bob.wilson@email.com', '555-0103', true),
(uuid_generate_v4(), 'Alice', 'Brown', 'alice.brown@email.com', '555-0104', true),
(uuid_generate_v4(), 'David', 'Lee', 'david.lee@email.com', '555-0105', true);

-- Sample Tickets
-- Coffee shop tickets (queue_id 1 = Downtown Seattle, type_definition_id 3 = food_order)
INSERT INTO Ticket (extid, queue_id, type_definition_id, current_state, subject_id, estimated_wait_minutes, custom_data, created_at) VALUES
(uuid_generate_v4(), 1, 3, 'received', 1, 5, '{"order_type": "mobile", "total_amount": 12.50}', NOW() - INTERVAL '2 minutes'),
(uuid_generate_v4(), 1, 3, 'in_progress', 2, 7, '{"order_type": "in_store", "total_amount": 8.75}', NOW() - INTERVAL '5 minutes'),
(uuid_generate_v4(), 1, 3, 'ready', 3, 10, '{"order_type": "mobile", "total_amount": 15.00}', NOW() - INTERVAL '12 minutes');

-- Bellevue Coffee tickets (queue_id 2, type_definition_id 4 = food_order)
INSERT INTO Ticket (extid, queue_id, type_definition_id, current_state, subject_id, estimated_wait_minutes, custom_data, created_at) VALUES
(uuid_generate_v4(), 2, 4, 'received', 4, 6, '{"order_type": "mobile", "total_amount": 9.25}', NOW() - INTERVAL '1 minute');

-- DMV tickets (queue_id 3 = Registration, type_definition_id 5 = dmv_registration)
INSERT INTO Ticket (extid, queue_id, type_definition_id, current_state, subject_id, estimated_wait_minutes, custom_data, created_at) VALUES
(uuid_generate_v4(), 3, 5, 'received', 5, 30, '{"vin": "1HGBH41JXMN109186", "make": "Honda", "model": "Accord", "year": 2021}', NOW() - INTERVAL '3 minutes');

-- Sample TicketItems (for the first coffee order)
INSERT INTO TicketItem (extid, ticket_id, item_type_definition_id, external_item_name, quantity, unit_price, created_at) VALUES
(uuid_generate_v4(), 1, 3, 'Caffe Latte', 2, 5.25, NOW() - INTERVAL '2 minutes'),
(uuid_generate_v4(), 1, 3, 'Blueberry Muffin', 1, 2.00, NOW() - INTERVAL '2 minutes');

-- Sample TicketItems (for the second coffee order)
INSERT INTO TicketItem (extid, ticket_id, item_type_definition_id, external_item_name, quantity, unit_price, created_at) VALUES
(uuid_generate_v4(), 2, 3, 'Cappuccino', 1, 4.75, NOW() - INTERVAL '5 minutes'),
(uuid_generate_v4(), 2, 3, 'Croissant', 1, 4.00, NOW() - INTERVAL '5 minutes');

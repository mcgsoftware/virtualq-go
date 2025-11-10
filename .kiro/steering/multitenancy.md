---
inclusion: always
---

# Multi-tenancy

Architectural capabilities for multi-tenancy. 

## Definition of a tenant

We define the top-level tenancy with an "Account". 
Product billing, procurement, etc. is with an Account. 
An account contains zero tenants (a prospective customer) to many
tenants.

A tenant is attached to the Account holder. For some busineses
a single tenant is all that is required. For other business 
customers (e.g. a ship) may need multiple levels of tenants to operate. 
A small business for example may require a single tenant and that
tenant to represent the operations for a single coffee store. 

A tenant is a unique implementation of a product. It includes
configuration, settings, customizations for the software to operate
for a customer. 

A larger business may require subtenants. For a ship, this might be a single restarurant on
board which has it's own menu, order status, UI graphics, definitions of who
can adminster it, and so on. For a coffee store chain, 
each store in the chain may be it's own subtenant.

A tenant has a location. It may be a loction within the same
physical building as another tenant (e.g. a vendor inside a large 
conference center)

## Definition of a Virtual Queue

A virtual queue represents a "line" of for getting
goods or services usually. A small tenant may have a 
single virtual queue. For example, starbucks has a single 
virtual queue for mobile and in-store purchases at
every store. 

When we work with a virtual queue in the system it 
is called a "line" and is modelled this way in our
API and databases. For the purpose of this document
we use the term "line" and "virtual queue" synonymously.

A tenant may need multiple virtual queues. For example, a
concession business that has multiple locations inside a 
large conference event. Each vendor booth would have its
own queue for say making food for conference attendees. 
For practical purposes, these virtual queues are made
one for each food cart at the conference. They are all
identical (single tenant) it's just the virtual queue
is distributed across multiple carts instead of a single queue.

Initially, virtual queues have a flat prioritization. 
In the future, we may have VIP higher priority virtual
queues and such for more nuanced wait times. 

Some tenants, like a DMV might have multiple lines defined
for it such as: Car Registrations, Drivers Tests, Licenses, etc.
The main reasons for multiple lines in the same location is 
for how tickets are processed. In the case of DMV, they have people
assigned to various activities, hence a separate line for 
them.

### What is the difference between a tenant and virtual queue

The tenant is the hierarchically owning entity for the virtual queue. 
A tenant can configure and fine tune the application, whereas
a line is a simple construct that has unique identity but
it relies on the tenant for most of it's configuration. 
For example a UI configuration must be done at the tenant level,
not the virtual queue level. 

## Tickets

Most POS systems have the concept of a "ticket". A
virtual queue is a queue of tickets. A ticket
for a food business usually represents a customer's food
order. A ticket for a restaurant reservation virtual queue
may represent a table reservation for walk-in customers. 
A ticket for a service desk might represent guests waiting to
talk to a company representative. A ticket for a hotel 
check-in solution might be for a guest that is wanting
to check-in to the hotel but the long line of people is
virtualized, so a ticket represents a hotel checkin.

A ticket is assigned to a virtual queue and a single ticket
can not belong to multiple virtual queues at the same time. 

### Ticket Types
There are different ticket types supported and some ticket
types will be customizable in future releases. 

When a virtual queue is configured for a tenant, the
ticket types it allows put into it are tenant-defined. 
For example, a coffee store probably doesn't need  to have
table_reservation ticket configured for it.

## Wait Time Estimations

Wait time estimation is often specific to the tenant and
vitual queue. We will have an api to select different 
out of the box methods to estimate (e.g. by averaging the
most recent 3 tickets of the same type) we can also let
customers define their on functions that estimate wait 
times perhaps using other systems and data to compute
the estimate with.  

Some virtual queues may not want time estimates shown
to customers. For some businesses, if the customer
knew how long the wait was they would just walk away.

### Virtual Queues are dynamic

A business may have slow queues for any reason (e.g. shortage
of supplies) or they
may speed up (e.g. more employees available suddenly). 
The virtual queue must always update wait times as the ticket
flow changes. 

### Ticket TTL
Some businesses want special events to trigger if a 
ticket reaches a certain age. Usually with an 
escalation process. Also sometimes tickets are not updated
properly due to human error or customers leaving, etc. 
A TTL can help clear out tickets that are not active
but still in the queue for some reason. 

# Customization

Some of the data model entities (e.g. Ticket)
can be thought of as a superclass. That is, the
tenant can extend the model to add custom attributes
to a ticket and the virtual queue treats them generically 
as a ticket, but ticket processes handled by the users
might read/write the custom ticket properties they 
added to the ticket definition. Generically, we call 
this "model type extensions".

In the first version, extensions will be defined 
as part of tenant customization. The databases
will store the custom data as JSON documents inside
the corresponding tables. The tenant customization 
will define the JSON Schema for the extension to 
help ensure the extension data is consistent. 

It is important to note that these extensions are 
tenant-defined, not virtual queue defined and not
account-defined.
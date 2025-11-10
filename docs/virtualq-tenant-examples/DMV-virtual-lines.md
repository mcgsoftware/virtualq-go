# DMV Use case

This outlines a DMV operation that could use virtual 
lines for managing their work intake at the DMV 
center. 

This is very much a guest services type of service
center, where citizens come in to resolve their DMV
issues and related DMV transactions. 

The DMV is normally very busy and understaffed. It's 
often a one hour to two hour wait time to do a 
simple transaction. Virtual lines can make it easier for
citizens to get started with their transactions and they
can leave DMV for lunch or whatever, to return when
their ticket is close to having someone at a desk
work on it. 

## Basic Configuration

- DMV will be the Account owner for North Florida
- DMV has 27 locations in North Florida
- Each location will use the same virtual lines configured the same way. In this regard, it's like a chain store - they are all the same, just different locations. 
### Virtual Line definitions:
  1. Vehicle Registration
  1. Drivers licenses
  1. Vehicle title and purchases
  1. Other

- Each virtual line has custom ticket definitions for it and the data and states are relevant to the workflow required to streamline DMV operations. 
- Example:
  - Registration has a form to fill out after start state
  - Registration process validates the citizen has the required information
  - Registration process runs a pre-check and sets ticket state to 'Ready' if it passes or 'Error'
  - Registration is assigned to an employee and state 'in-progress' when it's ready and a worked pulls the ticket to work on it. 

### Process workflow
- Note that DMV process run on their custom on-prem systems. Virtual lines only handles the queue and ticket state, not the process workflow or state transition work.

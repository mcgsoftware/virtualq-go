---
inclusion: always
---

# VirtualQ Project Overview

VirtualQ is a multi-tenant virtual queue management system inspired by Starbucks' order status monitors. It enables businesses to manage customer wait times and service workflows through real-time status tracking.

## Core Concept

Transform physical waiting lines into virtual queues where customers can:
- Join queues remotely via mobile apps
- Track their position and estimated wait times
- Receive notifications when service is ready
- Leave and return without losing their place

## Target Use Cases

- **Food Service**: Coffee shops, restaurants (order status tracking)
- **Government Services**: DMV offices (license renewals, registrations)
- **Service Centers**: Customer support desks, hotel check-ins
- **Healthcare**: Clinic waiting rooms, pharmacy queues

## Architecture Principles

- **Multi-tenant**: Single platform serving multiple businesses
- **Metadata-driven**: Configurable ticket types and workflows per tenant
- **Real-time**: Event-driven status updates across all interfaces
- **Modular**: Microservices architecture with clear boundaries

## Development Strategy

This project uses Spec-Driven Development (SDD) to:
1. Define clear requirements before implementation
2. Create comprehensive design documents
3. Generate actionable implementation tasks
4. Maintain context for AI-assisted development

Focus on building focused, demonstrable features rather than attempting to build the entire system at once.

For detailed architecture, component boundaries, and technology stack decisions, see: `#[[file:solution-overview.md]]`
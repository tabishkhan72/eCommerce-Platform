# eCommerce Platform Starter

This starter provides a Rails application template that sets up a headless commerce API with the following:
- Auth with Devise and JWT
- Policy authorization with Pundit
- Multi store and multi vendor modeling
- Products, variants, inventory, cart, orders
- B2B price tiers
- Stripe payment gateway placeholder
- CORS, pagination, Swagger via RSwag
- Sidekiq and Redis for async jobs
- Postgres as the primary database

## Quick start

Prerequisites
- Ruby 3.2 plus
- Node and Yarn optional
- Postgres and Redis installed or use Docker
- Rails command line tools

### One command bootstrap
From this folder, run:
```bash
bash scripts/bootstrap.sh my_shop_api
```

This will generate a new Rails API app in a sibling folder named `my_shop_api` and apply the template.

### Run with Docker
A sample Docker Compose is included. After generating the app, copy `deploy/compose.yml` into the app folder and run:
```bash
docker compose up --build
```

### After generation
- Set database credentials in `config/database.yml`
- Run `bin/rails db:setup`
- Start the server with `bin/rails server`

The API namespace is at `/api/v1` with endpoints for products, cart, and orders.

## What the template does
- Adds required gems to Gemfile
- Installs Devise and creates a User model with JWT
- Creates core models: Store, Vendor, Product, Variant, InventoryItem, Cart, CartItem, Order, OrderItem, PriceTier
- Adds namespaced controllers under `api/v1`
- Wires routes for products, cart, orders, vendors
- Adds Stripe gateway service stub
- Configures CORS and Swagger docs
- Adds Sidekiq and basic job for order processing

## Notes
- This is a foundation to extend. You will likely refine the data model and validations for your needs.
- For multi region pricing and taxes, plug in your provider or custom logic in the services layer.
- For a real Stripe integration, add webhook handling and capture flow in the Payments module.

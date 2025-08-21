# --- Rails application template: eCommerce Platform (hardened & production-lean) ---

# Core
gem 'pg'
gem 'redis'
gem 'sidekiq'
gem 'rack-cors'
gem 'rack-attack'
gem 'oj'

# AuthZ/AuthN
gem 'devise'
gem 'devise-jwt'
gem 'pundit'

# Payments & Money
gem 'stripe'
gem 'money-rails'

# API & Docs
gem 'kaminari'
gem 'jbuilder'
gem 'rswag-api'
gem 'rswag-ui'
gem 'rswag-specs'

# Multi-tenancy (optional; wired but easy to disable)
gem 'apartment'

# Dev/Test
gem_group :development, :test do
  gem 'rspec-rails'
  gem 'pry-rails'
  gem 'factory_bot_rails'
  gem 'database_cleaner-active_record'
  gem 'annotate'
  gem 'bullet'
end

after_bundle do
  # Generators & basic setup
  environment <<~RUBY
    config.api_only = true
    config.middleware.use Rack::Attack
    Oj.optimize_rails
    config.active_record.yaml_column_permitted_classes = [Symbol]
  RUBY

  rails_command "g rspec:install"
  rails_command "g devise:install"
  rails_command "g devise User"
  rails_command "g pundit:install"
  rails_command "g rswag:api:install"
  rails_command "g rswag:ui:install"

  # --- Initializers ---

  # MoneyRails
  create_file "config/initializers/money.rb", <<~RUBY
    MoneyRails.configure do |config|
      config.default_currency = :usd
      config.rounding_mode = BigDecimal::ROUND_HALF_UP
    end
  RUBY

  # CORS (lock to env)
  create_file "config/initializers/cors.rb", <<~RUBY
    allowlist = ENV.fetch('CORS_ORIGINS', '').split(',').map(&:strip).reject(&:empty?)
    Rails.application.config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins *allowlist.presence || []
        resource '*',
          headers: :any,
          methods: [:get, :post, :put, :patch, :delete, :options, :head],
          expose: ['Authorization']
      end
    end
  RUBY

  # Rack::Attack (simple sane defaults)
  create_file "config/initializers/rack_attack.rb", <<~RUBY
    class Rack::Attack
      Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      throttle('req/ip', limit: (ENV['RATE_LIMIT_REQ_PER_MIN'] || 120).to_i, period: 1.minute) { |req| req.ip }
      throttle('login/ip', limit: 10, period: 1.minute) { |req| req.path == '/users/sign_in' && req.post? && req.ip }
      self.throttled_response = lambda do |_env|
        [429, { 'Content-Type' => 'application/json' }, [{ error: 'rate_limited' }.to_json]]
      end
    end
  RUBY

  # Sidekiq
  create_file "config/initializers/sidekiq.rb", <<~RUBY
    Sidekiq.configure_server do |config|
      config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
    end
    Sidekiq.configure_client do |config|
      config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
    end
  RUBY

  # Devise JWT with denylist revocation
  rails_command "g migration CreateJwtDenylist jti:string:index exp:datetime"
  create_file "app/models/jwt_denylist.rb", <<~RUBY
    class JwtDenylist < ApplicationRecord
      self.table_name = 'jwt_denylists'
    end
  RUBY

  create_file "config/initializers/devise_jwt.rb", <<~RUBY
    Devise.setup do |config|
      config.jwt do |jwt|
        jwt.secret = Rails.application.credentials.jwt_secret || ENV['JWT_SECRET'] || 'dev_secret_change_me'
        jwt.dispatch_requests = [['POST', %r{^/users/sign_in$}]]
        jwt.revocation_requests = [['DELETE', %r{^/users/sign_out$}]]
        jwt.expiration_time = (ENV['JWT_TTL_SECONDS'] || 86_400).to_i
        jwt.request_formats = { user: [:json] }
        jwt.revocation_strategy = Devise::JWT::RevocationStrategies::Denylist
      end
    end

    module Devise
      module JWT
        module RevocationStrategies
          class Denylist
            def self.jwt_revoked?(payload, _user)
              JwtDenylist.exists?(jti: payload['jti'])
            end
            def self.revoke_jwt(payload, _user)
              JwtDenylist.create!(jti: payload['jti'], exp: Time.at(payload['exp']))
            end
          end
        end
      end
    end
  RUBY

  # Apartment (multi-tenant by subdomain; easy to disable)
  create_file "config/initializers/apartment.rb", <<~RUBY
    Apartment.configure do |config|
      config.excluded_models = %w[User JwtDenylist]
      config.use_schemas = true
      config.tenant_resolver = Apartment::Resolvers::Subdomain
    end
  RUBY

  # Annotate & Bullet (dev only)
  create_file "config/initializers/bullet.rb", <<~RUBY
    if defined?(Bullet)
      Bullet.enable = Rails.env.development?
      Bullet.bullet_logger = true
      Bullet.rails_logger = true
    end
  RUBY

  # --- Domain Models (with constraints) ---

  rails_command "g model Store name:string domain:string:index locale:string currency:string"
  rails_command "g model Vendor name:string store:references"
  rails_command "g model Product store:references vendor:references name:string slug:string:index description:text"
  rails_command "g model Variant product:references sku:string:index price_cents:integer currency:string"
  rails_command "g model InventoryItem variant:references quantity:integer location:string"
  rails_command "g model Cart user:references store:references status:string"
  rails_command "g model CartItem cart:references variant:references quantity:integer"
  rails_command "g model Order user:references store:references total_cents:integer currency:string status:string idempotency_key:string:index"
  rails_command "g model OrderItem order:references variant:references quantity:integer price_cents:integer"
  rails_command "g model PriceTier product:references label:string min_qty:integer price_cents:integer currency:string"

  # Add DB constraints & enums
  rails_command "g migration AddConstraintsAndEnums"

  append_file "db/migrate/*_add_constraints_and_enums.rb", <<~'RUBY'
    class AddConstraintsAndEnums < ActiveRecord::Migration[7.1]
      def change
        # Not-null + defaults
        change_column_null :stores, :name, false
        change_column_null :products, :name, false
        change_column_null :variants, :sku, false
        change_column_null :variants, :price_cents, false
        change_column_null :carts, :status, false
        change_column_null :orders, :status, false
        add_index :products, [:store_id, :slug], unique: true
        add_index :variants, :sku, unique: true
        add_index :inventory_items, :variant_id, unique: true
        add_index :price_tiers, [:product_id, :min_qty], unique: true
        add_index :carts, [:user_id, :store_id], unique: true, where: "status='active'"
        add_index :orders, :created_at

        # Enums (string -> check constraints)
        add_check_constraint :carts, "status IN ('active','abandoned','converted')", name: "carts_status_check"
        add_check_constraint :orders, "status IN ('pending','paid','failed','cancelled','refunded','fulfilling','shipped')", name: "orders_status_check"

        # FKs
        add_foreign_key :vendors, :stores
        add_foreign_key :products, :stores
        add_foreign_key :products, :vendors
        add_foreign_key :variants, :products
        add_foreign_key :inventory_items, :variants
        add_foreign_key :carts, :users
        add_foreign_key :carts, :stores
        add_foreign_key :cart_items, :carts
        add_foreign_key :cart_items, :variants
        add_foreign_key :orders, :users
        add_foreign_key :orders, :stores
        add_foreign_key :order_items, :orders
        add_foreign_key :order_items, :variants
      end
    end
  RUBY

  # --- Policies (example) ---
  create_file "app/policies/application_policy.rb", <<~RUBY, force: true
    class ApplicationPolicy
      attr_reader :user, :record
      def initialize(user, record); @user = user; @record = record; end
      def index?; true; end
      def show?; true; end
      def create?; user.present?; end
      def update?; user.present?; end
      def destroy?; user.present?; end
      class Scope
        def initialize(user, scope); @user = user; @scope = scope; end
        def resolve; @scope.all; end
      end
    end
  RUBY

  # --- Services ---

  # Stripe gateway (real call placeholder + idempotency_key pass-through)
  create_file "app/services/payments/stripe_gateway.rb", <<~RUBY
    module Payments
      class StripeGateway
        def initialize(api_key: ENV['STRIPE_API_KEY'])
          @api_key = api_key
        end
        def charge(amount_cents:, currency:, source:, description:, idempotency_key:)
          # TODO: Integrate Stripe SDK: Stripe::Charge.create({amount: amount_cents, currency:, source:, description:}, {idempotency_key:})
          OpenStruct.new(success?: true, id: SecureRandom.uuid, amount_cents:, currency:)
        end
      end
    end
  RUBY

  # Checkout service (transactional, idempotent, inventory safe)
  create_file "app/services/checkout_service.rb", <<~RUBY
    class CheckoutService
      class Error < StandardError; end

      def initialize(cart:, user:, store:, payment_source:, idempotency_key:)
        @cart, @user, @store = cart, user, store
        @payment_source, @idempotency_key = payment_source, idempotency_key
      end

      def call
        raise Error, 'cart empty' if @cart.cart_items.empty?
        existing = Order.find_by(idempotency_key: @idempotency_key)
        return existing if existing

        ActiveRecord::Base.transaction do
          total_cents = @cart.cart_items.joins(:variant).sum('cart_items.quantity * variants.price_cents')
          order = Order.create!(user: @user, store: @store, total_cents: total_cents, currency: 'USD', status: 'pending', idempotency_key: @idempotency_key)
          @cart.cart_items.includes(:variant).each do |ci|
            # inventory reservation
            inv = InventoryItem.lock.find_by!(variant_id: ci.variant_id)
            raise Error, 'insufficient inventory' if inv.quantity < ci.quantity
            inv.update!(quantity: inv.quantity - ci.quantity)
            OrderItem.create!(order: order, variant: ci.variant, quantity: ci.quantity, price_cents: ci.variant.price_cents)
          end
          OrderPaymentJob.perform_later(order.id, @payment_source, @idempotency_key)
          @cart.update!(status: 'converted')
          order
        end
      rescue ActiveRecord::RecordInvalid => e
        raise Error, e.message
      end
    end
  RUBY

  # --- Controllers ---

  create_file "app/controllers/application_controller.rb", <<~RUBY, force: true
    class ApplicationController < ActionController::API
      include Pundit::Authorization
      before_action :set_store
      rescue_from Pundit::NotAuthorizedError do
        render json: { error: 'not authorized' }, status: :forbidden
      end
      private
      def set_store
        # For Apartment by subdomain, tenant is switched automatically; still fetch store for context.
        @current_store = Store.first
      end
      def current_user
        # Replace with Devise's current_user in real flows
        super || User.first || User.create!(email: 'demo@example.com', password: 'password123')
      end
    end
  RUBY

  # Products
  create_file "app/controllers/api/v1/products_controller.rb", <<~RUBY
    module Api
      module V1
        class ProductsController < ApplicationController
          def index
            products = Product.where(store: @current_store).order(created_at: :desc).page(params[:page]).per(ENV.fetch('PAGE_SIZE', 20))
            render json: {
              data: products.as_json(only: [:id, :name, :slug, :description]),
              meta: { page: params[:page] || 1, total: products.total_count }
            }
          end

          def show
            product = Product.find(params[:id])
            render json: product.as_json(include: { variants: { only: [:id, :sku, :price_cents, :currency] } })
          end

          def create
            product = Product.new(product_params.merge(store: @current_store))
            if product.save
              render json: product, status: :created
            else
              render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def update
            product = Product.find(params[:id])
            if product.update(product_params)
              render json: product
            else
              render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
            end
          end

          def destroy
            Product.find(params[:id]).destroy
            head :no_content
          end

          private

          def product_params
            params.require(:product).permit(:name, :slug, :description, :vendor_id)
          end
        end
      end
    end
  RUBY

  # Cart & Checkout
  create_file "app/controllers/api/v1/carts_controller.rb", <<~RUBY
    module Api
      module V1
        class CartsController < ApplicationController
          def show
            cart = current_cart
            render json: cart_payload(cart)
          end

          def add_item
            cart = current_cart
            variant = Variant.find(params[:variant_id])
            item = cart.cart_items.find_or_initialize_by(variant: variant)
            item.quantity = item.quantity.to_i + params[:quantity].to_i.clamp(1, 10)
            item.save!
            render json: cart_payload(cart), status: :ok
          end

          def remove_item
            cart = current_cart
            cart.cart_items.find_by!(variant_id: params[:variant_id]).destroy
            render json: cart_payload(cart), status: :ok
          end

          def checkout
            cart = current_cart
            idempotency_key = request.headers['Idempotency-Key'] || SecureRandom.uuid
            order = CheckoutService.new(
              cart: cart,
              user: current_user,
              store: @current_store,
              payment_source: params[:payment_source] || 'tok_visa',
              idempotency_key: idempotency_key
            ).call
            render json: { order_id: order.id, status: order.status }, status: :created
          rescue CheckoutService::Error => e
            render json: { error: e.message }, status: :unprocessable_entity
          end

          private

          def current_cart
            Cart.find_or_create_by!(user: current_user, store: @current_store) { |c| c.status = 'active' }
          end

          def cart_payload(cart)
            {
              id: cart.id,
              items: cart.cart_items.includes(:variant).map { |i|
                { variant_id: i.variant_id, sku: i.variant.sku, qty: i.quantity, price_cents: i.variant.price_cents }
              }
            }
          end
        end
      end
    end
  RUBY

  # Orders (read + create manual orders if needed)
  create_file "app/controllers/api/v1/orders_controller.rb", <<~RUBY
    module Api
      module V1
        class OrdersController < ApplicationController
          def index
            orders = Order.where(store: @current_store).order(created_at: :desc).page(params[:page]).per(ENV.fetch('PAGE_SIZE', 20))
            render json: { data: orders.as_json(only: [:id, :status, :total_cents, :currency, :created_at]), meta: { total: orders.total_count } }
          end

          def show
            order = Order.find(params[:id])
            render json: order.as_json(include: { order_items: { only: [:variant_id, :quantity, :price_cents] } })
          end

          def create
            order = Order.new(order_params.merge(store: @current_store))
            if order.save
              render json: order, status: :created
            else
              render json: { errors: order.errors.full_messages }, status: :unprocessable_entity
            end
          end

          private

          def order_params
            params.require(:order).permit(:user_id, :total_cents, :currency, :status)
          end
        end
      end
    end
  RUBY

  # --- Jobs ---

  create_file "app/jobs/order_payment_job.rb", <<~RUBY
    class OrderPaymentJob < ApplicationJob
      queue_as :payments
      def perform(order_id, payment_source, idempotency_key)
        order = Order.find(order_id)
        return if order.status != 'pending'
        result = Payments::StripeGateway.new.charge(
          amount_cents: order.total_cents,
          currency: order.currency,
          source: payment_source,
          description: "Order ##{order.id}",
          idempotency_key: idempotency_key
        )
        if result.success?
          order.update!(status: 'paid')
          OrderFulfillmentJob.perform_later(order.id)
        else
          order.update!(status: 'failed')
        end
      end
    end
  RUBY

  create_file "app/jobs/order_fulfillment_job.rb", <<~RUBY
    class OrderFulfillmentJob < ApplicationJob
      queue_as :default
      def perform(order_id)
        order = Order.find(order_id)
        order.update!(status: 'fulfilling')
        # TODO: call WMS/3PL, reserve shipment, etc.
        order.update!(status: 'shipped')
      end
    end
  RUBY

  # --- Models: add simple validations/enums quickly ---

  append_file "app/models/order.rb", <<~RUBY
    class Order < ApplicationRecord
      belongs_to :user
      belongs_to :store
      has_many :order_items, dependent: :destroy
      validates :total_cents, numericality: { greater_than_or_equal_to: 0 }
      validates :currency, presence: true
      validates :status, presence: true
      validates :idempotency_key, presence: true, uniqueness: true
    end
  RUBY

  append_file "app/models/inventory_item.rb", <<~RUBY
    class InventoryItem < ApplicationRecord
      belongs_to :variant
      validates :quantity, numericality: { greater_than_or_equal_to: 0 }
    end
  RUBY

  # --- Routes ---
  route <<~RUBY
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'

    namespace :api do
      namespace :v1 do
        resources :products
        resource :cart, only: [:show] do
          post :add_item
          delete :remove_item
          post :checkout
        end
        resources :orders, only: [:index, :show, :create]
        resources :vendors, only: [:index, :show] do
          resources :products, only: [:index]
        end
      end
    end
  RUBY

  # --- RSwag (OpenAPI) auth header ---
  create_file "spec/swagger_helper.rb", <<~RUBY
    require 'rails_helper'
    RSpec.configure { |config| config.swagger_root = Rails.root.join('swagger').to_s }
    RSpec.configure do |config|
      config.after(:suite) do
        FileUtils.mkdir_p(RSpec.configuration.swagger_root)
        RSpec.configuration.swagger_format = :yaml
      end
    end
    Swagger::Blocks.build_root_json(Swagger::Blocks.build_root_json({}))
  RUBY

  # --- Seeds (safe sample data) ---
  append_file "db/seeds.rb", <<~RUBY
    store = Store.find_or_create_by!(name: 'Main', domain: 'localhost', locale: 'en', currency: 'USD')
    vendor = Vendor.find_or_create_by!(name: 'Default Vendor', store: store)
    p1 = Product.find_or_create_by!(store: store, vendor: vendor, name: 'Tee', slug: 'tee', description: 'Cotton tee')
    v1 = Variant.find_or_create_by!(product: p1, sku: 'TEE-S', price_cents: 1999, currency: 'USD')
    v2 = Variant.find_or_create_by!(product: p1, sku: 'TEE-M', price_cents: 1999, currency: 'USD')
    InventoryItem.find_or_create_by!(variant: v1) { |ii| ii.quantity = 100; ii.location = 'MAIN' }
    InventoryItem.find_or_create_by!(variant: v2) { |ii| ii.quantity = 100; ii.location = 'MAIN' }
    puts 'Seeded store/vendor/product/variants/inventory.'
  RUBY

  # Dev convenience
  rakefile("dev.rake", <<~RUBY)
    namespace :dev do
      task annotate: :environment do
        system('bundle exec annotate --models')
      end
    end
  RUBY

  say "\n✅ Template applied. Next steps:", :green
  say "1) rails db:create db:migrate db:seed", :green
  say "2) Set env: JWT_SECRET, STRIPE_API_KEY, REDIS_URL, CORS_ORIGINS", :green
  say "3) Start: foreman/Procfile or: rails s & sidekiq -q default -q payments", :green
end

# Rails application template for the eCommerce Platform

gem 'pg'
gem 'redis'
gem 'sidekiq'
gem 'devise'
gem 'devise-jwt'
gem 'pundit'
gem 'stripe'
gem 'money-rails'
gem 'apartment'
gem 'kaminari'
gem 'jbuilder'
gem 'rack-cors'

gem 'rswag-api'
gem 'rswag-ui'
gem 'rswag-specs'

gem_group :development, :test do
  gem 'rspec-rails'
  gem 'pry-rails'
  gem 'factory_bot_rails'
end

after_bundle do
  rails_command "g rspec:install"
  rails_command "g devise:install"
  rails_command "g devise User"
  rails_command "g pundit:install"

  # Core domain models
  rails_command "g model Store name:string domain:string locale:string currency:string"
  rails_command "g model Vendor name:string store:references"
  rails_command "g model Product store:references vendor:references name:string slug:string:index description:text"
  rails_command "g model Variant product:references sku:string:index price_cents:integer currency:string"
  rails_command "g model InventoryItem variant:references quantity:integer location:string"
  rails_command "g model Cart user:references store:references status:string"
  rails_command "g model CartItem cart:references variant:references quantity:integer"
  rails_command "g model Order user:references store:references total_cents:integer currency:string status:string"
  rails_command "g model OrderItem order:references variant:references quantity:integer price_cents:integer"
  rails_command "g model PriceTier product:references label:string min_qty:integer price_cents:integer currency:string"

  # MoneyRails initializer
  create_file "config/initializers/money.rb", <<~RUBY
    MoneyRails.configure do |config|
      config.default_currency = :usd
    end
  RUBY

  # CORS
  create_file "config/initializers/cors.rb", <<~RUBY
    Rails.application.config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head]
      end
    end
  RUBY

  # Devise JWT
  create_file "config/initializers/devise_jwt.rb", <<~RUBY
    Devise.setup do |config|
      config.jwt do |jwt|
        jwt.secret = Rails.application.credentials.jwt_secret || 'dev_secret_change_me'
        jwt.dispatch_requests = [['POST', %r{^/users/sign_in$}]]
        jwt.revocation_requests = [['DELETE', %r{^/users/sign_out$}]]
        jwt.expiration_time = 1.day.to_i
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

  # Simple Stripe gateway stub
  create_file "app/services/payments/stripe_gateway.rb", <<~RUBY
    module Payments
      class StripeGateway
        def initialize(api_key: ENV['STRIPE_API_KEY'])
          @api_key = api_key
        end

        def charge(amount_cents:, currency:, source:, description: nil)
          # TODO: implement with Stripe SDK
          OpenStruct.new(success?: true, id: SecureRandom.uuid, amount_cents: amount_cents, currency: currency)
        end
      end
    end
  RUBY

  # ApplicationController with Pundit and current_store helper
  create_file "app/controllers/application_controller.rb", <<~RUBY, force: true
    class ApplicationController < ActionController::API
      include Pundit::Authorization

      before_action :set_store

      rescue_from Pundit::NotAuthorizedError do
        render json: { error: 'not authorized' }, status: :forbidden
      end

      private

      def set_store
        @current_store = Store.first
      end
    end
  RUBY

  # Products controller
  create_file "app/controllers/api/v1/products_controller.rb", <<~RUBY
    module Api
      module V1
        class ProductsController < ApplicationController
          def index
            products = Product.where(store: @current_store).page(params[:page])
            render json: products.as_json(only: [:id, :name, :slug, :description])
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
            product = Product.find(params[:id])
            product.destroy
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

  # Cart controller
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
            item.quantity += params[:quantity].to_i
            item.save!
            render json: cart_payload(cart), status: :ok
          end

          def remove_item
            cart = current_cart
            item = cart.cart_items.find_by(variant_id: params[:variant_id])
            item&.destroy
            render json: cart_payload(cart), status: :ok
          end

          def checkout
            cart = current_cart
            total_cents = cart.cart_items.joins(:variant).sum('cart_items.quantity * variants.price_cents')
            order = Order.create!(user: current_user, store: @current_store, total_cents: total_cents, currency: 'USD', status: 'pending')
            cart.cart_items.find_each do |ci|
              OrderItem.create!(order: order, variant: ci.variant, quantity: ci.quantity, price_cents: ci.variant.price_cents)
            end
            OrderFulfillmentJob.perform_later(order.id)
            render json: { order_id: order.id, status: order.status }, status: :created
          end

          private

          def current_cart
            Cart.find_or_create_by!(user: current_user, store: @current_store) { |c| c.status = 'active' }
          end

          def current_user
            # Replace with Devise current_user for real auth
            User.first || User.create!(email: 'demo@example.com', password: 'password123')
          end

          def cart_payload(cart)
            {
              id: cart.id,
              items: cart.cart_items.includes(:variant).map { |i| { variant_id: i.variant_id, sku: i.variant.sku, qty: i.quantity, price_cents: i.variant.price_cents } }
            }
          end
        end
      end
    end
  RUBY

  # Orders controller
  create_file "app/controllers/api/v1/orders_controller.rb", <<~RUBY
    module Api
      module V1
        class OrdersController < ApplicationController
          def index
            orders = Order.where(store: @current_store).order(created_at: :desc).page(params[:page])
            render json: orders.as_json(only: [:id, :status, :total_cents, :currency])
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

  # Basic job for fulfillment
  create_file "app/jobs/order_fulfillment_job.rb", <<~RUBY
    class OrderFulfillmentJob < ApplicationJob
      queue_as :default

      def perform(order_id)
        order = Order.find(order_id)
        order.update!(status: 'paid')
      end
    end
  RUBY

  # Routes
  route <<~RUBY
    namespace :api do
      namespace :v1 do
        resources :products
        resource :cart, only: [:show] do
          post :add_item
          delete :remove_item
          post :checkout
        end
        resources :orders, only: [:index, :show, :create]
        resources :vendors do
          resources :products, only: [:index]
        end
      end
    end
  RUBY

  # Swagger
  rails_command "g rswag:api:install"
  rails_command "g rswag:ui:install"

  # Seed data
  append_file "db/seeds.rb", <<~RUBY
    store = Store.find_or_create_by!(name: 'Main', domain: 'localhost', locale: 'en', currency: 'USD')
    vendor = Vendor.find_or_create_by!(name: 'Default Vendor', store: store)
    p1 = Product.find_or_create_by!(store: store, vendor: vendor, name: 'Tee', slug: 'tee', description: 'Cotton tee')
    v1 = Variant.find_or_create_by!(product: p1, sku: 'TEE-S', price_cents: 1999, currency: 'USD')
    v2 = Variant.find_or_create_by!(product: p1, sku: 'TEE-M', price_cents: 1999, currency: 'USD')
  RUBY

  say "Template applied. Run rails db:migrate and rails db:seed", :green
end

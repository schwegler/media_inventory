# frozen_string_literal: true

source 'https://rubygems.org'
ruby '3.2.3'

gem 'rails', '~> 8.1.3'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 5.0'

# Hotwire stack
gem 'importmap-rails'
gem 'stimulus-rails'
gem 'turbo-rails'

# Asset pipeline (Propshaft replaces Sprockets for Rails 8)
gem 'dartsass-rails'
gem 'propshaft'

# Constrain dependencies to avoid compilation issues with native extensions
gem 'psych', '5.4.0'
gem 'rdoc', '>= 6.5.1.1'

gem 'sqlite3', '~> 2.9'

group :development, :test do
  gem 'brakeman'
  gem 'bundler-audit'
  gem 'rspec-rails', '~> 8.0'
  gem 'rubocop'
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'foreman'
  gem 'web-console'
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara'
  gem 'selenium-webdriver'
end

group :production, :test do
  gem 'pg'
end

gem 'bcrypt', '~> 3.1'

gem 'kaminari', '~> 1.2'

gem 'omniauth', '~> 2.1'
gem 'omniauth-atproto', '~> 0.1.4'
gem 'omniauth-oauth2', '~> 1.9'
gem 'omniauth-rails_csrf_protection', '~> 2.0'
gem 'rubyzip', '~> 2.3.0'

gem 'administrate', '~> 1.0'

gem 'webmock', '~> 3.26', group: :test

gem 'dockerfile-rails', '>= 1.7', group: :development

# frozen_string_literal: true

User.create!(name: 'Admin User',
             email: 'admin@example.com',

             admin: true)

User.create!(name: 'Example User',
             email: 'user@example.com',

             admin: false)

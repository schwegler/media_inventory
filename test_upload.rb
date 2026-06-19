# frozen_string_literal: true

require_relative 'config/environment'

user = User.first
puts "User: #{user.name}"

file_path = Rails.root.join('public', 'apple-touch-icon.png')
user.avatar.attach(io: File.open(file_path), filename: 'apple-touch-icon.png', content_type: 'image/png')

if user.save
  puts "Avatar attached: #{user.avatar.attached?}"
  puts "Avatar name: #{user.avatar.filename}"
else
  puts "Failed to attach avatar: #{user.errors.full_messages}"
end

# frozen_string_literal: true

require_relative 'config/environment'

user = User.first
puts "User: #{user.username}"

file_path = Rails.root.join('public', 'apple-touch-icon.png')
file = Rack::Test::UploadedFile.new(file_path, 'image/png')

Rails.application

# We need to simulate a request to SettingsController#update_basic_info
Rack::MockRequest.env_for(
  '/settings/update_basic_info',
  method: 'PATCH',
  params: {
    user: {
      username: user.username,
      avatar: file
    }
  }
)

# We must bypass authentication or mock it.
# Instead of doing that, let's just test ActionController::Parameters directly
params = ActionController::Parameters.new(user: { avatar: file, header_banner: file })
permitted = params.require(:user).permit(:username, :name, :birthday, :bio, :avatar, :header_banner)
puts "Permitted: #{permitted.inspect}"

user.update(permitted)
puts "Attached avatar? #{user.avatar.attached?}"

# Now test the UsersController to_h behaviour
update_params = permitted.to_h
puts "To Hash: #{update_params.inspect}"
user.update(update_params)
puts "Attached header banner? #{user.header_banner.attached?}"

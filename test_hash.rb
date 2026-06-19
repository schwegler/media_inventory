# frozen_string_literal: true

require 'action_controller'
require 'action_dispatch'
file = ActionDispatch::Http::UploadedFile.new(tempfile: Tempfile.new('foo'), filename: 'foo.jpg', type: 'image/jpeg')
params = ActionController::Parameters.new(user: { avatar: file, name: 'John' })
permitted = params.require(:user).permit(:avatar, :name)
puts permitted.to_h.inspect

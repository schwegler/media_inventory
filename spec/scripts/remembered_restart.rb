# frozen_string_literal: true

# Invoked in two independent Rails processes with an isolated temporary SQLite DB.
raise 'Test environment required' unless Rails.env.test?

state_file = ENV.fetch('REMEMBER_RESTART_STATE')
client = ActionDispatch::Integration::Session.new(Rails.application)

if ENV.fetch('REMEMBER_RESTART_PHASE') == 'issue'
  ActiveRecord::Schema.verbose = false
  load Rails.root.join('db/schema.rb')
  user = User.create!(name: 'Synthetic Restart', email: 'restart@example.test', password: 'password123')
  client.post('/login', params: { session: { email: user.email, password: 'password123', remember_device: '1' } })
  raise 'Login failed' unless client.response.redirect?

  File.write(state_file, JSON.generate(user_id: user.id, cookie: client.cookies[:remembered_device]), perm: 0o600)
else
  state = JSON.parse(File.read(state_file))
  client.cookies[:remembered_device] = state.fetch('cookie')
  client.get("/users/#{state.fetch('user_id')}/edit")
  raise 'Restoration failed across process restart' unless client.response.successful?
  raise 'Restoration did not rotate credential' if client.cookies[:remembered_device] == state.fetch('cookie')

  # Real competing database connections exercise the compare-and-swap path.
  device, token = RememberedDevice.issue(User.find(state.fetch('user_id')))
  snapshots = [RememberedDevice.find(device.id), RememberedDevice.find(device.id)]
  barrier = Queue.new
  workers = snapshots.map do |snapshot|
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        barrier.pop
        snapshot.restore(token)
      end
    end
  end
  2.times { barrier << true }
  results = workers.map(&:value)
  raise 'Concurrent restoration failed' unless results.all? { |result| result&.first&.id == device.id }
  raise 'Concurrent restoration rotated twice' unless results.one?(&:last)

  device.destroy!
  client.delete('/logout')
  raise 'Logout did not revoke device' if RememberedDevice.exists?
end
puts 'PASS'

class CreateDummyAdminAccount < ActiveRecord::Migration[8.1]
  def up
    admin = User.find_or_initialize_by(email: 'admin@example.com')
    admin.name = 'Admin User'
    admin.username = 'dummy_admin' if admin.username.blank?
    admin.password = 'password' if admin.new_record?
    admin.admin = true
    admin.confirmed_at ||= Time.current
    admin.save!
  end

  def down
    User.find_by(email: 'admin@example.com')&.destroy
  end
end

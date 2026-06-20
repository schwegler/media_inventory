class AddOwnershipToLibraryItems < ActiveRecord::Migration[8.1]
  def change
    add_column :library_items, :owned_physically, :boolean, default: false, null: false
    add_column :library_items, :owned_physically_format, :string
    add_column :library_items, :owned_digitally, :boolean, default: false, null: false
    add_column :library_items, :owned_digitally_format, :string
  end
end

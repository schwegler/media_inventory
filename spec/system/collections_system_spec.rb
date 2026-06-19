# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Collections Viewing', type: :system do
  let!(:confirmed_user) do
    User.create!(
      name: 'Confirmed User',
      email: 'confirmed@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end

  let!(:unconfirmed_user) do
    User.create!(
      name: 'Unconfirmed User',
      email: 'unconfirmed@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: nil
    )
  end

  it "displays a confirmed user's public collection items" do
    # Create public items
    LibraryItem.create!(item: Movie.find_or_create_by!(title: 'Public Movie'), is_public: true, is_collected: true,
                        user: confirmed_user)
    LibraryItem.create!(item: Album.find_or_create_by!(title: 'Public Album'), is_public: true, is_collected: true,
                        user: confirmed_user)
    # Create non-public item to ensure it is hidden
    LibraryItem.create!(item: Movie.find_or_create_by!(title: 'Private Movie'), is_public: false, is_collected: true,
                        user: confirmed_user)

    visit collection_path(confirmed_user)

    expect(page).to have_text("Confirmed User's Collection")
    expect(page).to have_text('Public Movie')
    expect(page).to have_text('Public Album')
    expect(page).not_to have_text('Private Movie')
  end

  it "displays warning for an unconfirmed user's collection" do
    visit collection_path(unconfirmed_user)

    expect(page).to have_text("This user's collection is not public because their account is unconfirmed.")
  end
end

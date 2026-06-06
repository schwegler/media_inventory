# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'users/index.html.erb', type: :view do
  let(:user1) { User.create!(name: 'Alice', email: 'alice@example.com') }
  let(:user2) { User.create!(name: 'Bob', email: 'bob@example.com') }

  before do
    assign(:users, Kaminari.paginate_array([user1, user2]).page(1))
    allow(view).to receive(:current_user?).and_return(false)
  end

  context 'when logged in as a regular user' do
    let(:current_user) { user1 }

    before do
      allow(view).to receive(:current_user).and_return(current_user)
      render
    end

    it 'renders the list of users' do
      expect(rendered).to match(/Alice/)
      expect(rendered).to match(/Bob/)
    end

    it 'does not show delete buttons' do
      expect(rendered).not_to match(/Delete/)
    end
  end

  context 'when logged in as an admin user' do
    let(:current_user) { User.create!(name: 'Admin', email: 'admin@example.com', admin: true) }

    before do
      allow(view).to receive(:current_user).and_return(current_user)
      render
    end

    it 'renders the delete buttons' do
      expect(rendered).to match(/Delete/)
    end
  end
end

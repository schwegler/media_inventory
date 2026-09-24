# frozen_string_literal: true

require 'spec_helper'
require 'rails_helper'

RSpec.describe User, type: :model do
  before do
    @user = User.new(
      name: 'Example User',
      email: 'user@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  subject { @user }

  it { should respond_to(:name) }
  it { should respond_to(:email) }
  it { should respond_to(:password_digest) }
  it { should respond_to(:password) }
  it { should respond_to(:password_confirmation) }
  it { should respond_to(:admin) }

  it { should be_valid }
  it { should_not be_admin }

  describe "with admin attribute set to 'true'" do
    before do
      @user.save!
      @user.toggle!(:admin)
    end

    it { should be_admin }
  end

  describe 'when name is not present' do
    before { @user.name = ' ' }
    it { should_not be_valid }
  end

  describe 'when name is longer than 50 characters' do
    before { @user.name = 'a' * 51 }
    it { should_not be_valid }
  end

  describe 'when name is exactly 50 characters' do
    before { @user.name = 'a' * 50 }
    it { should be_valid }
  end

  describe 'when email is not present' do
    before { @user.email = ' ' }
    it { should be_valid }
  end

  describe 'when email format is invalid' do
    it 'should be invalid' do
      addresses = %w[user@foo,com user_at_foo.org example.user@foo.
                     foo@bar_baz.com foo@bar+baz.com]
      addresses.each do |invalid_address|
        @user.email = invalid_address
        expect(@user).not_to be_valid
      end
    end
  end

  describe 'when email format is valid' do
    it 'should be valid' do
      addresses = %w[user@example.com USER@foo.COM A_US-ER@foo.bar.org
                     first.last@foo.jp alice+bob@baz.cn]
      addresses.each do |valid_address|
        @user.email = valid_address
        expect(@user).to be_valid
      end
    end
  end

  describe 'when email address is already taken' do
    before do
      user_with_same_email = @user.dup
      user_with_same_email.save
    end
    it { should_not be_valid }
  end

  describe 'when email address is already taken (case insensitive)' do
    before do
      user_with_same_email = @user.dup
      user_with_same_email.email = @user.email.upcase
      user_with_same_email.save
    end
    it { should_not be_valid }
  end

  describe '#liked?' do
    let!(:user) { User.create!(name: 'Tester', email: 'tester@example.com', password: 'password123') }
    let!(:post_item) { Post.create!(user: user, content: 'Test post') }

    context 'when likes association is not loaded' do
      it 'returns true when liked and executes database query' do
        Like.create!(user: user, likeable: post_item)
        expect(user.likes.loaded?).to be false
        expect(user.liked?(post_item)).to be true
      end

      it 'returns false when not liked' do
        expect(user.liked?(post_item)).to be false
      end
    end

    context 'when likes association is loaded' do
      it 'uses in-memory checking without making extra database queries' do
        Like.create!(user: user, likeable: post_item)
        user.likes.load

        expect(user.likes.loaded?).to be true
        queries = []
        subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
          queries << payload[:sql] unless payload[:name] == 'SCHEMA'
        end

        expect(user.liked?(post_item)).to be true
        ActiveSupport::Notifications.unsubscribe(subscription)
        expect(queries).to be_empty
      end

      it 'returns false in memory when not liked' do
        user.likes.load

        expect(user.likes.loaded?).to be true
        queries = []
        subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
          queries << payload[:sql] unless payload[:name] == 'SCHEMA'
        end

        expect(user.liked?(post_item)).to be false
        ActiveSupport::Notifications.unsubscribe(subscription)
        expect(queries).to be_empty
      end
    end
  end
end

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
    let(:movie) { Movie.create!(title: 'Inception') }

    before do
      @user.save!
    end

    it 'returns false when likeable is nil' do
      expect(@user.liked?(nil)).to be false
    end

    context 'when likes association is not loaded' do
      it 'queries the database using exists?' do
        expect(@user.likes.loaded?).to be false
        expect(@user.liked?(movie)).to be false

        @user.likes.create!(likeable: movie)

        expect(@user.liked?(movie)).to be true
      end
    end

    context 'when likes association is preloaded / loaded' do
      it 'uses in-memory check without querying the database' do
        @user.likes.create!(likeable: movie)

        user_with_likes = User.includes(:likes).find(@user.id)
        expect(user_with_likes.likes.loaded?).to be true

        # Ensure no database query is executed when calling liked?
        queries = []
        callback = ->(_name, _start, _finish, _id, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }
        ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
          expect(user_with_likes.liked?(movie)).to be true
        end

        expect(queries).to be_empty
      end
    end
  end
end

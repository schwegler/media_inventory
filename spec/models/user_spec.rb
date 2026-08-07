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
    let(:user) do
      User.create!(name: 'Test', email: 'test_likes@example.com', password: 'password', password_confirmation: 'password')
    end
    let(:movie) { Movie.create!(title: 'Inception') }
    let(:another_movie) { Movie.create!(title: 'The Matrix') }

    it 'caches the liked items on the user instance and prevents N+1 queries' do
      user.liked?(movie) # First call fetches and caches

      # Second call should not trigger any database query on likes table
      queries = 0
      ActiveSupport::Notifications.subscribed(lambda { |*args|
        payload = args.last
        queries += 1 if payload[:sql] =~ /likes/i && payload[:sql] =~ /SELECT/i
      }, 'sql.active_record') do
        user.liked?(movie)
        user.liked?(another_movie)
      end

      expect(queries).to eq(0)
    end

    it 'correctly checks if an item is liked' do
      expect(user.liked?(movie)).to be false

      like = Like.create!(user: user, likeable: movie)
      expect(user.liked?(movie)).to be true
      expect(user.liked?(another_movie)).to be false

      like.destroy
      expect(user.liked?(movie)).to be false
    end

    it 'invalidates the cache when a like is created or destroyed' do
      expect(user.liked?(movie)).to be false

      like = Like.create!(user: user, likeable: movie)
      # Creating the like must clear the cache on the user instance (via callback)
      expect(user.liked?(movie)).to be true

      like.destroy
      # Destroying the like must also clear the cache
      expect(user.liked?(movie)).to be false
    end
  end
end

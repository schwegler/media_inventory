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

  describe 'likes caching and invalidation' do
    let(:user) { User.create!(name: 'Tester', email: 'tester@example.com', password: 'password123', password_confirmation: 'password123') }
    let(:movie) { Movie.create!(title: 'Test Movie') }

    it 'caches liked? queries and invalidates the cache when likes are updated' do
      expect(user.liked?(movie)).to be false

      # The cache is now populated and should return false without hitting DB
      # We insert directly to database to bypass ActiveRecord object synchronization
      Like.insert!({ user_id: user.id, likeable_type: 'Movie', likeable_id: movie.id, created_at: Time.current, updated_at: Time.current })

      # Since user instance has a cached Set, liked? should still return false
      expect(user.liked?(movie)).to be false

      # Now clear the cache manually and it should query and find it
      user.clear_likes_cache
      expect(user.liked?(movie)).to be true

      # Let's test invalidation via the Like callbacks
      like = Like.find_by(user: user, likeable: movie)
      like.user = user # Link the same in-memory user instance

      # liked? should be true (cache populated as true)
      expect(user.liked?(movie)).to be true

      # Destroying the like should automatically clear user's cache via after_commit
      like.destroy!
      expect(user.liked?(movie)).to be false
    end
  end
end

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

  describe '#liked? with in-memory caching' do
    let(:user) do
      User.create!(name: 'Tester', email: 'tester@example.com', password: 'password', password_confirmation: 'password')
    end
    let(:movie) { Movie.create!(title: 'The Dark Knight') }

    it 'caches liked? query results and handles invalidation on mutate' do
      # Expect initially not liked
      expect(user.liked?(movie)).to be false

      # The cache should be set now (it should be an empty Set)
      expect(user.instance_variable_get(:@liked_cache)).to be_a(Set)
      expect(user.instance_variable_get(:@liked_cache)).to be_empty

      # Now, we create a Like on the movie
      # This should trigger after_commit and clear the cache
      like = Like.create!(user: user, likeable: movie)

      # Ensure that the user's liked cache was cleared by the callback
      expect(user.liked?(movie)).to be true

      # If we destroy the like, the cache is invalidated again and it should return false
      like.destroy
      expect(user.liked?(movie)).to be false
    end

    it 'caches to prevent redundant database hits' do
      expect(user.liked?(movie)).to be false

      # Since it is cached, even if we add a like directly to the database without clearing the cache,
      # the cached value should still return false (proving the cache is indeed being hit!)
      Like.insert({ user_id: user.id, likeable_type: 'Movie', likeable_id: movie.id, created_at: Time.current,
                    updated_at: Time.current })

      expect(user.liked?(movie)).to be false # still false because of cache

      # Now explicitly clear cache, it should return true
      user.clear_likes_cache
      expect(user.liked?(movie)).to be true
    end
  end
end

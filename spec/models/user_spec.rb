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

  describe 'likes caching' do
    let(:movie) { Movie.create!(title: 'Inception') }
    let(:other_movie) { Movie.create!(title: 'Avatar') }

    before do
      @user.save!
    end

    it 'caches liked items and clears them appropriately' do
      # Initially, liked? is false
      expect(@user.liked?(movie)).to be false
      expect(@user.instance_variable_get(:@liked_item_keys)).to eq([].to_set)

      # Create a like for movie. This should trigger after_commit callback which clears the cache on @user.
      like = Like.create!(user: @user, likeable: movie)
      expect(@user.instance_variable_get(:@liked_item_keys)).to be_nil

      # Next call to liked? should fetch from database and cache the new like status
      expect(@user.liked?(movie)).to be true
      expect(@user.liked?(other_movie)).to be false
      expect(@user.instance_variable_get(:@liked_item_keys)).to eq([['Movie', movie.id]].to_set)

      # Manual cache clear
      @user.clear_likes_cache
      expect(@user.instance_variable_get(:@liked_item_keys)).to be_nil

      # Destroying the like should trigger after_commit callback to clear the cache again
      like.destroy
      expect(@user.instance_variable_get(:@liked_item_keys)).to be_nil

      # Verify it returns false now
      expect(@user.liked?(movie)).to be false
    end
  end
end

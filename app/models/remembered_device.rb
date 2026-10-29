# frozen_string_literal: true

# Only digests of random 256-bit bearer secrets are persisted.
class RememberedDevice < ApplicationRecord
  belongs_to :user
  LIFETIME = 30.days
  OVERLAP = 60.seconds

  def self.issue(user)
    token = SecureRandom.urlsafe_base64(32)
    device = create!(user: user, session_generation: user.session_generation,
                     token_digest: Digest::SHA256.hexdigest(token), expires_at: LIFETIME.from_now)
    [device, token]
  end

  def self.restore(value)
    id, token = value.to_s.split('.', 2)
    return unless id&.match?(/\A[0-9]+\z/) && token&.match?(/\A[A-Za-z0-9_-]{43}\z/)

    device = find_by(id: id)
    return unless device

    device.restore(token) if device.session_generation == device.user.session_generation
  end

  def restore(token)
    return if expires_at <= Time.current

    digest = Digest::SHA256.hexdigest(token)
    return [self, nil] if previous_valid?(digest)
    return unless ActiveSupport::SecurityUtils.secure_compare(token_digest, digest)
    return [self, nil] if rotated_at && rotated_at > OVERLAP.ago

    replacement = SecureRandom.urlsafe_base64(32)
    # Compare-and-swap also serializes competing restores on SQLite, where row
    # locks are unavailable. A losing response never overwrites the winning cookie.
    changed = self.class.where(id: id, token_digest: digest, rotated_at: rotated_at)
                  .where('expires_at > ?', Time.current)
                  .update_all(previous_token_digest: digest, token_digest: Digest::SHA256.hexdigest(replacement),
                              rotated_at: Time.current, updated_at: Time.current)
    return [self, replacement] if changed == 1

    device = self.class.find_by(id: id)
    [device, nil] if device&.previous_valid?(digest)
  end

  def previous_valid?(digest)
    expires_at > Time.current && rotated_at && rotated_at > OVERLAP.ago && previous_token_digest &&
      ActiveSupport::SecurityUtils.secure_compare(previous_token_digest, digest)
  end
end

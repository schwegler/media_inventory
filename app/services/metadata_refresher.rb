# frozen_string_literal: true

require 'timeout'

class MetadataRefresher
  COOLDOWN = 5.minutes
  USER_COOLDOWN = 20.seconds
  LEASE = 2.minutes

  def self.call(item, user)
    new(item, user).call
  end

  def initialize(item, user)
    @item = item
    @user = user
    @refresh = MetadataRefresh.create_or_find_by!(item: item)
  end

  def enqueue
    return 'cooldown' unless claim?

    RefreshMediaMetadataJob.perform_later(@item, @user)
    'refreshing'
  rescue StandardError
    finish('failed')
  end

  def call(claimed: false)
    return 'cooldown' unless claimed || claim?

    @adapter = MetadataProvider.new(@item, revalidate: true)
    fields, rows = Timeout.timeout(45) { @adapter.call }
    changed = reconcile(fields, rows)
    state = changed.positive? ? 'success' : 'unchanged'
    state = 'partial' if @adapter.partial
    @refresh.update!(state: state, provider: @adapter.provider, succeeded_at: Time.current)
    state
  rescue MetadataProvider::Unsupported
    finish('unsupported')
  rescue MetadataProvider::RateLimited
    finish('rate_limited')
  rescue MetadataProvider::Unavailable
    finish('unavailable')
  rescue StandardError => e
    # Do not log provider URLs, credentials, or raw exception messages.
    Rails.logger.warn("Metadata refresh failed: #{e.class}")
    finish('failed')
  end

  private

  def claim?
    now = Time.current
    @user.with_lock do
      return false if @user.metadata_requested_at && @user.metadata_requested_at > now - USER_COOLDOWN

      claimed = MetadataRefresh.where(id: @refresh.id)
                               .where('requested_at IS NULL OR requested_at < ?', now - COOLDOWN)
                               .where('state != ? OR requested_at < ?', 'refreshing', now - LEASE)
                               .update_all(state: 'refreshing', requested_at: now, updated_at: now)
      return false if claimed.zero?

      @user.update!(metadata_requested_at: now)
    end
    @refresh.reload
    true
  end

  def reconcile(fields, rows)
    changed = 0
    @item.refreshing_metadata = true if @item.respond_to?(:refreshing_metadata=)
    @item.with_lock do
      values = @refresh.provider_values.dup
      fields.compact_blank.each { |field, value| assign_provider_value(field, value, values) }
      if @item.changed?
        @item.save!
        changed += 1
      end
      changed += MetadataChildren.episodes(@item, rows) if @item.is_a?(TvShow)
      changed += MetadataChildren.issues(@item, rows) if @item.is_a?(Comic)
      @refresh.update!(provider_values: values)
    end
    changed
  end

  def assign_provider_value(field, value, values)
    return unless @item.has_attribute?(field)

    value = MetadataProvider.image(value) if field == :thumbnail_url
    return if value.blank? || (field == :thumbnail_url && @item.cover_image.attached?)

    old = @item.public_send(field)
    @item.public_send("#{field}=", value) if field == :thumbnail_url || old.blank? || values[field.to_s] == old
    values[field.to_s] = value
  end

  def finish(state)
    @refresh.update!(state: state, provider: @adapter&.provider || @refresh.provider)
    state
  end
end

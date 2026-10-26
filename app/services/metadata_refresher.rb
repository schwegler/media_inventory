# frozen_string_literal: true

require 'timeout'

# rubocop:disable-next Metrics/ClassLength
class MetadataRefresher
  COOLDOWN = 5.minutes
  USER_COOLDOWN = 20.seconds
  LEASE = 2.minutes
  ALBUM_TIMEOUT = 12

  def self.call(item, user)
    new(item, user).call
  end

  def initialize(item, user, revalidate: true)
    @revalidate = revalidate
    @item = item
    @user = user
    @refresh = MetadataRefresh.find_by(item: item) || MetadataRefresh.create_or_find_by!(item: item)
  end

  def enqueue
    return 'cooldown' unless claim?

    return call(claimed: true) if @item.is_a?(Album)

    unless RefreshMediaMetadataJob.perform_later(@item, @user)
      @refresh.update!(state: 'queue_busy', requested_at: nil)
      return 'queue_busy'
    end
    'refreshing'
  rescue StandardError
    finish('failed')
  end

  def import_album
    raise ArgumentError, 'Album required' unless @item.is_a?(Album)

    return 'cooldown' unless claim_item?(Time.current)

    @refresh.reload
    call(claimed: true)
  end

  def call(claimed: false)
    return 'cooldown' unless claimed || claim?

    budget = @item.is_a?(Album) ? ALBUM_TIMEOUT : 45
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + budget
    @adapter = MetadataProvider.new(@item, revalidate: @revalidate, fresh: @revalidate, deadline: deadline)
    fields, rows = Timeout.timeout(budget) { @adapter.call }
    changed = reconcile(fields, rows)
    state = changed.positive? ? 'success' : 'unchanged'
    state = 'partial' if @adapter.partial
    state = 'edition_required' if @item.is_a?(Album) && @adapter.album_edition_required
    @refresh.update!(state: state, provider: @adapter.provider, succeeded_at: Time.current)
    state
  rescue AlbumMetadata::EditionConflict
    finish('edition_conflict')
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

      return false unless claim_item?(now)

      @user.update!(metadata_requested_at: now)
    end
    @refresh.reload
    true
  end

  def claim_item?(now)
    MetadataRefresh.where(id: @refresh.id)
                   .where('requested_at IS NULL OR requested_at < ?', now - COOLDOWN)
                   .where('state != ? OR requested_at < ?', 'refreshing', now - LEASE)
                   .update_all(state: 'refreshing', requested_at: now, updated_at: now).positive?
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
      changed += AlbumMetadata.reconcile(@item, rows) if @item.is_a?(Album)
      changed += MetadataChildren.episodes(@item, rows) if @item.is_a?(TvShow)
      changed += MetadataChildren.issues(@item, rows) if @item.is_a?(Comic)
      if @item.is_a?(Album) && @adapter.album_release_id
        values['album_release_id'] = @adapter.album_release_id
        values['album_release_group_id'] = @adapter.album_release_group_id
      end
      values.delete('entity_metadata_version') if @item.is_a?(Album) && @adapter.partial
      values['entity_metadata_version'] = 1 unless @adapter.partial
      @refresh.update!(provider_values: values)
    end
    changed
  end

  def assign_provider_value(field, value, values)
    return unless assignable_field?(field, values)

    value = MetadataProvider.image(value) if field == :thumbnail_url
    return if value.blank? || (field == :thumbnail_url && @item.cover_image.attached?)

    value = preserve_credit_corrections(value, values) if field == :metadata_credits_data
    if %i[metadata_credits_data metadata_details].include?(field)
      value = corrected_details(value, values) if field == :metadata_details
      @item.public_send("#{field}=", value)
      values[field.to_s] = value
      return
    end

    old = @item.public_send(field)
    @item.public_send("#{field}=", value) if field == :thumbnail_url || old.blank? || values[field.to_s] == old
    values[field.to_s] = value
  end

  def corrected_details(value, values)
    protected_keys = Array(values['corrected_detail_fields'])
    @item.metadata_details.merge(value.except(*protected_keys))
  end

  def assignable_field?(field, values)
    @item.has_attribute?(field) && !Array(values['corrected_fields']).include?(field.to_s)
  end

  def preserve_credit_corrections(credits, values)
    MetadataEntitySync.without_corrected_roles(@item, credits, Array(values['corrected_fields']),
                                               Array(values['corrected_detail_fields']))
  end

  def finish(state)
    @refresh.update!(state: state, provider: @adapter&.provider || @refresh.provider)
    state
  end
end

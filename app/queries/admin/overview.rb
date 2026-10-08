# frozen_string_literal: true

module Admin
  class Overview
    CACHE_KEY = 'admin/overview/v1'

    def snapshot
      @snapshot ||= Rails.cache.fetch(CACHE_KEY, expires_in: 1.minute) { build_snapshot }
    end

    def pending
      @pending ||= EditSuggestion.where(status: 'pending').includes(:user, :suggestable).order(:created_at).limit(4)
    end

    def recent_decisions
      @recent_decisions ||= EditSuggestion.where(status: %w[approved rejected]).includes(:user, :suggestable)
                                          .order(updated_at: :desc).limit(3)
    end

    def events
      @events ||= event_sources.flat_map do |model, includes|
        scope = model.order(created_at: :desc).limit(4)
        scope = scope.includes(*includes) if includes.any?
        records = scope.to_a
        related = records.flat_map do |record|
          %i[trackable commentable likeable suggestable].filter_map do |association|
            record.public_send(association) if record.respond_to?(association)
          end
        end
        RecordLabels.preload(related)
        records
      end.sort_by(&:created_at).reverse.first(10)
    end

    def integrations
      @integrations ||= ApiConfiguration.order(:source_name, :media_type).map do |config|
        state = if config.source_name.blank? || config.media_type.blank?
                  'Incomplete configuration'
                elsif !config.is_active?
                  'Disabled'
                elsif %w[TMDB RAWG ComicVine].include?(config.source_name) && config.access_token.blank?
                  'Credential needed'
                elsif config.base_url.blank?
                  'URL needed'
                else
                  'Configured'
                end
        { name: config.source_name, type: config.media_type, state: state }
      end
    end

    private

    def build_snapshot
      {
        catalog: catalog_metrics,
        users: User.count,
        new_users: User.where(created_at: 7.days.ago..).count,
        contributors: Activity.where(created_at: 7.days.ago..).distinct.count(:user_id),
        additions: LibraryItem.where(created_at: 7.days.ago..).count,
        pending: EditSuggestion.where(status: 'pending').count,
        comments: Comment.where(created_at: 7.days.ago..).count,
        likes: Like.where(created_at: 7.days.ago..).count,
        follows: Relationship.where(created_at: 7.days.ago..).count,
        mastodon: User.where.not(mastodon_access_token: [nil, '']).count,
        bluesky: User.where.not(bsky_access_token: [nil, '']).count,
        oauth_apps: MastodonOauthApplication.count,
        calculated_at: Time.current
      }
    end

    # A single SQL round trip; no catalog records are instantiated in Ruby.
    def catalog_metrics
      connection = ApplicationRecord.connection
      queries = Catalog::TYPES.map do |model|
        missing_ids = Catalog::MATCHABLE.include?(model) ? Catalog.missing_id(model).select(:id).to_sql : nil
        children = %w[TvShow Comic].include?(model.name) ? Catalog.without_children(model).select(:id).to_sql : nil
        artwork = Catalog.missing_artwork(model).select(:id).to_sql
        <<~SQL.squish
          SELECT #{connection.quote(model.name)} AS type, COUNT(*) AS total,
          COALESCE(SUM(CASE WHEN id IN (#{artwork}) THEN 1 ELSE 0 END), 0) AS missing_artwork,
          #{aggregate_condition(missing_ids)} AS missing_id,
          #{aggregate_condition(children)} AS without_children
          FROM #{model.quoted_table_name}
        SQL
      end
      connection.select_all(queries.join(' UNION ALL ')).to_a.map do |row|
        row.merge(row.except('type').transform_values(&:to_i))
      end
    end

    def aggregate_condition(query)
      query ? "COALESCE(SUM(CASE WHEN id IN (#{query}) THEN 1 ELSE 0 END), 0)" : '0'
    end

    def event_sources
      [[Activity, %i[user trackable]], [User, []], [Comment, %i[user commentable]],
       [Like, %i[user likeable]], [Relationship, %i[follower followed]], [EditSuggestion, %i[user suggestable]]]
    end
  end
end

# frozen_string_literal: true

class ShelfCatalogImport
  def self.call(klass, data)
    return klass.find(data[:catalog_id]) if data[:is_local]

    new(klass, MetadataImport.attributes(data, klass)).call
  end

  def initialize(klass, attributes)
    @klass = klass
    @attributes = attributes
    @field = attributes[:api_id].present? ? :api_id : :external_url
    @provider_id = attributes[@field].to_s.strip.presence
    @attributes[@field] = @provider_id
    raise MetadataImport::Invalid, 'This result has no stable provider identity. Search and select another result.' unless
      @provider_id
  end

  def call
    attempts ||= 0
    identity.with_lock do
      item = existing_or_new
      item.importing_metadata = true if item.respond_to?(:importing_metadata=)
      item.save! if item.new_record?
      item
    end
  rescue ActiveRecord::StatementInvalid => e
    # SQLite lacks row locks; restart its transaction after a competing writer commits.
    raise unless e.cause&.class&.name == 'SQLite3::BusyException' && (attempts += 1) <= 3

    sleep(0.05 * attempts)
    retry
  end

  private

  def identity
    key = Digest::SHA256.hexdigest([@klass.name, @field, @provider_id].to_json)
    ShelfCatalogIdentity.create_or_find_by!(media_type: @klass.name, identity_key: key) do |row|
      row.provider_id = @provider_id
    end
  end

  def existing_or_new
    return GameCatalogIdentity.resolve(@attributes) if @klass == VideoGame

    # Existing duplicate rows are preserved; repeated imports consistently reuse the first.
    @klass.where(@field => @provider_id).order(:id).first || @klass.new(@attributes)
  end
end

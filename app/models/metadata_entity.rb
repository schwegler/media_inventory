# frozen_string_literal: true

class MetadataEntity < ApplicationRecord
  include StoredMediaCover

  KINDS = %w[person artist organization genre franchise series collection platform].freeze
  has_one_attached :cover_image
  has_many :metadata_credits, dependent: :destroy
  has_many :metadata_identities, dependent: :destroy
  validates :name, :normalized_name, :identity_key, :slug, presence: true
  validates :kind, inclusion: { in: KINDS }
  before_validation :normalize_identity

  def self.normalize(value)
    value.to_s.unicode_normalize(:nfkc).strip.gsub(/\s+/, ' ').downcase
  end

  def self.matching(query)
    value = normalize(query)
    pattern = "%#{sanitize_sql_like(value, '!')}%"
    where("normalized_name LIKE ? ESCAPE '!' OR LOWER(CAST(aliases AS TEXT)) LIKE ? ESCAPE '!'", pattern, pattern)
      .order(Arel.sql(sanitize_sql_array(['CASE WHEN normalized_name = ? THEN 0 ELSE 1 END', value])), :name, :id)
  end

  def to_param
    "#{id}-#{slug}"
  end

  private

  def normalize_identity
    self.name = name.to_s.strip
    self.normalized_name = self.class.normalize(name)
    self.slug ||= name.parameterize.presence || 'entity'
    self.identity_key ||= "#{kind}:name:#{normalized_name}"
  end
end

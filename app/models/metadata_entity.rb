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
    where("#{discovery_name_order} LIKE ? ESCAPE '!' OR normalized_name LIKE ? ESCAPE '!' " \
          "OR LOWER(CAST(aliases AS TEXT)) LIKE ? ESCAPE '!'", pattern, pattern, pattern)
      .order(Arel.sql(sanitize_sql_array(['CASE WHEN normalized_name = ? THEN 0 ELSE 1 END', value])), :name, :id)
  end

  def to_param
    "#{id}-#{slug}"
  end

  # ComicVine sometimes quotes the first word/phrase of a storyline. Keep
  # provider identity intact and remove only that paired, leading decoration.
  def display_name
    return name unless kind == 'collection'

    name.sub(/\A"([^"]+)"|\A“([^”]+)”/) { Regexp.last_match(1) || Regexp.last_match(2) }
  end

  def self.discovery_name_order
    column = 'metadata_entities.normalized_name'
    cases = [['"', '"'], ['“', '”']].map do |opening, closing|
      remainder = "SUBSTR(#{column}, 2)"
      position = if connection.adapter_name == 'PostgreSQL'
                   "STRPOS(#{remainder}, #{connection.quote(closing)})"
                 else
                   "INSTR(#{remainder}, #{connection.quote(closing)})"
                 end
      "WHEN kind = 'collection' AND SUBSTR(#{column}, 1, 1) = #{connection.quote(opening)} AND #{position} > 1 " \
        "THEN SUBSTR(#{column}, 2, #{position} - 1) || SUBSTR(#{column}, #{position} + 2)"
    end
    Arel.sql("CASE #{cases.join(' ')} ELSE #{column} END")
  end

  private

  def normalize_identity
    self.name = name.to_s.strip
    self.normalized_name = self.class.normalize(name)
    self.slug ||= name.parameterize.presence || 'entity'
    self.identity_key ||= "#{kind}:name:#{normalized_name}"
  end
end

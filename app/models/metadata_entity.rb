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
    names = discovery_name_order.matches(pattern, '!', false).or(arel_table[:normalized_name].matches(pattern, '!', false))
    aliases = Arel.sql('LOWER(CAST(metadata_entities.aliases AS TEXT))').matches(pattern, '!', false)
    where(names.or(aliases))
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
    column = arel_table[:normalized_name]
    expression = Arel::Nodes::Case.new
    [['"', '"'], ['“', '”']].each do |opening, closing|
      function = connection.adapter_name == 'PostgreSQL' ? 'STRPOS' : 'INSTR'
      position = Arel::Nodes::NamedFunction.new(function, [substring(column, 2), Arel::Nodes.build_quoted(closing)])
      condition = arel_table[:kind].eq('collection').and(substring(column, 1, 1).eq(opening)).and(position.gt(1))
      prefix = substring(column, 2, position - 1)
      suffix = substring(column, position + 2)
      expression.when(condition).then(Arel::Nodes::InfixOperation.new('||', prefix, suffix))
    end
    expression.else(column)
  end

  def self.substring(value, start, length = nil)
    arguments = [value, start, length].compact.map do |argument|
      argument.is_a?(Numeric) ? Arel::Nodes.build_quoted(argument) : argument
    end
    Arel::Nodes::NamedFunction.new('SUBSTR', arguments)
  end
  private_class_method :substring

  private

  def normalize_identity
    self.name = name.to_s.strip
    self.normalized_name = self.class.normalize(name)
    self.slug ||= name.parameterize.presence || 'entity'
    self.identity_key ||= "#{kind}:name:#{normalized_name}"
  end
end

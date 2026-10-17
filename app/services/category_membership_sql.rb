# frozen_string_literal: true

# SQL tokenization shared by the category count and display queries.
module CategoryMembershipSql
  private

  def legacy_sources
    config = Category.config_for(type)
    attrs = type == 'comic-creators' ? %i[writer artist] : [config[:attribute]]
    config[:models].call.flat_map do |model|
      attrs.filter_map { |attr| Category.target_attribute(model, attr) }.uniq.map do |attr|
        table = model.quoted_table_name
        column = @connection.quote_column_name(attr)
        raw = "REPLACE(REPLACE(REPLACE(COALESCE(CAST(#{column} AS TEXT), ''), '/', ','), ';', ','), '|', ',')"
        "SELECT #{@connection.quote(model.name)} AS item_type, id AS item_id, #{raw} AS rest FROM #{table} " \
          "WHERE NOT EXISTS (SELECT 1 FROM metadata_credits WHERE item_type = #{@connection.quote(model.name)} " \
          "AND item_id = #{table}.id)"
      end
    end.join(' UNION ALL ')
  end

  def cte
    position = sqlite? ? "INSTR(rest, ',')" : "POSITION(',' IN rest)"
    token = sqlite? ? "SUBSTR(rest, 1, #{position} - 1)" : "SUBSTRING(rest FROM 1 FOR #{position} - 1)"
    remaining = sqlite? ? "SUBSTR(rest, #{position} + 1)" : "SUBSTRING(rest FROM #{position} + 1)"
    trim = sqlite? ? "TRIM(#{token}, #{@connection.quote(" \t\r\n")})" : "BTRIM(#{token}, #{@connection.quote(" \t\r\n")})"
    credits = Category.entity_credits(type).joins(:metadata_entity).reorder(nil)
                      .where(item_type: self.class::MODELS.map(&:name))
                      .select('metadata_entities.name AS name', 'metadata_entities.normalized_name AS match_name',
                              :item_type, :item_id)
    <<~SQL
      WITH RECURSIVE legacy_source AS (#{legacy_sources}),
      tokens(item_type, item_id, name, rest) AS (
        SELECT item_type, item_id, CAST('' AS TEXT), rest || ',' FROM legacy_source
        UNION ALL
        SELECT item_type, item_id, #{trim}, #{remaining} FROM tokens WHERE rest <> ''
      ), raw_memberships AS (
        #{credits.to_sql}
        UNION ALL
        SELECT name, #{fold('name')} AS match_name, item_type, item_id FROM tokens WHERE name <> ''
      ), memberships AS (
        SELECT MIN(name) AS name, match_name, item_type, item_id
        FROM raw_memberships GROUP BY match_name, item_type, item_id
      )
    SQL
  end
end

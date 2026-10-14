# frozen_string_literal: true

module GameDescriptionsHelper
  def game_description_prose(synopsis)
    formatted = sanitize(synopsis, tags: %w[p br h2 h3 h4 strong b em i ul ol li blockquote], attributes: [])
    fragment = Nokogiri::HTML.fragment(formatted)
    return formatted if fragment.css('p, h2, h3, h4, ul, ol, blockquote').any?

    simple_format(formatted.gsub(%r{<br\s*/?\s*>|\r?\n}i, "\n\n"))
  end

  def game_description_preview(synopsis)
    text = strip_tags(synopsis.gsub(%r{</(?:p|li|blockquote|h[2-4])>|<br\s*/?\s*>}i, "\n"))
    truncate(text.split(/\r?\n/).map(&:strip).find(&:present?).to_s, length: 500, separator: ' ')
  end
end

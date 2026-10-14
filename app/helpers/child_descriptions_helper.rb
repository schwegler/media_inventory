# frozen_string_literal: true

module ChildDescriptionsHelper
  def child_description(summary)
    formatted = sanitize(summary, tags: %w[p br h2 h3 h4 strong b em i ul ol li blockquote], attributes: [])
    fragment = Nokogiri::HTML.fragment(formatted)
    fragment.css('p, h2, h3, h4, ul, ol, blockquote').any? ? formatted : simple_format(formatted)
  end
end

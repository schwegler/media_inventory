# frozen_string_literal: true

# A bounded HTML fragment, not a visually clipped copy of the complete review.
class ReviewExcerpt
  TAGS = %w[p br strong em b i a ul ol li blockquote code].freeze
  attr_reader :html

  def initialize(body, length: 480, paragraphs: 3, breaks: 5)
    helpers = ActionController::Base.helpers
    formatted = helpers.simple_format(body)
    omitted_media = formatted.include?('<img')
    formatted = helpers.sanitize(formatted, tags: TAGS, attributes: %w[href title])
    fragment = Nokogiri::HTML5.fragment(formatted)
    @remaining = length
    @paragraphs = paragraphs
    @breaks = breaks
    @truncated = omitted_media || fragment.text.each_grapheme_cluster.take(length + 1).length > length ||
                 fragment.css('p, li').count { |node| node.text.strip.present? } > paragraphs ||
                 fragment.css('br').length > breaks
    trim_children(fragment) if truncated?
    @html = fragment.to_html.html_safe
  end

  def truncated?
    @truncated
  end

  private

  def trim_children(parent)
    parent.children.each do |node|
      if @stopped
        node.remove
      elsif node.text?
        trim_text(node)
      elsif node.element?
        trim_element(node)
      end
    end
  end

  def trim_text(node)
    clusters = node.content.each_grapheme_cluster.take(@remaining + 1)
    if clusters.length > @remaining
      prefix = clusters.take(@remaining).join
      prefix = prefix.sub(/\s+\S*\z/, '') if prefix.match?(/\S\z/) && clusters.last.match?(/\S/)
      node.content = "#{prefix.rstrip}…"
      @stopped = true
    else
      @remaining -= clusters.length
    end
  end

  def trim_element(node)
    if %w[p li].include?(node.name) && node.text.strip.present?
      return stop_at(node) if @paragraphs.zero?

      @paragraphs -= 1
    elsif node.name == 'br'
      return stop_at(node) if @breaks.zero?

      @breaks -= 1
    end
    trim_children(node)
  end

  def stop_at(node)
    # An omission marker belongs to the visible excerpt, never a hidden tail.
    previous = node.xpath('preceding::text()[normalize-space()]').last
    if previous
      previous.content = "#{previous.content.rstrip}…"
    else
      node.add_previous_sibling(Nokogiri::XML::Text.new('…', node.document))
    end
    node.remove
    @stopped = true
  end
end

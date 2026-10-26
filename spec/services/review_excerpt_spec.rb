# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewExcerpt do
  def parsed(excerpt)
    Nokogiri::HTML.fragment(excerpt.html)
  end

  it 'keeps short paragraphs, emphasis, and safe links complete' do
    body = "A <strong>great</strong> story.\n\nSee <a href=\"https://example.com/read\">this reading list</a>."
    excerpt = described_class.new(body)
    expect(excerpt).not_to be_truncated
    expect(parsed(excerpt).css('p').map(&:text)).to eq(['A great story.', 'See this reading list.'])
    expect(parsed(excerpt).at_css('strong').text).to eq('great')
    expect(parsed(excerpt).at_css('a')['href']).to eq('https://example.com/read')
  end

  it 'keeps a short list with nested paragraphs complete without double-counting its items' do
    excerpt = described_class.new('<ul><li><p>First thought.</p></li><li><p>Second thought.</p></li></ul>')
    expect(excerpt).not_to be_truncated
    expect(parsed(excerpt).css('li p').map(&:text)).to eq(['First thought.', 'Second thought.'])
  end

  it 'bounds one enormous paragraph and removes omitted links from the actual DOM' do
    excerpt = described_class.new("#{'Opening words. ' * 200}<a href=\"https://example.com/hidden\">Hidden tail</a>")
    expect(excerpt).to be_truncated
    expect(parsed(excerpt).text.strip.each_grapheme_cluster.count).to be <= 481
    expect(parsed(excerpt).text.strip).to end_with('…')
    expect(parsed(excerpt).css('a')).to be_empty
    expect(excerpt.html).not_to include('Hidden tail', '/hidden')
  end

  it 'retains meaningful paragraph boundaries and caps many short paragraphs' do
    excerpt = described_class.new("First thought.\n\nSecond thought.\n\nThird thought.\n\nA hidden fourth thought.")
    expect(excerpt).to be_truncated
    expect(parsed(excerpt).css('p').map(&:text)).to eq(['First thought.', 'Second thought.', 'Third thought.…'])
    expect(parsed(excerpt).text).not_to include('fourth')
  end

  it 'caps explicit line breaks instead of allowing hundreds of short lines' do
    excerpt = described_class.new((1..50).map { |n| "Line #{n}" }.join("\n"))
    expect(excerpt).to be_truncated
    expect(parsed(excerpt).css('br').length).to be <= 5
    expect(parsed(excerpt).text).not_to include('Line 50')
  end

  it 'never splits emoji sequences or combining Unicode characters' do
    cluster = "👩🏽‍🚀e\u0301"
    excerpt = described_class.new(cluster * 20, length: 10)
    expect(parsed(excerpt).text.strip).to eq("#{cluster * 5}…")
    expect(excerpt.html).to be_valid_encoding
  end

  it 'bounds unbroken text and leaves a boundary-length short review complete' do
    excerpt = described_class.new('x' * 20_000)
    expect(parsed(excerpt).text.strip.length).to eq(481)
    expect(described_class.new('x' * 480)).not_to be_truncated
  end

  it 'sanitizes active HTML while preserving a visible safe link' do
    excerpt = described_class.new('<a href="https://example.com">Read this</a>' \
                                  '<a href="javascript:alert(1)" onclick="alert(1)">Unsafe</a><script>alert(1)</script>')
    expect(parsed(excerpt).at_css('a')['href']).to eq('https://example.com')
    expect(parsed(excerpt).css('script, [onclick], [href^="javascript:"]')).to be_empty
  end

  it 'omits inline images from summaries with a full-review link flag' do
    excerpt = described_class.new('<img src="https://example.com/cover.png" alt="An illustration">')
    expect(excerpt).to be_truncated
    expect(parsed(excerpt).css('img')).to be_empty
  end
end

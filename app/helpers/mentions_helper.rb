# frozen_string_literal: true

module MentionsHelper
  def format_content_with_mentions(text)
    return '' if text.blank?

    # Using simple_format first so we get paragraphs and breaks, then sanitize, then gsub
    formatted = sanitize(simple_format(text))
    formatted.gsub(/@([a-zA-Z0-9_]+)/) do |mention|
      username = ::Regexp.last_match(1)
      user = User.find_by(username: username)
      if user
        link_to mention, user_path(user), class: 'mention-link', style: 'color: #818cf8; font-weight: 500;'
      else
        mention
      end
    end.html_safe
  end
end

# frozen_string_literal: true

# Lists are additive by stable identity, never replaced by position or refreshed away.
class BookChapterLists
  class Conflict < StandardError; end

  def self.reconcile(edition, rows)
    return 0 if rows.blank?

    edition.with_lock do
      rows.each do |row|
        existing = edition.book_chapters.find_by(position: row.fetch(:position))
        raise Conflict, 'A different chapter already occupies this position.' if
          existing && existing.identity_key != row.fetch(:identity_key)
      end
      rows.count do |row|
        chapter = edition.book_chapters.find_or_initialize_by(identity_key: row.fetch(:identity_key))
        # Preserve all existing chapter facts, reviews, progress, and IDs.
        next false unless chapter.new_record?

        chapter.assign_attributes(row)
        chapter.save!
        true
      end
    end
  end

  def self.manual(text)
    lines = text.to_s.lines.map(&:strip).reject(&:blank?)
    raise Conflict, 'Supply between 1 and 1000 chapter lines.' unless lines.size.between?(1, 1000)

    lines.each_with_index.map do |line, index|
      # Explicit optional grouping/label/title supports prologues and unnumbered chapters.
      part, label, title = line.split('|', 3).map { |value| value.strip.presence }
      unless line.include?('|')
        label = nil
        title = part
        part = nil
      end
      raise Conflict, 'Chapter fields must be 255 characters or fewer.' if [part, label, title].compact.any? do |s|
        s.size > 255
      end

      { identity_key: SecureRandom.uuid, position: index, part: part, label: label, title: title, provenance: 'manual' }
    end
  end
end

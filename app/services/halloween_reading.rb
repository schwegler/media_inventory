# frozen_string_literal: true

# Handwritten editorial copy, never provider metadata or a user's private review.
# Exact title AND author matches intentionally favor false negatives over adaptations.
class HalloweenReading
  PICKS = {
    ['Dracula', 'Bram Stoker'] =>
      'For a Halloween reading night, try following the trail of letters and diary entries in Dracula. ' \
      'Notice how each narrator knows only part of the danger: the gaps between their accounts create ' \
      'the suspense. Read a short section aloud, then compare what the next voice adds or leaves uncertain. ' \
      'An unabridged edition preserves that shifting structure; check the listing if you want the complete novel.',
    ['Frankenstein', 'Mary Shelley'] =>
      'Make Frankenstein a quieter Halloween choice by reading it as a story about responsibility. ' \
      'Keep two questions in mind: what does Victor owe his creation, and who gets to tell the creature’s story? ' \
      'The nested narrators make those questions harder than a simple monster tale suggests. ' \
      'Look for an edition that identifies its text: the 1818 and revised 1831 versions offer different reading paths.'
  }.freeze

  def self.for_title(item)
    return unless item.is_a?(Book)

    PICKS[[item.title, item.author]]
  end
end

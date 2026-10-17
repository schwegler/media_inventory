# frozen_string_literal: true

# Keep results proportional to the displayed titles, not the number of their owners.
class MediaCardRatings
  STANDARD_RATINGS = (1..10).map { |number| (number / 2.0).to_s }.freeze
  BATCH_SIZE = 250

  def self.key(item, user_id)
    [user_id, item.class.polymorphic_name, item.id]
  end

  def self.call(items, user_id: nil)
    new(items, user_id).call
  end

  def initialize(items, user_id)
    # Child media (episodes/issues/tracks) can be rated without a reverse association.
    @items = items.grep(ActiveRecord::Base).uniq
    @user_id = user_id
    @results = {}
  end

  def call
    # Do not let the request query cache retain all of the legacy scalar batches.
    LibraryItem.uncached do
      @items.group_by { |item| item.class.polymorphic_name }.each do |type, items|
        items.each_slice(BATCH_SIZE) { |batch| load_batch(type, batch) }
      end
    end
    @results
  end

  private

  def load_batch(type, items)
    ids = items.map(&:id)
    scope = LibraryItem.where(item_type: type, item_id: ids)
    visible = @user_id ? scope.where('is_public = ? OR user_id = ?', true, @user_id) : scope.where(is_public: true)
    totals = ids.to_h { |id| [id, [0.0, 0, 0.0]] }
    # At most ten counts per title, even if a title has millions of owners.
    visible.where(rating: STANDARD_RATINGS).group(:item_id, :rating).count.each do |(id, rating), count|
      add_rating(totals[id], rating.to_f * count, count)
    end
    add_legacy_ratings(visible, totals)
    own_ratings = user_ratings(scope)
    items.each do |item|
      sum, count, correction = totals.fetch(item.id)
      @results[self.class.key(item, @user_id)] = {
        user_rating: own_ratings[item.id].presence,
        avg_rating: count.positive? ? ((sum + correction) / count).round(1) : nil
      }
    end
  end

  def add_legacy_ratings(visible, totals)
    # rating is an unrestricted string. SQL casts differ from Ruby to_f (and can
    # raise on PostgreSQL), so preserve old conversions in bounded scalar batches.
    visible.where.not(rating: STANDARD_RATINGS + ['']).in_batches(of: BATCH_SIZE) do |batch|
      batch.pluck(:item_id, :rating).each do |id, rating|
        next if rating.blank?

        add_rating(totals[id], rating.to_f)
      end
    end
  end

  def add_rating(total, value, count = 1)
    # Like Array#sum, compensate for cancellation in legacy floating-point values.
    sum = total[0] + value
    total[2] += if total[0].abs >= value.abs
                  (total[0] - sum) + value
                else
                  (value - sum) + total[0]
                end
    total[0] = sum
    total[1] += count
  end

  def user_ratings(scope)
    return {} unless @user_id

    # One entry per title, including a private or unrated entry; never load its
    # review body. MIN(id) also keeps duplicate legacy entries deterministic.
    ids = scope.where(user_id: @user_id).group(:item_id).select('MIN(id)')
    LibraryItem.where(id: ids).pluck(:item_id, :rating).to_h
  end
end

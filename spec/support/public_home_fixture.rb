# frozen_string_literal: true

# Real provider titles/artwork, synthetic local catalog rows and clearly labeled accounts.
module PublicHomeFixture
  def build_public_home_fixture
    directory = Rails.root.join('spec/fixtures/files/discovery_covers')
    records = JSON.parse(directory.join('sources.json').read).map do |data|
      public_home_cover_record(data, directory)
    end
    %w[Riley Morgan].each_with_index do |name, index|
      owner = User.create!(name: "#{name} (QA fixture)", username: "#{name.downcase}_fixture", password: 'password',
                           confirmed_at: Time.current)
      picks = index.zero? ? records.first(5) : records.last(4)
      owner.favorite_shelves.create!(category: 'overall', picks: picks.map do |item|
        { 'type' => item.class.name, 'id' => item.id }
      end)
      owner.shelf_previews.attach(io: File.open(Rails.root.join('spec/fixtures/files/valid-cover.png')),
                                  filename: 'fixture-share-preview.png', content_type: 'image/png')
    end
    records
  end

  def public_home_cover_record(data, directory)
    record = data.fetch('type').constantize.new(title: data.fetch('title'))
    field = { 'Album' => 'artist', 'Book' => 'author', 'VideoGame' => 'developer' }[data['type']]
    record[field] = data['creator'] if field
    record.importing_metadata = true
    record.save!
    record.cover_image.attach(io: File.open(directory.join(data.fetch('file'))),
                              filename: data.fetch('file'), content_type: 'image/jpeg')
    record
  end
end

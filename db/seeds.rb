# frozen_string_literal: true

# Clear existing records
puts 'Clearing existing database records...'
VideoGame.delete_all
TvShow.delete_all
Movie.delete_all
Comic.delete_all
Album.delete_all
User.delete_all

puts 'Creating users...'
admin = User.create!(
  name: 'Admin User',
  email: 'admin@example.com',
  password: 'password',
  avatar_url: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&h=150&q=80',
  admin: true,
  confirmed_at: Time.current
)

user = User.create!(
  name: 'Example User',
  email: 'user@example.com',
  password: 'password',
  avatar_url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&h=150&q=80',
  admin: false,
  confirmed_at: Time.current
)

puts 'Seeding movies...'
movies_data = [
  {
    title: 'Inception',
    director: 'Christopher Nolan',
    release_year: 2010,
    rating: '5',
    is_public: true,
    user: admin
  },
  {
    title: 'Interstellar',
    director: 'Christopher Nolan',
    release_year: 2014,
    rating: '5',
    is_public: true,
    user: admin
  },
  {
    title: 'The Dark Knight',
    director: 'Christopher Nolan',
    release_year: 2008,
    rating: '5',
    is_public: true,
    user: user
  },
  {
    title: 'Pulp Fiction',
    director: 'Quentin Tarantino',
    release_year: 1994,
    rating: '5',
    is_public: true,
    user: user
  },
  {
    title: 'Inglourious Basterds',
    director: 'Quentin Tarantino',
    release_year: 2009,
    rating: '4.5',
    is_public: true,
    user: admin
  },
  {
    title: 'The Matrix',
    director: 'Wachowskis',
    release_year: 1999,
    rating: '5',
    is_public: true,
    user: user
  },
  {
    title: 'Dune',
    director: 'Denis Villeneuve',
    release_year: 2021,
    rating: '4.5',
    is_public: true,
    user: admin
  },
  {
    title: 'Blade Runner 2049',
    director: 'Denis Villeneuve',
    release_year: 2017,
    rating: '5',
    is_public: true,
    user: user
  },
  {
    title: 'Spirited Away',
    director: 'Hayao Miyazaki',
    release_year: 2001,
    rating: '5',
    is_public: true,
    user: admin
  },
  {
    title: 'My Neighbor Totoro',
    director: 'Hayao Miyazaki',
    release_year: 1988,
    rating: '4.5',
    is_public: true,
    user: user
  }
]
movies_data.each { |data| Movie.create!(data) }

puts 'Seeding albums...'
albums_data = [
  {
    title: 'The Dark Side of the Moon',
    artist: 'Pink Floyd',
    release_year: 1973,
    genre: 'Rock',
    is_public: true,
    user: admin
  },
  {
    title: 'Random Access Memories',
    artist: 'Daft Punk',
    release_year: 2013,
    genre: 'Electronic',
    is_public: true,
    user: user
  },
  {
    title: 'To Pimp a Butterfly',
    artist: 'Kendrick Lamar',
    release_year: 2015,
    genre: 'Hip Hop',
    is_public: true,
    user: admin
  },
  {
    title: 'Thriller',
    artist: 'Michael Jackson',
    release_year: 1982,
    genre: 'Pop',
    is_public: true,
    user: user
  },
  {
    title: 'OK Computer',
    artist: 'Radiohead',
    release_year: 1997,
    genre: 'Alternative Rock',
    is_public: true,
    user: admin
  },
  {
    title: 'Rumours',
    artist: 'Fleetwood Mac',
    release_year: 1977,
    genre: 'Rock',
    is_public: true,
    user: user
  }
]
albums_data.each { |data| Album.create!(data) }

puts 'Seeding comics...'
comics_data = [
  {
    title: 'The Amazing Spider-Man',
    writer: 'Stan Lee',
    artist: 'Steve Ditko',
    publisher: 'Marvel',
    issue_number: 1,
    is_public: true,
    user: admin
  },
  {
    title: 'Batman: The Dark Knight Returns',
    writer: 'Frank Miller',
    artist: 'Frank Miller',
    publisher: 'DC',
    issue_number: 1,
    is_public: true,
    user: user
  },
  {
    title: 'Watchmen',
    writer: 'Alan Moore',
    artist: 'Dave Gibbons',
    publisher: 'DC',
    issue_number: 1,
    is_public: true,
    user: admin
  },
  {
    title: 'The Walking Dead',
    writer: 'Robert Kirkman',
    artist: 'Tony Moore',
    publisher: 'Image Comics',
    issue_number: 1,
    is_public: true,
    user: user
  },
  {
    title: 'The Sandman',
    writer: 'Neil Gaiman',
    artist: 'Sam Kieth',
    publisher: 'Vertigo',
    issue_number: 1,
    is_public: true,
    user: admin
  }
]
comics_data.each { |data| Comic.create!(data) }

puts 'Seeding TV shows...'
tv_shows_data = [
  {
    title: 'Game of Thrones',
    network: 'HBO',
    api_id: '82',
    is_public: true,
    user: admin
  },
  {
    title: 'Breaking Bad',
    network: 'AMC',
    api_id: '169',
    is_public: true,
    user: user
  },
  {
    title: 'The Wire',
    network: 'HBO',
    api_id: '179',
    is_public: true,
    user: admin
  },
  {
    title: 'Succession',
    network: 'HBO',
    api_id: '27436',
    is_public: true,
    user: user
  },
  {
    title: 'Stranger Things',
    network: 'Netflix',
    api_id: '2993',
    is_public: true,
    user: admin
  }
]
tv_shows_data.each { |data| TvShow.create!(data) }

puts 'Seeding video games...'
video_games_data = [
  {
    title: 'Minecraft',
    developer: 'Mojang Studios',
    publisher: 'Mojang Studios',
    platform: 'PC',
    release_year: 2011,
    rating: '5',
    is_public: true,
    user: admin,
    consumed: true,
    consumed_at: Date.new(2011, 11, 18),
    review: 'An absolute masterpiece of creativity and sandbox survival. Spent hundreds of hours building worlds.'
  },
  {
    title: 'Portal 2',
    developer: 'Valve',
    publisher: 'Valve',
    platform: 'PC',
    release_year: 2011,
    rating: '5',
    is_public: true,
    user: user,
    consumed: true,
    consumed_at: Date.new(2011, 4, 19),
    review: 'Flawless puzzle mechanics, brilliant writing, and unforgettable characters. The co-op mode is also incredible!'
  },
  {
    title: 'Elden Ring',
    developer: 'FromSoftware',
    publisher: 'Bandai Namco',
    platform: 'PlayStation 5',
    release_year: 2022,
    rating: '5',
    is_public: true,
    user: admin,
    consumed: true,
    consumed_at: Date.new(2022, 3, 15),
    review: 'An incredible open world coupled with challenging combat. The sense of discovery is unmatched.'
  },
  {
    title: 'Chrono Trigger',
    developer: 'Square',
    publisher: 'Square',
    platform: 'SNES',
    release_year: 1995,
    rating: '5',
    is_public: true,
    user: user,
    consumed: true,
    consumed_at: Date.new(1995, 8, 11),
    review: 'Still the gold standard for JRPGs. Sublime soundtrack, timeless story, and great multiple endings.'
  },
  {
    title: 'The Legend of Zelda: Breath of the Wild',
    developer: 'Nintendo EPD',
    publisher: 'Nintendo',
    platform: 'Nintendo Switch',
    release_year: 2017,
    rating: '4.5',
    is_public: true,
    user: admin,
    in_watchlist: false,
    consumed: true,
    consumed_at: Date.new(2017, 4, 5)
  }
]
video_games_data.each { |data| VideoGame.create!(data) }

puts 'Database seeding complete! Seeded 2 users and 31 media items.'

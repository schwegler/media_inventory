# frozen_string_literal: true

# Clear existing records
puts "Clearing existing database records..."
WrestlingEvent.delete_all
TvShow.delete_all
Movie.delete_all
Comic.delete_all
Album.delete_all
User.delete_all

puts "Creating users..."
admin = User.create!(
  name: 'Admin User',
  email: 'admin@example.com',
  admin: true,
  confirmed_at: Time.current
)

user = User.create!(
  name: 'Example User',
  email: 'user@example.com',
  admin: false,
  confirmed_at: Time.current
)

puts "Seeding movies..."
movies_data = [
  { title: 'Inception', director: 'Christopher Nolan', release_year: 2010, rating: '5', is_public: true, user: admin },
  { title: 'Interstellar', director: 'Christopher Nolan', release_year: 2014, rating: '5', is_public: true, user: admin },
  { title: 'The Dark Knight', director: 'Christopher Nolan', release_year: 2008, rating: '5', is_public: true, user: user },
  { title: 'Pulp Fiction', director: 'Quentin Tarantino', release_year: 1994, rating: '5', is_public: true, user: user },
  { title: 'Inglourious Basterds', director: 'Quentin Tarantino', release_year: 2009, rating: '4.5', is_public: true, user: admin },
  { title: 'The Matrix', director: 'Wachowskis', release_year: 1999, rating: '5', is_public: true, user: user },
  { title: 'Dune', director: 'Denis Villeneuve', release_year: 2021, rating: '4.5', is_public: true, user: admin },
  { title: 'Blade Runner 2049', director: 'Denis Villeneuve', release_year: 2017, rating: '5', is_public: true, user: user },
  { title: 'Spirited Away', director: 'Hayao Miyazaki', release_year: 2001, rating: '5', is_public: true, user: admin },
  { title: 'My Neighbor Totoro', director: 'Hayao Miyazaki', release_year: 1988, rating: '4.5', is_public: true, user: user }
]
movies_data.each { |data| Movie.create!(data) }

puts "Seeding albums..."
albums_data = [
  { title: 'The Dark Side of the Moon', artist: 'Pink Floyd', release_year: 1973, genre: 'Rock', is_public: true, user: admin },
  { title: 'Random Access Memories', artist: 'Daft Punk', release_year: 2013, genre: 'Electronic', is_public: true, user: user },
  { title: 'To Pimp a Butterfly', artist: 'Kendrick Lamar', release_year: 2015, genre: 'Hip Hop', is_public: true, user: admin },
  { title: 'Thriller', artist: 'Michael Jackson', release_year: 1982, genre: 'Pop', is_public: true, user: user },
  { title: 'OK Computer', artist: 'Radiohead', release_year: 1997, genre: 'Alternative Rock', is_public: true, user: admin },
  { title: 'Rumours', artist: 'Fleetwood Mac', release_year: 1977, genre: 'Rock', is_public: true, user: user }
]
albums_data.each { |data| Album.create!(data) }

puts "Seeding comics..."
comics_data = [
  { title: 'The Amazing Spider-Man', writer: 'Stan Lee', artist: 'Steve Ditko', publisher: 'Marvel', issue_number: 1, is_public: true, user: admin },
  { title: 'Batman: The Dark Knight Returns', writer: 'Frank Miller', artist: 'Frank Miller', publisher: 'DC', issue_number: 1, is_public: true, user: user },
  { title: 'Watchmen', writer: 'Alan Moore', artist: 'Dave Gibbons', publisher: 'DC', issue_number: 1, is_public: true, user: admin },
  { title: 'The Walking Dead', writer: 'Robert Kirkman', artist: 'Tony Moore', publisher: 'Image Comics', issue_number: 1, is_public: true, user: user },
  { title: 'The Sandman', writer: 'Neil Gaiman', artist: 'Sam Kieth', publisher: 'Vertigo', issue_number: 1, is_public: true, user: admin }
]
comics_data.each { |data| Comic.create!(data) }

puts "Seeding TV shows..."
tv_shows_data = [
  { title: 'Game of Thrones', season: 1, episode: 1, network: 'HBO', is_public: true, user: admin },
  { title: 'Breaking Bad', season: 5, episode: 16, network: 'AMC', is_public: true, user: user },
  { title: 'The Wire', season: 1, episode: 1, network: 'HBO', is_public: true, user: admin },
  { title: 'Succession', season: 4, episode: 10, network: 'HBO', is_public: true, user: user },
  { title: 'Stranger Things', season: 4, episode: 9, network: 'Netflix', is_public: true, user: admin }
]
tv_shows_data.each { |data| TvShow.create!(data) }

puts "Seeding wrestling events..."
wrestling_events_data = [
  { title: 'WrestleMania III', promotion: 'WWE', date: Date.new(1987, 3, 29), venue: 'Pontiac Silverdome', is_public: true, user: admin },
  { title: 'WrestleMania X-Seven', promotion: 'WWE', date: Date.new(2001, 4, 1), venue: 'Astrodome', is_public: true, user: user },
  { title: 'All In London', promotion: 'AEW', date: Date.new(2023, 8, 27), venue: 'Wembley Stadium', is_public: true, user: admin },
  { title: 'Wrestle Kingdom 11', promotion: 'NJPW', date: Date.new(2017, 1, 4), venue: 'Tokyo Dome', is_public: true, user: user },
  { title: 'Starrcade \'97', promotion: 'WCW', date: Date.new(1997, 12, 28), venue: 'MCI Center', is_public: true, user: admin }
]
wrestling_events_data.each { |data| WrestlingEvent.create!(data) }

puts "Database seeding complete! Seeded 2 users and 31 media items."

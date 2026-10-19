# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Favorite shelves', type: :request do
  let(:user) { User.create!(name: 'Shelf User', username: 'shelf_user', email: 'shelf@example.com', password: 'password') }
  let(:movie) { Movie.create!(title: 'A favorite') }

  def login
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  it 'saves owner presentation for guests and rejects other users' do
    login
    patch shelf_path(user.username), params: { presentation: { theme: 'gallery', layout: 'collector' } }, as: :json
    expect(response).to have_http_status(:ok)
    delete logout_path
    get shelf_path(user.username, theme: 'electric')
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('.favorite-shelf')['data-shelf-theme']).to eq('gallery')
    expect(page.css('.shelf-themes, .shelf-customization')).to be_empty
    other = User.create!(name: 'Visitor', email: 'visitor@example.com', password: 'password')
    post login_path, params: { session: { email: other.email, password: 'password' } }
    get shelf_path(user.username)
    visitor_page = Nokogiri::HTML(response.body)
    expect(visitor_page.css('.shelf-themes, .shelf-customization, .shelf-headline-editor')).to be_empty
    expect(visitor_page.at_css('.favorite-shelf')['data-favorite-shelf-owner-value']).to eq('false')
    patch shelf_path(user.username), params: { presentation: { theme: 'electric' } }, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(user.reload.shelf_presentation['theme']).to eq('gallery')
  end

  it 'keeps named seasonal collections independent of existing shelves' do
    original = user.favorite_shelves.create!(category: 'overall', picks: [{ type: 'Movie', id: movie.id }])
    login
    %w[Halloween Christmas Everyday].each do |title|
      patch shelf_path(user.username), params: { new_collection: { title: title, description: 'A little context' } }
      expect(response).to have_http_status(:see_other)
    end
    expect(user.shelf_collections.count).to eq(3)
    collection = user.shelf_collections.find_by!(title: 'Christmas')
    patch shelf_path(user.username, collection: collection.slug), params: { picks: [{ type: 'Movie', id: movie.id }] },
                                                                  as: :json
    expect(response).to have_http_status(:ok)
    expect(original.reload.items).to eq([movie])
    delete logout_path
    get shelf_path(user.username)
    expect(response.body).to include('Christmas')
    expect(response.body).not_to include('>Halloween</a>', '>Everyday</a>')
    get shelf_path(user.username, collection: collection.slug)
    expect(response.body).to include('Christmas', 'A little context', movie.title)
    expect(response.body).not_to include('Create collection', 'Save shelf')
  end

  it 'offers a private owner visitor preview and preserves collection identity when editing details' do
    collection = user.shelf_collections.create!(title: 'Halloween', picks: [{ type: 'Movie', id: movie.id }])
    login
    get shelf_path(user.username, collection: collection.slug, view: 'visitor')
    page = Nokogiri::HTML(response.body)
    expect(page.css('.shelf-themes, .shelf-customization, .shelf-headline-editor')).to be_empty
    expect(page.at_css('.favorite-shelf')['data-favorite-shelf-owner-value']).to eq('false')
    patch shelf_path(user.username, collection: collection.slug),
          params: { collection_details: { title: 'Halloween nights', description: 'A new description' } }
    expect(response).to redirect_to(shelf_path(user.username, collection: collection.slug))
    expect(collection.reload.items).to eq([movie])
    expect(collection.title).to eq('Halloween nights')
  end

  it 'imports a signed external pick without library ownership and deduplicates provider IDs' do
    login
    selection = MetadataImport.sign('book', { title: 'An API discovery', api_id: 'openlibrary_OL123W' })
    expect do
      2.times do
        post shelf_catalog_items_path, params: { type: 'book', selection: selection }, as: :json
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['title']).to eq('An API discovery')
      end
    end.to change(Book, :count).by(1).and change(LibraryItem, :count).by(0)
    post shelf_catalog_items_path, params: { type: 'book', selection: 'tampered' }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    delete logout_path
    post shelf_catalog_items_path, params: { type: 'book', selection: selection }, as: :json
    expect(response).to have_http_status(:redirect)
  end

  it 'includes item destinations in the interactive shelf data and search results' do
    user.favorite_shelves.create!(category: 'Movie', picks: [{ type: 'Movie', id: movie.id }])
    get shelf_path(user.username, category: 'Movie')
    page = Nokogiri::HTML(response.body)
    picks = JSON.parse(page.at_css('.favorite-shelf')['data-favorite-shelf-picks-value'])
    expect(picks.first['url']).to eq(movie_path(movie))
    login
    get search_shelves_path(category: 'Movie', q: 'favorite')
    expect(response.parsed_body.first['url']).to eq(movie_path(movie))
  end

  it 'does not publish on visits and deduplicates explicit same-signature previews' do
    login
    get shelf_path(user.username, category: 'Movie')
    doc = Nokogiri::HTML(response.body)
    expect(doc.text).to include('Publish share preview')
    expect(user.shelf_previews.count).to eq(0)
    signature = doc.at_css('.favorite-shelf')['data-favorite-shelf-preview-signature-value']
    2.times do
      patch shelf_path(user.username, category: 'Movie'), params: {
        preview_image: fixture_file_upload('transparent-logo.png', 'image/png'), preview_category: 'Movie',
        preview_signature: signature, theme: 'midnight'
      }
      expect(response).to have_http_status(:no_content)
    end
    expect(user.shelf_previews.count).to eq(1)
    delete logout_path
    get shelf_path(user.username)
    expect(Nokogiri::HTML(response.body).text).to include('taking shape.', 'Explore Shelf User’s library')
  end

  it 'stores generated previews for public social cards and rejects stale previews' do
    user.favorite_shelves.create!(category: 'Movie', picks: [{ type: 'Movie', id: movie.id }])
    login
    get shelf_path(user.username, category: 'Movie')
    page = Nokogiri::HTML(response.body)
    signature = page.at_css('.favorite-shelf')['data-favorite-shelf-preview-signature-value']
    image = fixture_file_upload('transparent-logo.png', 'image/png')
    patch shelf_path(user.username, category: 'Movie'), params: {
      preview_image: image, preview_category: 'Movie', preview_signature: signature, theme: 'midnight'
    }
    expect(response).to have_http_status(:no_content)
    delete logout_path
    get shelf_path(user.username, category: 'Movie')
    page = Nokogiri::HTML(response.body)
    preview = page.at_css('meta[property="og:image"]')['content']
    expect(preview).to include('/rails/active_storage/blobs/')
    expect(page.at_css('meta[name="twitter:image"]')['content']).to eq(preview)
    get shelf_path(user.username, category: 'Movie', theme: 'gallery')
    page_html = Nokogiri::HTML(response.body)
    expect(page_html.at_css('meta[property="og:image"]')['content']).to end_with('/brand/trove_logo_dark_card.png')
    user.update!(shelf_headline: 'Changed')
    get shelf_path(user.username, category: 'Movie')
    page_html = Nokogiri::HTML(response.body)
    expect(page_html.at_css('meta[property="og:image"]')['content']).to end_with('/brand/trove_logo_dark_card.png')
    login
    patch shelf_path(user.username, category: 'Movie'), params: {
      preview_image: fixture_file_upload('transparent-logo.png', 'image/png'), preview_category: 'Movie',
      preview_signature: signature, theme: 'midnight'
    }
    expect(response).to have_http_status(:conflict)
  end

  it 'resolves handles and redirects legacy profile links while preserving tabs' do
    get handle_profile_path(user.username)
    expect(response).to have_http_status(:ok)
    get user_path(user, tab: 'collection')
    expect(response).to redirect_to(handle_profile_path(user.username, tab: 'collection'))
  end

  it 'saves ranked picks and renders a public shelf without review content' do
    login
    patch shelf_path(user.username, category: 'Movie'), params: { picks: [{ type: 'Movie', id: movie.id }] }, as: :json
    expect(response).to have_http_status(:ok)
    expect(user.favorite_shelves.find_by!(category: 'Movie').items).to eq([movie])
    delete logout_path
    get shelf_path(user.username, category: 'Movie')
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('A favorite', 'Download image')
    expect(response.body).not_to include('Save shelf')
  end

  it 'exhibits only populated shelves to visitors' do
    user.favorite_shelves.create!(category: 'Movie', picks: [{ type: 'Movie', id: movie.id }])
    get shelf_path(user.username)
    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.css('.shelf-exhibit').size).to eq(1)
    expect(page.css('.shelf-exhibit h2').map(&:text)).to eq(['Movies'])
    expect(page.css('.shelf-exhibit').map(&:text).join).to include(movie.title)
    expect(page.css('.shelf-formats input').map { |input| input['value'] }).to eq(%w[landscape portrait])
    expect(page.css('.favorite-shelf-slots')).to be_empty
  end

  it 'renders site navigation on public and signed-in shelves' do
    [false, true].each do |signed_in|
      login if signed_in
      [nil, 'Movie'].each do |category|
        get shelf_path(user.username, category: category, theme: 'electric')
        expect(response).to have_http_status(:ok)
        page = Nokogiri::HTML(response.body)
        expect(page.css('.app-header').size).to eq(1)
        expect(page.at_css('.brand-link')['href']).to eq(root_path)
        expect(page.at_css("#mobile-navigation a[href='#{movies_path}']")).to be_present
        expect(page.at_css('.favorite-shelf')['data-shelf-theme']).to eq('electric')
        expect(page.at_css('turbo-frame#modal')).to be_present
        expect(page.at_css('button[data-action="favorite-shelf#copyAltText"]').text).to eq('Copy image alt text')
        expect(page.at_css('textarea[data-favorite-shelf-target="altText"]')['readonly']).to be_present
        toolbar_links = page.css('.shelf-toolbar-links a')
        expected_links = [signed_in ? 'View shelf overview' : 'All shelves']
        expected_links << 'Edit selections' if signed_in && category.nil?
        expected_links += ['Customize profile', 'Preview as visitor'] if signed_in
        expect(toolbar_links.map(&:text)).to eq(expected_links + ['View profile', 'Share'])
        overview = toolbar_links.find { |link| link.text == (signed_in ? 'View shelf overview' : 'All shelves') }
        expect(URI.parse(overview['href']).path).to eq(shelf_path(user.username))
        expect(Rack::Utils.parse_nested_query(URI.parse(overview['href']).query)).not_to have_key('category')
        if signed_in
          expect(page.at_css('[aria-label="Account menu"]')).to be_present
        else
          expect(page.at_css(".app-header a[href='#{login_path}']")).to be_present
        end
      end
    end
  end

  it 'carries supported themes through shelf links and safely defaults unknown themes' do
    get shelf_path(user.username, theme: 'gallery')
    page = Nokogiri::HTML(response.body)
    expect(page.at_css('.favorite-shelf')['data-shelf-theme']).to eq('gallery')
    expect(page.css('.shelf-exhibit').all? { |link| link['href'].include?('theme=gallery') }).to be(true)
    get shelf_path(user.username, theme: 'unknown')
    expect(Nokogiri::HTML(response.body).at_css('.favorite-shelf')['data-shelf-theme']).to eq('midnight')
  end

  it 'lets the owner save a public headline and restore the default' do
    login
    patch shelf_path(user.username, theme: 'electric'), params: { shelf_headline: '  My favorite distractions.  ' }
    expect(response).to redirect_to(shelf_path(user.username, theme: 'electric'))
    expect(user.reload.shelf_headline).to eq('My favorite distractions.')
    get shelf_path(user.username)
    expect(Nokogiri::HTML(response.body).at_css('h1').text).to eq('My favorite distractions.')
    expect(response.body).to include('Edit headline')
    delete logout_path
    get shelf_path(user.username)
    expect(response.body).to include('My favorite distractions.')
    expect(response.body).not_to include('Edit headline')
    login
    patch shelf_path(user.username), params: { shelf_headline: '   ' }
    expect(user.reload.shelf_headline).to be_nil
    get shelf_path(user.username)
    expect(Nokogiri::HTML(response.body).at_css('h1').text).to eq('The thingsI keep.')
  end

  it 'rejects oversized headlines and changes from other users' do
    login
    patch shelf_path(user.username), params: { shelf_headline: 'x' * 81 }
    expect(user.reload.shelf_headline).to be_nil
    other = User.create!(name: 'Other', username: 'other', password: 'password')
    patch shelf_path(other.username), params: { shelf_headline: 'Changed' }
    expect(response).to have_http_status(:forbidden)
    expect(other.reload.shelf_headline).to be_nil
  end

  it 'rejects another user modifying the shelf' do
    login
    other = User.create!(name: 'Other', username: 'other', password: 'password')
    patch shelf_path(other.username, category: 'overall'), params: { picks: [] }, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'rejects duplicates, overfull shelves, and wrong media types' do
    login
    pick = { type: 'Movie', id: movie.id }
    [[pick, pick], Array.new(6, pick)].each do |picks|
      patch shelf_path(user.username, category: 'overall'), params: { picks: picks }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
    patch shelf_path(user.username, category: 'Book'), params: { picks: [pick] }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'searches the catalog with media filtering' do
    login
    movie
    get search_shelves_path(category: 'Movie', q: 'favorite')
    expect(response.parsed_body.first['title']).to eq('A favorite')
    get search_shelves_path(category: 'Book', q: 'favorite')
    expect(response.parsed_body).to eq([])
  end
  it 'keeps curated image choices in shared links and publishes each chosen style explicitly' do
    login
    get shelf_path(user.username, category: 'Movie', theme: 'telly', layout: 'reading',
                                  texture: 'stars', companion: 'facet')
    doc = Nokogiri::HTML(response.body)
    section = doc.at_css('.favorite-shelf')
    expect(section['data-shelf-theme']).to eq('telly')
    expect(JSON.parse(section['data-favorite-shelf-style-value'])).to eq(
      'layout' => 'reading', 'texture' => 'stars', 'companion' => 'facet'
    )
    signature = section['data-favorite-shelf-preview-signature-value']
    %w[reading collector].each do |layout|
      patch shelf_path(user.username, category: 'Movie'), params: {
        preview_image: fixture_file_upload('transparent-logo.png', 'image/png'), preview_category: 'Movie',
        preview_signature: signature, theme: 'telly', layout: layout, texture: 'stars', companion: 'facet'
      }
      expect(response).to have_http_status(:no_content)
    end
    expect(user.shelf_previews.count).to eq(1)
    expect(user.shelf_previews.first.blob.metadata['style']['layout']).to eq('collector')
    get shelf_path(user.username, theme: 'facet', layout: 'unknown', texture: 'invalid', companion: 'other')
    style = JSON.parse(Nokogiri::HTML(response.body).at_css('.favorite-shelf')['data-favorite-shelf-style-value'])
    expect(style).to eq('layout' => 'exhibition', 'texture' => 'clean', 'companion' => 'auto')
  end
  it 'separates the showcase overview from editing Overall and retains presentation choices' do
    login
    get shelf_path(user.username, category: 'overall', theme: 'electric', layout: 'reading',
                                  texture: 'stars', companion: 'facet')
    doc = Nokogiri::HTML(response.body)
    overview = doc.at_css('a.shelf-overview-link')
    query = Rack::Utils.parse_nested_query(URI.parse(overview['href']).query)
    expect(query).to include('theme' => 'electric', 'layout' => 'reading', 'texture' => 'stars', 'companion' => 'facet')
    expect(query).not_to have_key('category')
    expect(doc.at_css('.shelf-view-state').text).to eq('Editing Overall selections')
    expect(doc.at_css('.shelf-heading > a')['href']).to eq(overview['href'])
    get overview['href']
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('.shelf-view-state').text).to eq('Viewing shelf overview')
    edit = doc.css('a').find { |link| link.text == 'Edit selections' }
    expect(edit['href']).to include('category=overall', 'theme=electric', 'layout=reading')
    expect(doc.at_css('.shelf-overview-link')['aria-current']).to eq('page')
  end
  it 'offers Midnight Feature separately and accepts its explicitly published preview' do
    login
    get shelf_path(user.username, category: 'Movie', theme: 'midnight_feature')
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('.favorite-shelf')['data-shelf-theme']).to eq('midnight_feature')
    expect(doc.css('.shelf-themes label').map(&:text)).to include('Midnight Feature', 'Halloween')
    signature = doc.at_css('.favorite-shelf')['data-favorite-shelf-preview-signature-value']
    patch shelf_path(user.username, category: 'Movie'), params: {
      preview_image: fixture_file_upload('transparent-logo.png', 'image/png'), preview_category: 'Movie',
      preview_signature: signature, theme: 'midnight_feature', layout: 'collector'
    }
    expect(response).to have_http_status(:no_content)
    expect(user.shelf_previews.first.blob.metadata).to include('theme' => 'midnight_feature')
  end
  it 'keeps an escaped custom headline primary in category pages, metadata and published signatures' do
    headline = "it's finally spooky szn 🦇 <script>no()</script>"
    user.update!(shelf_headline: headline)
    [nil, 'overall', 'Book'].each do |category|
      get shelf_path(user.username, category: category, theme: 'halloween')
      doc = Nokogiri::HTML(response.body)
      expect(doc.at_css('h1').text).to include(headline)
      expect(doc.at_css('.favorite-shelf')['data-favorite-shelf-headline-value']).to eq(headline)
      expect(doc.at_css('meta[property="og:title"]')['content']).to include(headline)
      expect(doc.at_css('meta[property="og:description"]')['content']).to include(headline)
      expect(doc.css('.shelf-heading script')).to be_empty
      expect(doc.text).not_to include('Five favorites.', 'My top five')
    end
    old_signature = controller.helpers.shelf_preview_signature(user, 'Book')
    user.update!(shelf_headline: 'a different night')
    expect(controller.helpers.shelf_preview_signature(user, 'Book')).not_to eq(old_signature)
  end
end

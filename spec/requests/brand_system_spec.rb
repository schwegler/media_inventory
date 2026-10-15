# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Brand system and mascot assets', type: :request do
  let(:brand_asset_names) do
    %w[
      facet_pose_01_bookworm.png
      facet_pose_02_gamer_mode.png
      facet_pose_03_crate_digger.png
      facet_pose_04_five_star.png
      mascot_duo_telly_and_facet_transparent.png
      trove_rounded_app_icon.png
      trove_logo_dark_card.png
      trove_logo_light_card.png
      trove_favicon_32px.png
    ]
  end

  it 'provides all official Facet mascot poses and Trove logo assets' do
    brand_asset_names.each do |filename|
      path = Rails.root.join('app', 'assets', 'images', 'brand', filename)
      expect(File.exist?(path)).to be(true), "Expected #{filename} to exist in app/assets/images/brand/"
      header = File.binread(path, 26)
      expect(header[0, 8]).to eq("\x89PNG\r\n\x1a\n".b), "Expected #{filename} to be a valid PNG file"

      if filename == 'trove_rounded_app_icon.png'
        # Ensure RGBA color type (type 6) so transparent corners render cleanly in dark mode
        expect(header[25].ord).to eq(6), 'Expected trove_rounded_app_icon.png to have an alpha channel (color type 6)'
      end
    end
  end

  it 'compiles design tokens with refined palette and mascot utility rules' do
    tokens_path = Rails.root.join('app', 'assets', 'stylesheets', '_tokens.scss')
    content = File.read(tokens_path)
    expect(content).to include('--canvas: #f7f7fa;')
    expect(content).to include('--canvas: #111119;')
    expect(content).to include('--violet: #6d3acb;')
    expect(content).to include('--violet: #cab5ff;')
    expect(content).to include('.mascot-sticker')
    expect(content).to include('.mascot-slot-hero')
  end
end

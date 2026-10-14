# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Entity Header Layout Boundary', type: :request do
  let!(:entity) { MetadataEntity.create!(name: 'Nicole Robinson', kind: 'person') }

  it 'renders entity page cleanly inside main content container without escaping navigation' do
    get metadata_entity_path(entity)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<main id="main-content"')
    expect(response.body).to include('class="catalog-page entity-page"')
    expect(response.body).to include('Nicole Robinson')
    # Verify global navigation is present once
    expect(response.body.scan('<header class="app-header"').size).to eq(1)
  end
end

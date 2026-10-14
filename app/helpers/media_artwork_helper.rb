# frozen_string_literal: true

module MediaArtworkHelper
  def media_cover_image(item, **)
    url = item.stored_cover_url
    sources = MediaArtworkRendition::SIZES.map { |width, _| "#{url}?width=#{width} #{width}w" }.join(', ')
    image_tag(url, srcset: sources, sizes: '(max-width: 600px) 45vw, 240px',
                   loading: 'lazy', decoding: 'async', **)
  end

  def artwork_lightbox(url, label, &)
    link_to(url, class: 'artwork-zoom', aria: { label: "View #{label} at full size" },
                 data: { controller: 'artwork-lightbox', action: 'click->artwork-lightbox#open',
                         artwork_lightbox_label_value: label }, &)
  end
end

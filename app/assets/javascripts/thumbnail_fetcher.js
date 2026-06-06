// Debounce helper to prevent overloading APIs
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

// Main fetcher function
function initThumbnailFetcher() {
  const forms = document.querySelectorAll('form');
  
  forms.forEach(form => {
    // Determine media type based on input names present in the form
    let mediaType = null;
    let titleInput = null;
    let secondaryInput = null; // artist, writer, promotion etc.

    if (form.querySelector('input[name="movie[title]"]')) {
      mediaType = 'movie';
      titleInput = form.querySelector('input[name="movie[title]"]');
      secondaryInput = form.querySelector('input[name="movie[director]"]');
    } else if (form.querySelector('input[name="album[title]"]')) {
      mediaType = 'album';
      titleInput = form.querySelector('input[name="album[title]"]');
      secondaryInput = form.querySelector('input[name="album[artist]"]');
    } else if (form.querySelector('input[name="comic[title]"]')) {
      mediaType = 'comic';
      titleInput = form.querySelector('input[name="comic[title]"]');
      secondaryInput = form.querySelector('input[name="comic[writer]"]') || form.querySelector('input[name="comic[artist]"]');
    } else if (form.querySelector('input[name="tv_show[title]"]')) {
      mediaType = 'tv_show';
      titleInput = form.querySelector('input[name="tv_show[title]"]');
    } else if (form.querySelector('input[name="wrestling_event[title]"]')) {
      mediaType = 'wrestling_event';
      titleInput = form.querySelector('input[name="wrestling_event[title]"]');
      secondaryInput = form.querySelector('input[name="wrestling_event[promotion]"]');
    }

    if (!titleInput) return;

    // Create thumbnail preview and selection UI if not already present
    let container = form.querySelector('.thumbnail-fetcher-container');
    if (!container) {
      container = document.createElement('div');
      container.className = 'thumbnail-fetcher-container';
      container.innerHTML = `
        <label>Thumbnail Cover</label>
        <div class="thumbnail-fetcher-layout">
          <div class="thumbnail-preview-box">
            <img class="thumbnail-preview-img" src="" alt="Cover Preview" style="display: none;">
            <div class="thumbnail-preview-placeholder">No Cover</div>
          </div>
          <div class="thumbnail-options-box">
            <span class="fetcher-status-text">Type title to fetch covers...</span>
            <div class="thumbnail-options-grid"></div>
          </div>
        </div>
        <input type="hidden" name="${mediaType}[thumbnail_url]" class="thumbnail-url-hidden">
      `;
      // Insert container after the title field row
      const titleRow = titleInput.closest('div');
      if (titleRow) {
        titleRow.after(container);
      } else {
        form.prepend(container);
      }
    }

    const previewImg = container.querySelector('.thumbnail-preview-img');
    const placeholder = container.querySelector('.thumbnail-preview-placeholder');
    const statusText = container.querySelector('.fetcher-status-text');
    const optionsGrid = container.querySelector('.thumbnail-options-grid');
    const hiddenInput = container.querySelector('.thumbnail-url-hidden');

    // Pre-populate if hidden input already has a value (e.g. edit form)
    if (hiddenInput.value) {
      previewImg.src = hiddenInput.value;
      previewImg.style.display = 'block';
      placeholder.style.display = 'none';
    }

    const fetchThumbnails = async () => {
      const title = titleInput.value.trim();
      if (!title) {
        optionsGrid.innerHTML = '';
        statusText.textContent = 'Type title to fetch covers...';
        return;
      }

      statusText.textContent = 'Searching web for covers...';
      optionsGrid.innerHTML = '';

      let query = title;
      if (secondaryInput && secondaryInput.value.trim()) {
        query += ' ' + secondaryInput.value.trim();
      }

      try {
        let results = [];

        if (mediaType === 'movie') {
          const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&media=movie&limit=5`;
          const response = await fetch(url);
          const data = await response.json();
          results = (data.results || []).map(r => r.artworkUrl100 ? r.artworkUrl100.replace('100x100bb', '400x400bb') : null).filter(Boolean);
        } else if (mediaType === 'album') {
          const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&media=music&entity=album&limit=5`;
          const response = await fetch(url);
          const data = await response.json();
          results = (data.results || []).map(r => r.artworkUrl100 ? r.artworkUrl100.replace('100x100bb', '500x500bb') : null).filter(Boolean);
        } else if (mediaType === 'tv_show') {
          const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&media=tvShow&limit=5`;
          const response = await fetch(url);
          const data = await response.json();
          results = (data.results || []).map(r => r.artworkUrl100 ? r.artworkUrl100.replace('100x100bb', '400x400bb') : null).filter(Boolean);
        } else if (mediaType === 'comic') {
          // Google Books API is great for comics
          const url = `https://www.googleapis.com/books/v1/volumes?q=${encodeURIComponent(query)}&maxResults=5`;
          const response = await fetch(url);
          const data = await response.json();
          results = (data.items || []).map(item => {
            const imageLinks = item.volumeInfo?.imageLinks;
            return imageLinks?.thumbnail || imageLinks?.smallThumbnail;
          }).filter(Boolean).map(url => url.replace('http://', 'https://'));
        } else if (mediaType === 'wrestling_event') {
          // Fallback search on iTunes first
          const url = `https://itunes.apple.com/search?term=${encodeURIComponent(query)}&limit=5`;
          const response = await fetch(url);
          const data = await response.json();
          results = (data.results || []).map(r => r.artworkUrl100 ? r.artworkUrl100.replace('100x100bb', '400x400bb') : null).filter(Boolean);
        }

        if (results.length === 0) {
          statusText.textContent = 'No covers found. Standard category icon will be used.';
          return;
        }

        statusText.textContent = 'Select a cover:';
        
        results.forEach((imgUrl, index) => {
          const imgBtn = document.createElement('div');
          imgBtn.className = 'thumbnail-option-card';
          imgBtn.innerHTML = `<img src="${imgUrl}" alt="Option ${index + 1}">`;
          
          imgBtn.addEventListener('click', () => {
            // Unselect others
            container.querySelectorAll('.thumbnail-option-card').forEach(card => card.classList.remove('selected'));
            imgBtn.classList.add('selected');
            
            // Set value and preview
            hiddenInput.value = imgUrl;
            previewImg.src = imgUrl;
            previewImg.style.display = 'block';
            placeholder.style.display = 'none';
          });

          optionsGrid.appendChild(imgBtn);
        });

        // Automatically select the first cover
        const firstCard = optionsGrid.querySelector('.thumbnail-option-card');
        if (firstCard) {
          firstCard.click();
        }

      } catch (err) {
        console.error('Error fetching thumbnails:', err);
        statusText.textContent = 'Error loading covers.';
      }
    };

    const debouncedFetch = debounce(fetchThumbnails, 600);

    // Fetch when title or secondary details change
    titleInput.addEventListener('input', debouncedFetch);
    if (secondaryInput) {
      secondaryInput.addEventListener('input', debouncedFetch);
    }
  });
}

// Toggle consumed date visibility
function initConsumedDateToggles() {
  const checkboxes = document.querySelectorAll('input[name$="[consumed]"]');
  checkboxes.forEach(cb => {
    const form = cb.closest('form');
    if (form) {
      const dateField = form.querySelector('.consumed-date-row');
      if (dateField) {
        dateField.style.display = cb.checked ? 'block' : 'none';
      }
    }
  });
}

// Bind load events
document.addEventListener('turbolinks:load', () => {
  initThumbnailFetcher();
  initConsumedDateToggles();
});

if (!window.Turbolinks) {
  document.addEventListener('DOMContentLoaded', () => {
    initThumbnailFetcher();
    initConsumedDateToggles();
  });
}

// Listen to checkbox changes dynamically
document.addEventListener('change', (event) => {
  if (event.target.name && event.target.name.endsWith('[consumed]')) {
    const form = event.target.closest('form');
    if (form) {
      const dateField = form.querySelector('.consumed-date-row');
      if (dateField) {
        dateField.style.display = event.target.checked ? 'block' : 'none';
      }
    }
  }
});

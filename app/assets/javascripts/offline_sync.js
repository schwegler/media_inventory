// Register Service Worker
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/service-worker.js')
      .then(registration => {
        console.log('[Service Worker] Registered with scope:', registration.scope);
      })
      .catch(error => {
        console.error('[Service Worker] Registration failed:', error);
      });
  });
}

const DB_NAME = 'MediaInventoryOfflineDB';
const DB_VERSION = 1;
const STORE_NAME = 'pending_sync';

// Open IndexedDB
function openDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onerror = () => reject(request.error);
    request.onsuccess = () => resolve(request.result);
    request.onupgradeneeded = (event) => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: 'id', autoIncrement: true });
      }
    };
  });
}

// Add item to IndexedDB
async function addPendingItem(item) {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(STORE_NAME, 'readwrite');
    const store = transaction.objectStore(STORE_NAME);
    const request = store.add(item);
    transaction.oncomplete = () => resolve(request.result);
    transaction.onerror = () => reject(transaction.error);
  });
}

// Get all pending items
async function getPendingItems() {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(STORE_NAME, 'readonly');
    const store = transaction.objectStore(STORE_NAME);
    const request = store.getAll();
    transaction.oncomplete = () => resolve(request.result);
    transaction.onerror = () => reject(transaction.error);
  });
}

// Delete item
async function deletePendingItem(id) {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(STORE_NAME, 'readwrite');
    const store = transaction.objectStore(STORE_NAME);
    store.delete(id);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
  });
}

// Update item (e.g. status)
async function updatePendingItem(item) {
  const db = await openDB();
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(STORE_NAME, 'readwrite');
    const store = transaction.objectStore(STORE_NAME);
    store.put(item);
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
  });
}

let isSyncing = false;

// Trigger synchronization of offline submissions
async function syncPendingData() {
  if (isSyncing || !navigator.onLine) return;
  
  const items = await getPendingItems();
  const pendingItems = items.filter(item => item.status === 'pending');
  if (pendingItems.length === 0) return;

  isSyncing = true;
  
  const banner = document.getElementById('offline-banner');
  const bannerText = document.getElementById('offline-banner-text');
  const badge = document.getElementById('nav-sync-badge');
  
  if (banner) {
    banner.className = 'offline-banner visible syncing';
    if (bannerText) {
      bannerText.innerHTML = '<span class="sync-spinner"></span> Syncing local database...';
    }
  }
  if (badge) {
    badge.className = 'nav-sync-badge syncing';
    badge.textContent = 'Syncing...';
  }

  let successCount = 0;
  let failCount = 0;
  const currentCsrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');

  for (const item of pendingItems) {
    try {
      const params = new URLSearchParams();
      for (const [name, value] of item.entries) {
        if (name === 'authenticity_token' && currentCsrfToken) {
          params.append(name, currentCsrfToken);
        } else {
          params.append(name, value);
        }
      }

      const headers = {
        'Content-Type': 'application/x-www-form-urlencoded'
      };
      if (currentCsrfToken) {
        headers['X-CSRF-Token'] = currentCsrfToken;
      }

      const response = await fetch(item.action, {
        method: 'POST',
        headers: headers,
        body: params.toString(),
        redirect: 'follow'
      });

      if (response.ok) {
        await deletePendingItem(item.id);
        successCount++;
        showToast('Synced Successfully', `Synced '${item.title}' with the server.`, 'success');
      } else {
        console.warn(`Sync failed for item ${item.id} with status ${response.status}`);
        if (response.status === 422) {
          item.status = 'failed';
          item.errorMessage = 'Server validation failed';
          await updatePendingItem(item);
          failCount++;
          showToast('Sync Warning', `'${item.title}' could not be synced: validation error.`, 'danger');
        } else {
          failCount++;
        }
      }
    } catch (err) {
      console.error('Fetch error during sync:', err);
      failCount++;
    }
  }

  isSyncing = false;
  await updateSyncUI();

  if (successCount > 0 && failCount === 0) {
    if (banner) {
      banner.className = 'offline-banner visible online';
      if (bannerText) bannerText.textContent = `Sync complete! ${successCount} item(s) uploaded.`;
    }
    setTimeout(() => {
      getPendingItems().then(remaining => {
        const activePending = remaining.filter(i => i.status === 'pending');
        if (activePending.length === 0 && navigator.onLine) {
          document.body.classList.remove('has-offline-banner');
          if (banner) banner.className = 'offline-banner';
        }
      });
    }, 3000);

    // Refresh current view to show synced items
    if (window.Turbolinks) {
      Turbolinks.visit(location.toString(), { action: 'replace' });
    } else {
      location.reload();
    }
  } else if (failCount > 0) {
    if (banner) {
      banner.className = 'offline-banner visible';
      if (bannerText) bannerText.textContent = `Sync completed with errors. ${failCount} item(s) failed.`;
    }
  } else {
    updateOnlineStatus();
  }
}

// Update connection banner and trigger sync if online
function updateOnlineStatus() {
  const isOnline = navigator.onLine;
  const banner = document.getElementById('offline-banner');
  const bannerText = document.getElementById('offline-banner-text');
  
  if (!isOnline) {
    document.body.classList.add('has-offline-banner');
    if (banner) {
      banner.className = 'offline-banner visible';
      if (bannerText) bannerText.textContent = 'Offline Mode | Submissions will be saved locally';
    }
  } else {
    getPendingItems().then(items => {
      const pendingItems = items.filter(item => item.status === 'pending');
      if (pendingItems.length > 0) {
        syncPendingData();
      } else {
        document.body.classList.remove('has-offline-banner');
        if (banner) {
          banner.className = 'offline-banner';
        }
      }
    });
  }
}

// Update Sync Badges and Drawer List
async function updateSyncUI() {
  const items = await getPendingItems();
  const badgeItem = document.getElementById('nav-sync-item');
  const badge = document.getElementById('nav-sync-badge');
  const panel = document.getElementById('pending-sync-panel');
  const listContainer = document.getElementById('pending-sync-list');

  const pendingCount = items.filter(i => i.status === 'pending').length;
  const failedCount = items.filter(i => i.status === 'failed').length;
  const totalCount = items.length;

  if (totalCount > 0) {
    if (badgeItem) badgeItem.style.display = 'inline-flex';
    if (badge) {
      badge.textContent = `${totalCount} pending`;
      if (failedCount > 0) {
        badge.textContent = `${totalCount} pending (${failedCount} failed)`;
        badge.style.backgroundColor = '#dc3545';
      } else if (isSyncing) {
        badge.textContent = 'Syncing...';
        badge.style.backgroundColor = '#007bff';
      } else {
        badge.style.backgroundColor = '#ffc107';
        badge.style.color = '#212529';
      }
    }
  } else {
    if (badgeItem) badgeItem.style.display = 'none';
    if (panel) panel.classList.remove('visible');
  }

  if (listContainer) {
    if (totalCount === 0) {
      listContainer.innerHTML = '<div class="empty-state">No pending items to sync.</div>';
    } else {
      listContainer.innerHTML = '';
      items.forEach(item => {
        const itemEl = document.createElement('div');
        itemEl.className = `pending-item status-${item.status}`;
        
        let statusBadge = '';
        if (item.status === 'failed') {
          statusBadge = `<span style="color:#dc3545;font-weight:bold;float:right;font-size:0.7rem;">Failed</span>`;
        }

        itemEl.innerHTML = `
          <div>
            ${statusBadge}
            <span class="item-type">${item.type}</span>
          </div>
          <span class="item-title">${escapeHTML(item.title)}</span>
          <div style="display:flex;justify-content:space-between;align-items:center;margin-top:4px;">
            <span class="item-meta">${new Date(item.timestamp).toLocaleTimeString()}</span>
            <button class="delete-pending-btn" data-id="${item.id}" style="background:none;border:none;color:#dc3545;font-size:0.75rem;cursor:pointer;padding:0;">Remove</button>
          </div>
        `;
        listContainer.appendChild(itemEl);
      });
    }
  }
}

// Escape HTML utility
function escapeHTML(str) {
  return str.replace(/[&<>'"]/g, 
    tag => ({
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      "'": '&#39;',
      '"': '&quot;'
    }[tag] || tag)
  );
}

// Show popup toast message
function showToast(title, message, type = 'info') {
  const container = document.getElementById('offline-toast-container');
  if (!container) return;

  const toast = document.createElement('div');
  toast.className = `offline-toast toast-${type}`;
  
  let icon = 'ℹ️';
  if (type === 'success') icon = '✅';
  else if (type === 'warning') icon = '⚠️';
  else if (type === 'danger') icon = '❌';

  toast.innerHTML = `
    <div class="toast-title">
      <span>${icon}</span>
      <span>${title}</span>
    </div>
    <div class="toast-body">${message}</div>
  `;

  container.appendChild(toast);
  
  setTimeout(() => {
    toast.classList.add('visible');
  }, 50);

  setTimeout(() => {
    toast.classList.remove('visible');
    setTimeout(() => {
      toast.remove();
    }, 400);
  }, 4000);
}

// Intercept form submissions
document.addEventListener('submit', async function(event) {
  const form = event.target;
  const action = form.getAttribute('action') || '';
  const method = (form.getAttribute('method') || 'post').toLowerCase();

  let path = action;
  try {
    path = new URL(action, window.location.origin).pathname;
  } catch (e) {}

  const isResourceForm = path.match(/^\/(movies|albums|comics|tv_shows|wrestling_events)(\/)?$/) && method === 'post';

  if (!isResourceForm) return;

  if (!navigator.onLine) {
    event.preventDefault();
    event.stopPropagation();

    const submitBtn = form.querySelector('[type="submit"]');
    if (submitBtn) submitBtn.disabled = true;

    try {
      const formData = new FormData(form);
      const entries = [];
      for (const [name, value] of formData.entries()) {
        entries.push([name, value]);
      }

      let typeName = 'Item';
      if (path.includes('movies')) typeName = 'Movie';
      else if (path.includes('albums')) typeName = 'Album';
      else if (path.includes('comics')) typeName = 'Comic';
      else if (path.includes('tv_shows')) typeName = 'TV Show';
      else if (path.includes('wrestling_events')) typeName = 'Wrestling Event';

      const titleInput = form.querySelector('input[name$="[title]"]') || form.querySelector('input[name$="[name]"]');
      const titleVal = titleInput ? titleInput.value.trim() : '';
      const itemTitle = titleVal || `Unnamed ${typeName}`;

      const pendingItem = {
        type: typeName,
        title: itemTitle,
        action: path,
        entries: entries,
        timestamp: new Date().toISOString(),
        status: 'pending'
      };

      await addPendingItem(pendingItem);
      showToast('Saved Offline', `'${itemTitle}' has been saved locally and will sync when online.`, 'warning');
      form.reset();
      await updateSyncUI();

    } catch (err) {
      console.error('Error saving pending item:', err);
      showToast('Error', 'Failed to save item locally.', 'danger');
    } finally {
      if (submitBtn) submitBtn.disabled = false;
    }
  }
});

// Bind UI actions
document.addEventListener('click', async function(event) {
  if (event.target.classList.contains('delete-pending-btn')) {
    const id = parseInt(event.target.getAttribute('data-id'), 10);
    if (!isNaN(id)) {
      if (confirm('Are you sure you want to remove this pending item?')) {
        await deletePendingItem(id);
        await updateSyncUI();
        showToast('Item Removed', 'The pending item was deleted from local storage.', 'info');
      }
    }
  }

  if (event.target.id === 'nav-sync-badge') {
    const panel = document.getElementById('pending-sync-panel');
    if (panel) {
      panel.classList.toggle('visible');
    }
  }

  if (event.target.id === 'close-pending-panel') {
    const panel = document.getElementById('pending-sync-panel');
    if (panel) {
      panel.classList.remove('visible');
    }
  }
});

// Setup online/offline listeners
window.addEventListener('online', updateOnlineStatus);
window.addEventListener('offline', updateOnlineStatus);

// Initialize
function initializeOfflineSync() {
  updateOnlineStatus();
  updateSyncUI();
}

document.addEventListener('turbolinks:load', initializeOfflineSync);
if (!window.Turbolinks) {
  document.addEventListener('DOMContentLoaded', initializeOfflineSync);
}

// Keep drafts in memory only. Project/view keys prevent one project's inputs
// from appearing in another; files are deliberately left to the browser.
export function captureForms(root) {
  const forms = {};
  for (const form of root.querySelectorAll('form[id]')) {
    // Global search is owned by app state, not by per-page form drafts.
    if (form.id === 'global-search-form') continue;
    forms[form.id] = [...form.elements]
      .filter(field => (field.name || field.id) && !['file', 'submit', 'button'].includes(field.type))
      .map(field => ({name: field.name, id: field.id, value: field.value, checked: field.checked}));
  }
  return forms;
}

export function restoreForms(root, forms = {}) {
  for (const [id, fields] of Object.entries(forms)) {
    const form = root.querySelector(`#${CSS.escape(id)}`);
    if (!form) continue;
    for (const saved of fields) {
      const field = saved.id ? form.querySelector(`#${CSS.escape(saved.id)}`) : form.elements.namedItem(saved.name);
      if (!field || field.type === 'file') continue;
      field.value = saved.value;
      if (field.type === 'checkbox' || field.type === 'radio') field.checked = saved.checked;
    }
  }
}

export function focusIdentity(element) {
  if (!element) return null;
  if (element.id) return `#${CSS.escape(element.id)}`;
  if (element.dataset?.action) {
    const key = element.dataset.key;
    return `[data-action="${CSS.escape(element.dataset.action)}"]${key === undefined ? '' : `[data-key="${CSS.escape(key)}"]`}`;
  }
  return null;
}

// Completion handling belongs to every refresh, including manual refreshes.
export function unhandledCompletedJobs(jobs, handled) {
  return jobs.filter(job => ['succeeded', 'failed', 'cancelled'].includes(job.status) && !handled.has(job.id));
}

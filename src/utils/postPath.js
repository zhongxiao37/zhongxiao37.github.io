export function postSlugPath(id, date) {
  // id is like "2020-07-28-my-post.md", strip extension
  const filename = id.replace('.md', '');
  const slug = filename.replace(/^\d{4}-\d{2}-\d{2}-/, '');
  const d = date instanceof Date ? date : new Date(date);
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}/${mm}/${dd}/${slug}`;
}

export function postCategories(data) {
  const raw = data.categories ?? data.category ?? '';
  return raw.split(' ').filter(Boolean);
}

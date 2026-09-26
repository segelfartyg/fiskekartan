// A deliberately tiny router: the only client-side route besides the map
// itself is the public profile page at /{username}, so there's no need for
// a routing library. The backend serves index.html for any such path.

function usernameFromPath(pathname: string): string | null {
  const segment = decodeURIComponent(pathname.replace(/^\/+|\/+$/g, ''));
  return segment && !segment.includes('/') ? segment.toLowerCase() : null;
}

export const route: { profileUsername: string | null } = $state({
  profileUsername: usernameFromPath(window.location.pathname),
});

window.addEventListener('popstate', () => {
  route.profileUsername = usernameFromPath(window.location.pathname);
});

export function navigate(path: string): void {
  if (path === window.location.pathname) return;
  history.pushState(null, '', path);
  route.profileUsername = usernameFromPath(path);
}

/** Click handler for plain <a href> links, keeping them client-side. */
export function handleLinkClick(e: MouseEvent): void {
  if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
  const href = (e.currentTarget as HTMLAnchorElement).getAttribute('href');
  if (!href?.startsWith('/')) return;
  e.preventDefault();
  navigate(href);
}

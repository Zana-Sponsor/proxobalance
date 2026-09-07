/* Lightweight SVG icon system. Replaces legacy <i class="fa-*"> hooks,
   including HTML rendered later by the admin tables. No icon font is loaded. */
(() => {
  const P = {
    'bars':'<path d="M4 6h16M4 12h16M4 18h16"/>',
    'xmark':'<path d="M18 6 6 18M6 6l12 12"/>',
    'times':'<path d="M18 6 6 18M6 6l12 12"/>',
    'check':'<path d="m20 6-11 11-5-5"/>',
    'check-double':'<path d="m18 6-11 11-5-5"/><path d="m22 10-7.5 7.5"/>',
    'plus':'<path d="M12 5v14M5 12h14"/>',
    'pen':'<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L8 18l-4 1 1-4Z"/>',
    'trash':'<path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6M10 11v5M14 11v5"/>',
    'floppy-disk':'<path d="M5 3h12l2 2v16H5Z"/><path d="M8 3v6h8V3M8 21v-7h8v7"/>',
    'arrows-rotate':'<path d="M20 11a8 8 0 0 0-14.8-4L3 10"/><path d="M3 4v6h6M4 13a8 8 0 0 0 14.8 4l2.2-3"/><path d="M21 20v-6h-6"/>',
    'arrow-left':'<path d="M19 12H5m6-6-6 6 6 6"/>',
    'arrow-right':'<path d="M5 12h14m-6-6 6 6-6 6"/>',
    'arrow-up':'<path d="m6 11 6-6 6 6M12 5v14"/>',
    'arrow-down':'<path d="m6 13 6 6 6-6M12 19V5"/>',
    'right-left':'<path d="m16 3 4 4-4 4M20 7H4m4 14-4-4 4-4M4 17h16"/>',
    'clock':'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    'hourglass-end':'<path d="M6 2h12M6 22h12M7 2c0 5 2 6 5 8 3-2 5-3 5-8M7 22c0-5 2-6 5-8 3 2 5 3 5 8"/>',
    'bell':'<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',
    'bell-slash':'<path d="M13.7 4.1A6 6 0 0 1 18 10c0 3 1 5 3 7H8M10 21h4M3 3l18 18M6.3 6.3A6 6 0 0 0 6 10c0 3-1 5-3 7h11"/>',
    'bullhorn':'<path d="m3 11 16-6v14L3 13Z"/><path d="M11.6 16 13 21H7l-1.5-6"/>',
    'paper-plane':'<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
    'inbox':'<path d="M4 4h16l2 12v4H2v-4Z"/><path d="M2 16h6l2 2h4l2-2h6"/>',
    'users':'<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.9M16 3.1a4 4 0 0 1 0 7.8"/>',
    'user':'<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    'user-plus':'<path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M8.5 11a4 4 0 1 0 0-8"/><path d="M19 8v6M16 11h6"/>',
    'user-slash':'<path d="M16 21v-2a4 4 0 0 0-4-4H7M8.5 11a4 4 0 0 0 3.8-5.3M3 3l18 18"/>',
    'user-check':'<path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2M8.5 11a4 4 0 1 0 0-8"/><path d="m17 11 2 2 4-4"/>',
    'user-secret':'<path d="M4 8h16M9 4h6l2 4H7Z"/><circle cx="8" cy="13" r="2"/><circle cx="16" cy="13" r="2"/><path d="M10 13h4M6 21a6 6 0 0 1 12 0"/>',
    'user-shield':'<circle cx="8" cy="7" r="4"/><path d="M2 21a6 6 0 0 1 10-4.5"/><path d="m17 13 4 2v3c0 2.5-1.7 4.3-4 5-2.3-.7-4-2.5-4-5v-3Z"/>',
    'right-from-bracket':'<path d="M10 17l5-5-5-5M15 12H3M14 3h6v18h-6"/>',
    'lock':'<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
    'lock-open':'<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 7.5-2"/>',
    'key':'<circle cx="7" cy="17" r="4"/><path d="m10 14 9-9M15 9l3 3M18 6l2 2"/>',
    'fingerprint':'<path d="M12 11a3 3 0 0 1 3 3c0 3-.6 5.2-1.6 7M9 21c1-2 1.5-4.3 1.5-7a1.5 1.5 0 0 1 3 0c0 2.1-.3 4-.9 5.8M5.5 19c.8-1.5 1-3.2 1-5a5.5 5.5 0 0 1 11 0c0 1.2-.1 2.3-.3 3.4M4 14a8 8 0 0 1 16 0M6 6a9 9 0 0 1 12 0"/>',
    'shield':'<path d="m12 3 8 4v5c0 5-3.4 8.2-8 10-4.6-1.8-8-5-8-10V7Z"/>',
    'shield-halved':'<path d="m12 3 8 4v5c0 5-3.4 8.2-8 10-4.6-1.8-8-5-8-10V7Z"/><path d="M12 3v19"/>',
    'ban':'<circle cx="12" cy="12" r="9"/><path d="m5.6 5.6 12.8 12.8"/>',
    'triangle-exclamation':'<path d="M10.3 3.5 2.5 18a2 2 0 0 0 1.8 3h15.4a2 2 0 0 0 1.8-3L13.7 3.5a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/>',
    'circle-info':'<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7h.01"/>',
    'circle-notch':'<path d="M21 12a9 9 0 1 1-9-9"/>',
    'circle':'<circle cx="12" cy="12" r="8"/>',
    'bolt':'<path d="m13 2-9 12h8l-1 8 9-12h-8Z"/>',
    'gauge':'<path d="M4 17a8 8 0 1 1 16 0M12 13l4-4"/><path d="M7 20h10"/>',
    'gauge-high':'<path d="M4 17a8 8 0 1 1 16 0M12 13l5-5"/><path d="M7 20h10"/>',
    'chart-line':'<path d="M3 3v18h18M7 16l4-5 3 3 5-7"/>',
    'chart-pie':'<path d="M12 3v9h9A9 9 0 1 1 12 3Z"/><path d="M16 4a8 8 0 0 1 5 5h-5Z"/>',
    'percent':'<path d="m19 5-14 14"/><circle cx="7" cy="7" r="2"/><circle cx="17" cy="17" r="2"/>',
    'coins':'<circle cx="8" cy="8" r="5"/><path d="M3 8v4c0 2.8 2.2 5 5 5 1.4 0 2.7-.6 3.6-1.5M13 7c.9-.6 1.9-1 3-1 2.8 0 5 2.2 5 5v5c0 2.8-2.2 5-5 5-2 0-3.8-1.2-4.6-3"/>',
    'money-bill-transfer':'<rect x="3" y="6" width="18" height="12" rx="2"/><path d="M8 12h8M13 9l3 3-3 3"/>',
    'wallet':'<path d="M4 5h14a2 2 0 0 1 2 2v12H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z"/><path d="M16 11h6v5h-6a2.5 2.5 0 0 1 0-5Z"/>',
    'receipt':'<path d="M5 3h14v19l-3-2-4 2-4-2-3 2Z"/><path d="M8 8h8M8 12h8M8 16h5"/>',
    'image':'<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="2"/><path d="m21 15-5-5L5 20"/>',
    'upload':'<path d="M12 16V4m-5 5 5-5 5 5M5 20h14"/>',
    'eye':'<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
    'eye-slash':'<path d="M3 3l18 18M10.6 10.6a2 2 0 0 0 2.8 2.8M9.9 5.2A11 11 0 0 1 12 5c6 0 10 7 10 7a16 16 0 0 1-2.1 3M6.2 6.2C3.6 8 2 12 2 12s4 7 10 7a10 10 0 0 0 4.2-.9"/>',
    'desktop':'<rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8M12 17v4"/>',
    'network-wired':'<rect x="9" y="2" width="6" height="5" rx="1"/><rect x="2" y="17" width="6" height="5" rx="1"/><rect x="16" y="17" width="6" height="5" rx="1"/><path d="M12 7v5M5 17v-5h14v5"/>',
    'list':'<path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>',
    'clone':'<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/>',
    'shuffle':'<path d="M3 6h3c4 0 5 12 9 12h6M18 15l3 3-3 3M3 18h3c1.5 0 2.6-1.5 3.5-3M18 3l3 3-3 3M14.5 6H21"/>',
    'robot':'<rect x="4" y="7" width="16" height="13" rx="2"/><path d="M12 3v4M8 12h.01M16 12h.01M8 16h8"/>',
    'screwdriver-wrench':'<path d="m14.7 6.3 3-3a4 4 0 0 1-5 5l-8 8a2 2 0 1 0 3 3l8-8a4 4 0 0 1 5-5l-3 3Z"/>',
    'dice':'<rect x="4" y="4" width="16" height="16" rx="3"/><circle cx="9" cy="9" r="1"/><circle cx="15" cy="15" r="1"/>'
  };

  function iconName(node) {
    const cls = [...node.classList].find(c => c.startsWith('fa-') && c !== 'fa-spin');
    return cls ? cls.slice(3) : 'circle';
  }

  function replaceOne(node) {
    if (!(node instanceof Element) || node.dataset.svgReady === '1') return;
    const name = iconName(node);
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('aria-hidden', 'true');
    svg.setAttribute('focusable', 'false');
    svg.classList.add('svg-icon', `svg-${name}`);
    if (node.classList.contains('fa-spin')) svg.classList.add('fa-spin');
    for (const c of node.classList) {
      if (!c.startsWith('fa') && c !== 'fas') svg.classList.add(c);
    }
    if (node.getAttribute('style')) svg.setAttribute('style', node.getAttribute('style'));
    if (node.getAttribute('title')) svg.setAttribute('title', node.getAttribute('title'));
    svg.innerHTML = P[name] || P.circle;
    node.replaceWith(svg);
  }

  function scan(root = document) {
    if (root.matches?.('i.fas, i.fa-solid')) replaceOne(root);
    root.querySelectorAll?.('i.fas, i.fa-solid').forEach(replaceOne);
  }

  let scheduled = false;
  const observer = new MutationObserver(records => {
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(() => {
      for (const record of records) for (const node of record.addedNodes) if (node.nodeType === 1) scan(node);
      scheduled = false;
    });
  });

  window.PXIcons = { scan };
  scan();
  observer.observe(document.documentElement, { childList: true, subtree: true });
})();

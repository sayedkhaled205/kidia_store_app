(function (scope) {
  'use strict';
  function choices(payload, ar) {
    const tr = (en, arabic) => ar ? arabic : en;
    const rows = [], seen = new Set();
    function add(label, destination, id = '', group = 'Pages') {
      if (!label || !['home','categories','category','collection','offers','wishlist','cart','account','checkout','search','product','order'].includes(destination)) return;
      if (['category','product','order'].includes(destination) && !/^[1-9]\d*$/.test(String(id))) return;
      const key = JSON.stringify([label, destination, String(id)]);
      if (seen.has(key)) return;
      seen.add(key); rows.push({label: String(label), destination, id: String(id), group});
    }
    [['Home','الرئيسية','home'],['Categories','الأقسام','categories'],['Offers','الخصومات','offers'],['Wishlist','المفضلة','wishlist'],['Cart','السلة','cart'],['Account','حسابي','account']].forEach(([en, arabic, type]) => add(tr(en,arabic),type));
    [['latest','New arrivals','وصل حديثًا'],['featured','Featured products','منتجات مميزة'],['on_sale','Sale products','منتجات الخصومات'],['best_selling','Best selling','الأكثر مبيعًا'],['top_rated','Top rated','الأعلى تقييمًا']].forEach(([id,en,arabic]) => add(tr(en,arabic),'collection',id,'Collections'));
    const cats = Array.isArray(payload.store?.category_items) ? payload.store.category_items : [];
    const map = new Map(cats.map(c => [String(c.id),c]));
    cats.forEach(c => {
      const names = [c.name], visited = new Set([String(c.id)]); let parent = map.get(String(c.parent));
      while (parent && !visited.has(String(parent.id))) { visited.add(String(parent.id)); names.unshift(parent.name); parent=map.get(String(parent.parent)); }
      add(names.filter(Boolean).join(' / '),'category',c.id,'Categories');
    });
    let blocks = payload.push_home_blocks || [];
    if (!Array.isArray(blocks)) blocks = [];
    for (const block of blocks) {
      if (block.enabled === false) continue;
      const s = block.settings || {};
      add(s.title || block.name, s.action_type, s.action_value, 'Shortcuts');
      for (const item of Array.isArray(s.items) ? s.items : []) add(item.label || item.title, item.action_type, item.action_value, 'Shortcuts');
    }
    return rows;
  }
  function mount(root, payload) {
    const type = root.querySelector('[name="push_destination"]');
    const id = root.querySelector('[name="push_destination_id"]');
    if (!type || !id) return;
    const ar = document.documentElement.lang.startsWith('ar');
    let select = root.querySelector('[data-push-ready-destination]');
    if (!select) {
      select = document.createElement('select'); select.dataset.pushReadyDestination='';
      select.setAttribute('aria-label', ar ? 'الصفحة المقصودة' : 'Destination page');
      type.hidden = true; type.after(select);
      if (!Array.from(type.options).some(o => o.value === 'categories')) type.add(new Option('Categories','categories'));
      select.addEventListener('change', () => {
        const option = select.selectedOptions[0];
        type.value = option.dataset.destination || option.value;
        id.value = option.dataset.id || '';
        type.dispatchEvent(new Event('change',{bubbles:true}));
        id.dispatchEvent(new Event('input',{bubbles:true}));
        type.hidden = true;
        id.closest('label').hidden = option.dataset.ready === '1';
      });
    }
    const previous = select.value; select.replaceChildren();
    const groups = new Map();
    for (const row of choices(payload, ar)) {
      let group = groups.get(row.group);
      if (!group) { group=document.createElement('optgroup'); group.label=({Pages:'الصفحات',Collections:'المجموعات',Categories:'الأقسام',Shortcuts:'الاختصارات'}[row.group] && ar) ? {Pages:'الصفحات',Collections:'المجموعات',Categories:'الأقسام',Shortcuts:'الاختصارات'}[row.group] : row.group; groups.set(row.group,group); select.append(group); }
      const option = new Option(row.label, JSON.stringify([row.destination,row.id,row.label]));
      Object.assign(option.dataset,{destination:row.destination,id:row.id,ready:'1'}); group.append(option);
    }
    const advanced = document.createElement('optgroup'); advanced.label=ar?'اختيار آخر':'Custom destination';
    for (const original of type.options) { const option=original.cloneNode(true); option.dataset.destination=original.value; advanced.append(option); }
    select.append(advanced);
    const matching=Array.from(select.options).find(o=>o.value===previous) || Array.from(select.options).find(o=>o.dataset.destination===type.value && (o.dataset.id||'')===id.value);
    if (matching) select.value=matching.value;
  }
  const api={choices,mount};
  if (typeof module !== 'undefined' && module.exports) module.exports=api;
  else scope.MobiShopPushDestinations=api;
})(typeof window === 'undefined' ? globalThis : window);

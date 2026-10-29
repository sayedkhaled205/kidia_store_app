(function () {
  'use strict';
  const ar = () => document.documentElement.lang.startsWith('ar');
  const tr = (en, arabic) => ar() ? arabic : en;
  const el = (tag, text, className) => { const node = document.createElement(tag); if (text !== undefined) node.textContent = text; if (className) node.className = className; return node; };
  const integer = value => Number.isSafeInteger(value) && value >= 0 ? value : 0;
  const metrics = () => [
    ['targeted',tr('Targeted devices','الأجهزة المستهدفة')], ['sent',tr('Accepted for sending','اتقبل للإرسال')],
    ['failed',tr('Send failures','فشل الإرسال')], ['received',tr('Confirmed received','وصول مؤكد')],
    ['opened',tr('Unique opens','فتح بدون تكرار')], ['orders',tr('Verified orders','طلبات مؤكدة')],
    ['paid_orders',tr('Paid orders','طلبات مدفوعة')]
  ];
  const decimal = value => /^\d{1,14}(?:\.\d{1,6})?$/.test(String(value)) ? BigInt(String(value).split('.')[0]) * 1000000n + BigInt((String(value).split('.')[1] || '').padEnd(6,'0')) : 0n;
  const money = value => (value / 1000000n).toString().replace(/\B(?=(\d{3})+(?!\d))/g,',') + '.' + (value % 1000000n).toString().padStart(6,'0').replace(/0+$/,'').padEnd(2,'0');
  function revenue(rows) {
    const totals = {};
    rows.forEach(row => Object.entries(row.revenue || {}).forEach(([currency,value]) => {
      if (/^[A-Z]{3}$/.test(currency)) totals[currency] = (totals[currency] || 0n) + decimal(value);
    }));
    return Object.entries(totals).map(([currency,value]) => currency + ' ' + money(value)).join(' · ') || '—';
  }
  function notice(node, message, failed, busy) {
    node.className = 'wm-push-notice ' + (failed ? 'is-error' : busy ? 'is-busy' : 'is-success');
    node.setAttribute('role', failed ? 'alert' : 'status'); node.setAttribute('aria-live', failed ? 'assertive' : 'polite');
    node.setAttribute('aria-atomic','true'); node.setAttribute('aria-busy',String(Boolean(busy)));
    const icon = el('span', busy ? '' : failed ? '!' : '✓', 'wm-push-notice-icon'); icon.setAttribute('aria-hidden','true');
    node.replaceChildren(icon,el('span',message));
  }
  function mount(root, data) {
    root.querySelector('.wm-push-analytics')?.remove();
    const section = el('section',undefined,'wm-push-analytics'); section.setAttribute('aria-label',tr('Push analytics','تحليلات الإشعارات'));
    section.append(el('h2',tr('Push analytics','تحليلات الإشعارات')));
    const anchor = root.querySelector('.mobishop-push-history'); if (anchor) anchor.before(section); else root.append(section);
    const legacyStats=root.querySelector('.mobishop-push-stats');
    if (legacyStats) { legacyStats.hidden=true; legacyStats.style.setProperty('display','none','important'); }
    if (!data || data.status !== 'ready' || data.version !== 2) {
      section.append(el('p',tr('Analytics is unavailable. Reload to try again. Unavailable data is not counted as zero.','التحليلات غير متاحة حاليًا. أعد تحميل الصفحة للمحاولة. البيانات غير المتاحة لا تُحسب صفرًا.'))); return;
    }
    const controls = el('div',undefined,'wm-push-controls');
    const label = el('label',tr('Campaign period','فترة الحملات'));
    const range = el('select'); range.setAttribute('aria-label',tr('Campaign period','فترة الحملات'));
    [[30,tr('Last 30 days','آخر ٣٠ يوم')],[7,tr('Last 7 days','آخر ٧ أيام')],[90,tr('Last 90 days','آخر ٩٠ يوم')],[0,tr('All tracked campaigns','كل الحملات المتتبعة')]].forEach(([value,text]) => { const option=el('option',text);option.value=String(value);range.append(option); });
    label.append(range); controls.append(label);
    const exportButton = el('button',tr('Export CSV','تنزيل CSV'),'wm-push-export'); exportButton.type='button'; controls.append(exportButton); section.append(controls);
    section.append(el('p',tr('Sending is provider acceptance, not delivery. Confirmed receipt includes foreground receipt or an open; background delivery can be unreported. Each device is counted once per campaign.','الإرسال يعني قبول مزود الخدمة، مش تأكيد الوصول. الوصول المؤكد يشمل الاستلام والتطبيق مفتوح أو فتح الإشعار؛ الوصول في الخلفية قد لا يتم تسجيله. الجهاز يُحسب مرة واحدة لكل حملة.'),'wm-push-note'));
    section.append(el('p',data.conversion_supported
      ? tr('Orders use the last notification opened within 7 days before checkout. Tracking requires the updated app. Cancelled, failed and fully refunded orders are excluded. Order value includes shipping/tax and subtracts refunds; paid orders are shown separately.','الطلب يُنسب لآخر إشعار اتفتح خلال ٧ أيام قبل إتمام الطلب. التتبع يحتاج نسخة التطبيق المحدّثة. الطلبات الملغاة والفاشلة والمستردة بالكامل مستبعدة. قيمة الطلب تشمل الشحن والضريبة بعد طرح الاستردادات، والطلبات المدفوعة تظهر منفصلة.')
      : tr('Purchase attribution is not available for this store connection yet. Order metrics are shown as unavailable.','ربط المشتريات بالإشعارات غير متاح لاتصال المتجر ده حاليًا. أرقام الطلبات بتظهر كبيانات غير متاحة.'),'wm-push-note'));
    const body = el('div'); section.append(body);
    let filtered=[];
    const render = () => {
      const days=Number(range.value); const cutoff=days ? Date.now()/1000-days*86400 : 0;
      filtered=(Array.isArray(data.campaigns)?data.campaigns:[]).filter(row=>row && integer(row.created_at)>=cutoff);
      body.replaceChildren();
      const cards=el('div',undefined,'wm-push-metrics');
      metrics().forEach(([key,title]) => {
        const card=el('div'); card.append(el('span',title));
        card.append(el('strong',!data.conversion_supported&&['orders','paid_orders'].includes(key)?'—':String(filtered.reduce((sum,row)=>sum+integer(row[key]),0))));cards.append(card);
      });
      const value=el('div');value.append(el('span',tr('Attributed order value','قيمة الطلبات المنسوبة')),el('strong',data.conversion_supported?revenue(filtered):'—'));cards.append(value);body.append(cards);
      if (!filtered.length) { body.append(el('p',tr('No tracked campaigns in this period. Earlier history is preserved below; old counters are not presented as verified analytics.','لا توجد حملات متتبعة في الفترة دي. السجل الأقدم محفوظ تحت، والعدادات القديمة لا تُعرض كتحليلات مؤكدة.'),'wm-push-empty'));exportButton.disabled=true;return; }
      exportButton.disabled=false;
      filtered.forEach(row=>{
        const item=el('details',undefined,'wm-push-campaign');
        const summary=el('summary'); summary.append(el('strong',row.title || tr('Notification','إشعار')),el('span',new Date(row.created_at*1000).toLocaleString()),el('span',row.status || ''));
        item.append(summary,el('p',row.message || ''));
        const list=el('dl');
        metrics().forEach(([key,title])=>list.append(el('dt',title),el('dd',!data.conversion_supported&&['orders','paid_orders'].includes(key)?'—':String(integer(row[key])))));
        list.append(el('dt',tr('Open rate / targeted devices','نسبة الفتح من الأجهزة المستهدفة')),el('dd',integer(row.targeted)?(integer(row.opened)*100/row.targeted).toFixed(1)+'%':'—'));
        list.append(el('dt',tr('Buyers in this campaign','المشترون من الحملة')),el('dd',data.conversion_supported?String(integer(row.buyers)):'—'));
        list.append(el('dt',tr('Attributed order value','قيمة الطلبات المنسوبة')),el('dd',data.conversion_supported?revenue([row]):'—'));
        list.append(el('dt',tr('Audience','الجمهور')),el('dd',row.audience || ''));
        Object.entries(row.platforms || {}).forEach(([platform,counts])=>list.append(el('dt',platform),el('dd',`${integer(counts.received)} ${tr('received','وصل')} · ${integer(counts.opened)} ${tr('opened','فتح')}`)));
        item.append(list);body.append(item);
      });
    };
    range.addEventListener('change',render);
    exportButton.addEventListener('click',()=>{
      const keys=['id','title','created_at','audience','status','targeted','sent','failed','received','opened','orders','buyers','paid_orders'];
      const quote=value=>'"'+String(value??'').replace(/^[=+@-]/,"'$&").replace(/"/g,'""')+'"';
      const rows=[keys.concat('order_value'),...filtered.map(row=>keys.map(key=>!data.conversion_supported&&['orders','buyers','paid_orders'].includes(key)?'unavailable':row[key]).concat(data.conversion_supported?revenue([row]):'unavailable'))];
      const url=URL.createObjectURL(new Blob(['\uFEFF'+rows.map(row=>row.map(quote).join(',')).join('\r\n')],{type:'text/csv;charset=utf-8'}));
      const link=el('a');link.href=url;link.download='push-analytics.csv';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
    });
    render();
  }
  window.MobiShopPushReport={mount,notice};
})();

'use strict';
/* FGS HIS – Project Management (live). Only the PUBLIC publishable key is used here.
   All permissions are enforced by the database (RLS + triggers), not by this file. */
const CFG = window.FGS_CONFIG;
if (!CFG || !CFG.url || !CFG.key) throw new Error('config.js is missing: copy config.example.js to config.js');
const INITIAL_HASH = location.hash;
const sb = supabase.createClient(CFG.url, CFG.key, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } });

const $ = s => document.querySelector(s);
const H = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const N = n => (Math.round(+n * 100) / 100).toLocaleString('en-US');
const R = n => N(n || 0) + ' ر.س';
const RL = { owner: 'المالك', general_manager: 'المدير العام', project_manager: 'مدير المشروع', finance: 'المالية', team_member: 'عضو فريق' };
const MG = ['owner', 'general_manager', 'project_manager', 'finance'];
const ERR = {
  SELF_APPROVAL_FORBIDDEN: 'لا يمكنك اعتماد عملية سجّلتها بنفسك',
  ONLY_OWNER_CAN_APPROVE: 'الاعتماد للمالك فقط',
  PAYMENT_EXCEEDS_REMAINING: 'المبلغ يتجاوز المتبقي من الدفعة',
  RESERVE_EXCEEDED: 'المبلغ يتجاوز المتبقي من الاحتياطي',
  CLIENT1_PAYMENT_EXCEEDS_BUDGET: 'المبلغ يتجاوز تكلفة العميل الأول',
  EXCEEDS_BUDGET_OVERRIDE_REASON_REQUIRED: 'يتجاوز الميزانية المعتمدة ويلزم سبب موافقة',
  PHASE_HAS_INCOMPLETE_TASKS: 'لا تُعتمد المرحلة قبل اكتمال مهامها 100%',
  ASSIGNEE_MUST_BE_AN_ACTIVE_USER: 'المسؤول يجب أن يكون مستخدمًا فعّالًا',
  DECIDED_RECORD_IS_IMMUTABLE: 'السجل المعتمد أو المرفوض لا يُعدَّل',
  ONLY_CREATOR_CAN_EDIT: 'لا يعدّل السجل إلا من أنشأه',
  LAST_OWNER_CANNOT_BE_REMOVED: 'لا يمكن إزالة آخر مالك',
  TEAM_MEMBER_CAN_ONLY_UPDATE_PROGRESS_AND_STATUS: 'يُسمح لك بتحديث الإنجاز والحالة فقط',
};
const msg = e => { const m = (e && e.message) || String(e); const k = Object.keys(ERR).find(k => m.includes(k)); return k ? ERR[k] : (m.includes('row-level security') ? 'لا تملك صلاحية لهذا الإجراء' : m); };
const toast = m => { const t = $('#toast'); t.textContent = m; t.style.display = 'block'; clearTimeout(t._h); t._h = setTimeout(() => t.style.display = 'none', 4500); };
const today = () => new Date(Date.now() - new Date().getTimezoneOffset() * 6e4).toISOString().slice(0, 10);
const when = s => s ? new Date(s).toLocaleString('en-GB', { dateStyle: 'short', timeStyle: 'short' }) : '—';

const addDays = (s, n) => { const d = new Date(s + 'T00:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); };
const projStart = () => ((D.proj || [])[0] || {}).start_date || null;
const pStart = t => t.planned_start || ((projStart() && t.week_from) ? addDays(projStart(), (t.week_from - 1) * 7) : null);
const pEnd = t => t.planned_end || ((projStart() && t.week_to) ? addDays(projStart(), t.week_to * 7 - 1) : null);
const isLate = t => { const e = pEnd(t); return !!e && e < today() && t.progress < 100; };
const dl = (name, text, type) => { const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([text], { type })); a.download = name; document.body.appendChild(a); a.click(); setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 500); };
const fb = (et, id) => `<button class="b s" data-a="files" data-et="${et}" data-id="${id}">📎 ${(D.att || []).filter(a => a.entity_type === et && a.entity_id === id).length}</button>`;
const techCost = ph => isMg() ? `<span class="mu">تكلفة تقنية (اختيارية): ${N((((D.pcost || []).find(c => c.phase_id === ph.id)) || {}).cost || 0)}</span>${me.role === 'owner' ? ` <button class="b s" data-a="phCost" data-id="${ph.id}">تعديل</button>` : ''}` : '';
const recon = () => `<div class="card"><h3>مطابقة Excel مع مستند الدفعات</h3>${tbl(['البند (Excel)', 'Excel', 'مستند الدفعات', 'الفرق'], (D.bref || []).map(x => [H(x.description), N(x.excel_amount), x.payment_doc_amount == null ? 'خارج 95,750 (العميل الأول)' : N(x.payment_doc_amount), x.payment_doc_amount == null ? '—' : (+x.payment_doc_amount - +x.excel_amount ? `<span class="t wr">${N(x.payment_doc_amount - x.excel_amount)}</span>` : '0')]))}<p class="mu">المرجع المالي المعتمد: مستند الدفعات (95,750)، وتكلفة العميل الأول (35,000) منفصلة.</p></div>`;
let repSel = '1';
function repData(k) {
  const d = D.dash || {}, num = x => +x || 0, today_ = today();
  if (k === '1') return { t: 'التقرير المالي الشامل (بدون ضريبة القيمة المضافة)', h: ['البند', 'القيمة (ر.س)'], r: [['ميزانية تطوير المنتج', num(d.budget)], ['تكلفة العميل الأول (مستقلة)', num(d.client1_budget)], ['الاحتياطي المالي', num(d.reserve)], ['استخدام الاحتياطي المعتمد', num(d.reserve_used)], ['إجمالي بنود الدفعات', num(d.planned)], ['الدفعات المعتمدة', num(d.paid)], ['دفعات بانتظار الاعتماد', num(d.payments_pending)], ['المصروف الفعلي المعتمد (المنتج)', num(d.expenses_actual)], ['مصروفات بانتظار الاعتماد', num(d.expenses_pending)], ['المصروف المعتمد – العميل الأول', num(d.client1_expenses)], ['المدفوع – العميل الأول', num(d.client1_paid)], ['الميزانية المتبقية', num(d.budget) + num(d.reserve_used) - num(d.expenses_actual)]] };
  if (k === '2') return { t: 'تقرير الدفعات', h: ['الدفعة', 'المرحلة', 'القيمة', 'المعتمد المدفوع', 'بانتظار الاعتماد', 'المتبقي'], r: (d.payments || []).map(p => [p.code, p.name, num(p.amount), num(p.paid), num(p.pending), num(p.remaining)]) };
  if (k === '3') return { t: 'تقرير المصروفات', h: ['التاريخ', 'المصروف', 'التصنيف', 'النطاق', 'المورد', 'المبلغ', 'الحالة', 'سند'], r: (D.exps || []).map(e => [e.expense_date, e.name, e.category, e.scope === 'product' ? 'المنتج' : 'العميل الأول', e.payee, num(e.amount), PMAP[e.status][0], e.ref]) };
  if (k === '4') return { t: 'تقرير مراحل المشروع', h: ['المرحلة', 'الأسابيع', 'الإنجاز %', 'المهام المكتملة', 'الاعتماد', 'تكلفة تقنية (اختيارية)'], r: D.phases.map(ph => { const ts = D.tasks.filter(t => t.phase_id === ph.id), ap = (D.appr || []).find(a => a.phase_id === ph.id); return [ph.name, ph.week_from + '–' + ph.week_to, ts.length ? Math.round(ts.reduce((a, t) => a + t.progress, 0) / ts.length) : 0, ts.filter(t => t.progress >= 100).length + ' / ' + ts.length, ap ? 'معتمدة ' + ap.approved_on : 'بانتظار', num((((D.pcost || []).find(c => c.phase_id === ph.id)) || {}).cost)]; }) };
  if (k === '5') { const ap = (D.exps || []).filter(e => e.status === 'approved' && e.scope === 'product'); const rows = (D.pays || []).map(p => { const amt = (p.payment_items || []).reduce((a, i) => a + num(i.amount), 0), act = ap.filter(e => e.stage_payment_id === p.id).reduce((a, e) => a + num(e.amount), 0); return [p.code + ' – ' + p.name, amt, act, amt - act]; }); const un = ap.filter(e => !e.stage_payment_id).reduce((a, e) => a + num(e.amount), 0); return { t: 'الميزانية مقابل المصروف الفعلي حسب المرحلة المالية', h: ['المرحلة المالية', 'المعتمد', 'الفعلي', 'الفرق'], r: rows.concat([['مصروف بلا مرحلة مالية', 0, un, -un], ['الإجمالي', num(d.budget), num(d.expenses_actual), num(d.budget) + num(d.reserve_used) - num(d.expenses_actual)]]) }; }
  const late = D.tasks.filter(isLate).map(t => ['مهمة متأخرة', t.code + ' ' + t.title, 'نهاية مخططة ' + pEnd(t) + ' — إنجاز ' + t.progress + '%']);
  const overdue = (D.pays || []).filter(p => p.due_date && p.due_date < today_).map(p => { const s = ((d.payments || []).find(x => x.code === p.code)) || {}; return num(s.remaining) > 0 ? ['دفعة متأخرة', p.code + ' ' + p.name, 'المتبقي ' + N(s.remaining) + ' — الاستحقاق ' + p.due_date] : null; }).filter(Boolean);
  const pend = [['عمليات بانتظار الاعتماد', 'دفعات/مصروفات/احتياطي/العميل الأول', ((D.recs || []).concat(D.exps || [], D.res || [], D.c1p || [])).filter(x => x.status === 'pending').length + ' عملية']];
  const iss = (D.iss || []).filter(i => i.status !== 'resolved').map(i => [(i.kind === 'risk' ? 'خطر' : 'تعارض') + ' مفتوح', i.code + ' ' + i.title, i.resolution_note || '']);
  return { t: 'تقرير التأخير والمخاطر', h: ['النوع', 'البند', 'التفاصيل'], r: late.concat(overdue, pend, iss) };
}

let me = null, D = {}, tab = 'dash', chan = null, tm = null;
const isMg = () => MG.includes(me.role);
const can = {
  pay: () => ['owner', 'finance'].includes(me.role),
  exp: () => ['owner', 'finance', 'project_manager'].includes(me.role),
  approve: () => me.role === 'owner',
  phaseAppr: () => ['owner', 'general_manager'].includes(me.role),
  plan: () => ['owner', 'project_manager'].includes(me.role),
  issue: () => ['owner', 'project_manager', 'general_manager'].includes(me.role),
};
const TABNAME = { dash: 'لوحة المتابعة', pay: 'الدفعات', exp: 'المصروفات والاعتمادات', ph: 'المراحل والمهام', iss: 'المخاطر والتعارضات', users: 'المستخدمون', audit: 'سجل العمليات', rep: 'التقارير', set: 'الإعدادات' };
const tabsFor = () => me.role === 'team_member' ? ['ph'] : ['dash', 'pay', 'exp', 'ph', 'iss', 'rep', 'set'].concat(me.role === 'owner' ? ['users'] : [], ['owner', 'general_manager'].includes(me.role) ? ['audit'] : []);
const tabName = t => (me.role === 'team_member' && t === 'ph') ? 'مهامي' : TABNAME[t];
const PNm = id => { const p = (D.profiles || []).find(x => x.id === id); return p ? (p.full_name || p.email) : '—'; };
const PMAP = { pending: ['بانتظار الاعتماد', 'wr'], approved: ['معتمد', 'ok'], rejected: ['مرفوض', 'er'] };
const stTag = s => `<span class="t ${PMAP[s][1]}">${PMAP[s][0]}</span>`;
const TSTAT = { not_started: 'لم تبدأ', in_progress: 'قيد التنفيذ', done: 'مكتملة', blocked: 'معوّقة' };
const PRIO = { low: 'منخفضة', medium: 'متوسطة', high: 'عالية', urgent: 'عاجلة' };

/* ---------------- auth screens ---------------- */
function showLogin(m) {
  $('#shell').hidden = true; const b = $('#login'); b.hidden = false;
  b.innerHTML = `<h1>FGS HIS</h1><p class="mu">Project Management — تسجيل الدخول</p>${m ? `<p class="t er">${H(m)}</p>` : ''}
  <form id="lf"><label>البريد الإلكتروني</label><input id="em" type="email" autocomplete="username" required>
  <label>كلمة المرور</label><input id="pw" type="password" autocomplete="current-password" required>
  <button class="b" type="submit">دخول</button></form><p><a href="#" id="fg">نسيت كلمة المرور؟</a></p>`;
  $('#lf').onsubmit = async e => {
    e.preventDefault();
    const { error } = await sb.auth.signInWithPassword({ email: $('#em').value.trim(), password: $('#pw').value });
    if (error) return showLogin('بيانات الدخول غير صحيحة أو الحساب غير مفعّل');
    await start();
  };
  $('#fg').onclick = async e => {
    e.preventDefault(); const em = $('#em').value.trim(); if (!em) return toast('اكتب بريدك أولًا');
    await sb.auth.resetPasswordForEmail(em, { redirectTo: location.origin + location.pathname });
    toast('إن كان البريد مسجّلًا ستصلك رسالة لإعادة التعيين');
  };
}
function showSetPassword() {
  $('#shell').hidden = true; const b = $('#login'); b.hidden = false;
  b.innerHTML = `<h1>تعيين كلمة المرور</h1><form id="pf"><label>كلمة المرور الجديدة (10 خانات على الأقل)</label><input id="np" type="password" minlength="10" autocomplete="new-password" required><button class="b" type="submit">حفظ ومتابعة</button></form>`;
  $('#pf').onsubmit = async e => {
    e.preventDefault();
    const { error } = await sb.auth.updateUser({ password: $('#np').value });
    if (error) return toast(error.message);
    history.replaceState(null, '', location.pathname); await start();
  };
}
function showInactive() {
  $('#shell').hidden = true; const b = $('#login'); b.hidden = false;
  b.innerHTML = `<h1>الحساب غير مفعّل</h1><p>حسابك لم يُفعَّل بعد أو تم إيقافه. تواصل مع مالك النظام.</p><button class="b" id="io">خروج</button>`;
  $('#io').onclick = () => sb.auth.signOut();
}
sb.auth.onAuthStateChange(ev => { if (ev === 'SIGNED_OUT') { me = null; if (chan) sb.removeChannel(chan); chan = null; showLogin(); } });

async function start() {
  const { data: { session } } = await sb.auth.getSession();
  if (!session) return showLogin();
  const { data, error } = await sb.from('profiles').select('*').eq('id', session.user.id).single();
  if (error || !data) return showLogin('تعذّر تحميل الحساب');
  me = data;
  if (!me.active) return showInactive();
  $('#login').hidden = true; $('#shell').hidden = false;
  $('#who').textContent = (me.full_name || me.email) + ' — ' + RL[me.role];
  tab = tabsFor()[0];
  await refresh(true); subscribe();
}

/* ---------------- data ---------------- */
const sel = async (t, s = '*', f) => { let q = sb.from(t).select(s); if (f) q = f(q); const { data, error } = await q; if (error) throw error; return data || []; };
async function load() {
  const live = q => q.is('deleted_at', null);
  const jobs = [
    sel('phases', '*', q => live(q).order('seq')),
    sel('tasks', '*', q => live(q).order('seq')),
    sel('task_notes', '*', q => q.order('created_at')),
    sel('attachments', '*', q => live(q)),
    sel('profiles', 'id,full_name,email,role,active', q => q.order('created_at')),
  ];
  if (isMg()) jobs.push(
    sb.rpc('dashboard'),
    sel('payments', '*, payment_items(*)', q => live(q).order('seq')),
    sel('payment_records', '*', q => live(q).order('created_at', { ascending: false })),
    sel('expenses', '*', q => live(q).order('created_at', { ascending: false })),
    sel('reserve_usage', '*', q => live(q).order('created_at', { ascending: false })),
    sel('client1_payments', '*', q => live(q).order('created_at', { ascending: false })),
    sel('client1_items', '*', q => q.order('seq')),
    sel('issues', '*', q => live(q).order('code')),
    sel('phase_approvals', '*', q => q.is('revoked_at', null)),
    sel('phase_costs', '*'),
    sel('projects', '*'),
    sel('budget_reference', '*', q => q.order('seq')),
    sel('report_snapshots', 'id,report_type,generated_at,generated_by', q => q.order('generated_at', { ascending: false }).limit(10)),
  );
  const r = await Promise.all(jobs);
  [D.phases, D.tasks, D.notes, D.att, D.profiles] = r;
  if (isMg()) {
    if (r[5].error) throw r[5].error;
    D.dash = r[5].data; [D.pays, D.recs, D.exps, D.res, D.c1p, D.c1i, D.iss, D.appr, D.pcost, D.proj, D.bref, D.snaps] = r.slice(6);
  }
}
async function refresh(first) {
  try { await load(); render(); if (!first) { const l = $('#live'); l.textContent = '● تم التحديث'; setTimeout(() => l.textContent = '● مباشر', 1500); } }
  catch (e) { toast('تعذّر تحميل البيانات: ' + msg(e)); }
}
function subscribe() {
  if (chan) sb.removeChannel(chan);
  chan = sb.channel('live');
  const t = ['phases', 'tasks', 'task_notes', 'profiles'].concat(isMg() ? ['payments', 'payment_records', 'expenses', 'reserve_usage', 'client1_payments', 'issues', 'phase_approvals'] : []);
  t.forEach(x => chan.on('postgres_changes', { event: '*', schema: 'public', table: x }, () => { clearTimeout(tm); tm = setTimeout(() => refresh(), 400); }));
  chan.subscribe();
}
async function loadAudit() {
  const { data, error } = await sb.from('audit_log').select('*').order('id', { ascending: false }).limit(200);
  if (error) return toast(msg(error)); D.audit = data; render();
}

/* ---------------- ui helpers ---------------- */
const tbl = (h, r) => `<div class="w"><table><tr>${h.map(x => `<th>${x}</th>`).join('')}</tr>${r.length ? r.map(x => `<tr>${x.map(c => `<td>${c}</td>`).join('')}</tr>`).join('') : `<tr><td colspan="${h.length}" class="mu">لا توجد بيانات</td></tr>`}</table></div>`;
const bars = (rows, mx) => rows.map(r => `<div class="r"><span>${H(r[0])}</span><div><i style="width:${mx > 0 ? Math.max(0, Math.min(100, r[1] / mx * 100)) : 0}%"></i></div><span>${r[2] ?? N(r[1])}</span></div>`).join('');
function ask(title, fs, ok) {
  const d = $('#dlg');
  d.innerHTML = `<h3>${title}</h3>` + fs.map(f => `<label>${f[1]}</label>` + (f[2] === 'sel'
    ? `<select id="f_${f[0]}">${f[4].map(o => `<option value="${H(o[0])}"${String(o[0]) === String(f[3]) ? ' selected' : ''}>${H(o[1])}</option>`).join('')}</select>`
    : f[2] === 'ta' ? `<textarea id="f_${f[0]}" rows="2">${H(f[3])}</textarea>` : `<input id="f_${f[0]}" type="${f[2]}" value="${H(f[3])}">`)).join('')
    + `<p><button class="b" id="fok">حفظ</button> <button class="b s" id="fno">إلغاء</button></p>`;
  $('#fno').onclick = () => d.close();
  $('#fok').onclick = async () => {
    const v = {}; fs.forEach(f => { const e = $('#f_' + f[0]); v[f[0]] = f[2] === 'number' ? (e.value === '' ? null : +e.value) : e.value; });
    if ((await ok(v)) !== false) d.close();
  };
  d.showModal();
}
async function run(p) { const { error } = await p; if (error) { toast(msg(error)); return false; } await refresh(); return true; }

/* ---------------- views ---------------- */
const V = {
  dash() {
    const d = D.dash || {}, rem = +d.budget + +d.reserve_used - +d.expenses_actual;
    const pend = (D.recs || []).filter(r => r.status === 'pending').length + (D.exps || []).filter(r => r.status === 'pending').length + (D.res || []).filter(r => r.status === 'pending').length + (D.c1p || []).filter(r => r.status === 'pending').length;
    const k = (l, v, s, c) => `<div class="card k ${c || ''}"><small>${l}</small><b>${v}</b>${s ? `<small>${s}</small>` : ''}</div>`;
    return `<div class="card"><span class="mu">جميع المبالغ بدون ضريبة القيمة المضافة — لا تدخل الإجماليات إلا العمليات المعتمدة.</span></div>
    <div class="g">${k('ميزانية تطوير المنتج', R(d.budget), '', 'au')}${k('المصروف الفعلي (معتمد)', R(d.expenses_actual), 'بانتظار الاعتماد: ' + R(d.expenses_pending))}${k('الدفعات المعتمدة', R(d.paid), 'بانتظار الاعتماد: ' + R(d.payments_pending))}${k('المتبقي من الدفعات', R(d.planned - d.paid), 'من ' + R(d.planned))}${k('الميزانية المتبقية', R(rem))}
    ${k('الاحتياطي (مستقل)', R(d.reserve), 'المستخدم: ' + R(d.reserve_used) + ' | المتبقي: ' + R(d.reserve - d.reserve_used), 'au')}${k('العميل الأول (مستقل)', R(d.client1_budget), 'المدفوع: ' + R(d.client1_paid) + ' | المصروف: ' + R(d.client1_expenses), 'au')}
    ${k('الإنجاز العام', N(d.progress) + '%')}${k('مراحل معتمدة', d.phases_approved + ' / ' + d.phases_total)}${k('مهام متأخرة', D.tasks.filter(isLate).length)}${k('بانتظار الاعتماد', pend + ' عملية')}</div>
    <div class="g g2"><div class="card"><h3>الدفعات الأربع</h3>${bars((d.payments || []).map(p => [p.code + ' – ' + p.name, p.paid, N(p.paid) + ' / ' + N(p.amount)]), Math.max(1, ...(d.payments || []).map(p => +p.amount)))}</div>
    <div class="card"><h3>إنجاز المراحل</h3>${bars((d.phases || []).map(p => [p.name + (p.approved ? ' ✓' : ''), p.progress, N(p.progress) + '%']), 100)}</div></div>`;
  },
  pay() {
    const pm = {}; ((D.dash || {}).payments || []).forEach(p => pm[p.code] = p);
    const rows = D.pays.map(p => {
      const s = pm[p.code] || {}, st = s.remaining <= 0 ? 'مدفوعة بالكامل' : s.paid > 0 ? 'مدفوعة جزئيًا' : p.due_flag ? 'مستحقة' : 'غير مستحقة';
      return [p.code, `<details><summary>${H(p.name)}</summary>${(p.payment_items || []).sort((a, b) => a.seq - b.seq).map(i => `<div class="mu">${H(i.description)}: ${N(i.amount)}</div>`).join('')}</details>`, N(s.amount), N(s.paid), N(s.pending), N(s.remaining), `<span class="t ${s.remaining <= 0 ? 'ok' : s.paid > 0 ? 'wr' : ''}">${st}</span>`, p.due_date || '—', H(p.payee) || '—',
        can.pay() ? `<button class="b" data-a="recPay" data-id="${p.id}">تسجيل دفعة</button><button class="b s" data-a="editPay" data-id="${p.id}">تعديل</button>` : ''];
    });
    const rec = (D.recs || []).map(r => { const code = (D.pays.find(p => p.id === r.payment_id) || {}).code; return [code, N(r.amount), r.paid_date, H(r.payee), H(r.ref), stTag(r.status), PNm(r.created_by), H(r.decision_note) || '', can.approve() && r.status === 'pending' ? `<button class="b" data-a="dec" data-t="payment_records" data-id="${r.id}" data-s="approved" ${r.created_by === me.id ? 'disabled title="لا يمكنك اعتماد عملية سجّلتها"' : ''}>اعتماد</button><button class="b x" data-a="dec" data-t="payment_records" data-id="${r.id}" data-s="rejected">رفض</button>` : '', fb('payment_record', r.id)]; });
    return `<div class="card">${tbl(['رقم', 'المرحلة (البنود)', 'القيمة', 'المعتمد المدفوع', 'بانتظار الاعتماد', 'المتبقي', 'الحالة', 'الاستحقاق', 'المستفيد', ''], rows)}</div>
    <p class="mu">القيمة والبنود معتمدة ولا يغيّرها إلا المالك. الدفعة المسجّلة لا تدخل الإجمالي إلا بعد اعتماد المالك.</p>
    <div class="card"><h3>سجل الدفعات</h3>${tbl(['الدفعة', 'المبلغ', 'التاريخ', 'المستفيد', 'سند', 'الحالة', 'سجّلها', 'ملاحظة', '', 'مرفقات'], rec)}</div>`;
  },
  exp() {
    const ex = (D.exps || []).map(e => [e.expense_date, H(e.name), H(e.category), e.scope === 'product' ? 'المنتج' : 'العميل الأول', H(e.payee), N(e.amount), H(e.ref), stTag(e.status), PNm(e.created_by), can.approve() && e.status === 'pending' ? `<button class="b" data-a="dec" data-t="expenses" data-id="${e.id}" data-s="approved" ${e.created_by === me.id ? 'disabled title="لا يمكنك اعتماد عملية سجّلتها"' : ''}>اعتماد</button><button class="b x" data-a="dec" data-t="expenses" data-id="${e.id}" data-s="rejected">رفض</button>` : '', fb('expense', e.id)]);
    const rs = (D.res || []).map(r => [r.usage_date, N(r.amount), H(r.note), stTag(r.status), PNm(r.created_by), can.approve() && r.status === 'pending' ? `<button class="b" data-a="dec" data-t="reserve_usage" data-id="${r.id}" data-s="approved" ${r.created_by === me.id ? 'disabled' : ''}>اعتماد</button><button class="b x" data-a="dec" data-t="reserve_usage" data-id="${r.id}" data-s="rejected">رفض</button>` : '']);
    const c1 = (D.c1p || []).map(r => [r.paid_date, N(r.amount), H(r.payee), H(r.ref), stTag(r.status), PNm(r.created_by), can.approve() && r.status === 'pending' ? `<button class="b" data-a="dec" data-t="client1_payments" data-id="${r.id}" data-s="approved" ${r.created_by === me.id ? 'disabled' : ''}>اعتماد</button><button class="b x" data-a="dec" data-t="client1_payments" data-id="${r.id}" data-s="rejected">رفض</button>` : '', fb('client1_payment', r.id)]);
    return `<p>${can.exp() ? '<button class="b" data-a="newExp">+ مصروف جديد</button>' : ''} ${(can.approve() || me.role === 'finance') ? '<button class="b s" data-a="newRes">+ طلب استخدام احتياطي</button><button class="b s" data-a="newC1">+ دفعة للعميل الأول</button>' : ''}</p>
    <div class="card"><h3>المصروفات</h3>${tbl(['التاريخ', 'المصروف', 'التصنيف', 'النطاق', 'المورد', 'المبلغ', 'سند', 'الحالة', 'سجّله', '', 'مرفقات'], ex)}</div>
    <div class="card"><h3>الاحتياطي المالي (يُصرف بموافقة المالك فقط)</h3>${tbl(['التاريخ', 'المبلغ', 'المبرر', 'الحالة', 'سجّله', ''], rs)}</div>
    <div class="card"><h3>حساب العميل الأول (35,000 — مستقل)</h3>${tbl(['البند', 'المبلغ'], (D.c1i || []).map(i => [H(i.description), N(i.amount)]))}<p></p>${tbl(['التاريخ', 'المبلغ', 'المستفيد', 'سند', 'الحالة', 'سجّله', '', 'مرفقات'], c1)}</div>`;
  },
  ph() {
    const team = me.role === 'team_member';
    return (team ? `<p class="mu">تظهر هنا المهام المسندة إليك فقط. يمكنك تحديث الإنجاز وإضافة الملاحظات والمرفقات.</p>` : '') + D.phases.map(ph => {
      const ts = D.tasks.filter(t => t.phase_id === ph.id), pct = ts.length ? ts.reduce((a, t) => a + t.progress, 0) / ts.length : 0;
      const ap = (D.appr || []).find(a => a.phase_id === ph.id);
      const rows = ts.map(t => {
        const cp = me.role === 'owner' || me.role === 'project_manager' || t.assignee_id === me.id;
        const late = isLate(t);
        return [H(t.code), H(t.title), t.assignee_id ? PNm(t.assignee_id) : `<span class="mu">${H(t.owner_label)}</span>`, PRIO[t.priority], t.duration_text ? 'مدة ' + H(t.duration_text) + ' أيام' : (t.week_from ? 'أسبوع ' + t.week_from + (t.week_to && t.week_to !== t.week_from ? '–' + t.week_to : '') : '—'), (pStart(t) || '—') + ' → ' + (pEnd(t) || '—'),
          cp ? `<select data-c="prog" data-id="${t.id}">${[0, 25, 50, 75, 100].map(v => `<option${v === t.progress ? ' selected' : ''}>${v}</option>`).join('')}</select>` : t.progress + '%',
          `<span class="t ${t.status === 'done' ? 'ok' : late || t.status === 'blocked' ? 'er' : t.status === 'in_progress' ? 'wr' : ''}">${late ? 'متأخرة' : TSTAT[t.status]}</span>`,
          `<button class="b s" data-a="notes" data-id="${t.id}">ملاحظات (${D.notes.filter(n => n.task_id === t.id).length})</button><button class="b s" data-a="files" data-id="${t.id}">مرفقات (${D.att.filter(a => a.entity_id === t.id).length})</button>` + (can.plan() ? `<button class="b s" data-a="editTask" data-id="${t.id}">تعديل/إسناد</button>` : '')];
      });
      if (team && !ts.length) return '';
      return `<div class="card"><h3>${H(ph.name)} <span class="t ${ap ? 'ok' : ''}">${ap ? 'معتمدة ' + ap.approved_on : N(pct) + '%'}</span> <span class="mu">أسبوع ${ph.week_from}–${ph.week_to}</span> ${can.plan() ? `<button class="b s" data-a="editPh" data-id="${ph.id}">تعديل المدة</button>` : ''} ${techCost(ph)}</h3>
      ${team ? '' : `<p class="mu"><b>المسؤول:</b> ${H(ph.owner_label)}<br><b>المخرجات:</b> ${H(ph.outputs)}<br><b>شرط الاعتماد:</b> ${H(ph.approval_condition)}</p>`}
      ${tbl(['الكود', 'المهمة', 'المسؤول', 'الأولوية', 'المدة', 'التواريخ', 'الإنجاز', 'الحالة', ''], rows)}
      ${can.phaseAppr() ? `<p>${ap ? (me.role === 'owner' ? `<button class="b x" data-a="unappr" data-id="${ap.id}">إلغاء الاعتماد</button>` : '') : `<button class="b" data-a="appr" data-id="${ph.id}" ${pct < 100 ? 'disabled title="تكتمل المهام أولًا"' : ''}>اعتماد المرحلة ومخرجاتها</button>`}</p>` : ''}</div>`;
    }).join('');
  },
  iss() {
    return recon() + (can.issue() ? '<p><button class="b" data-a="newIss">+ إضافة</button></p>' : '') + `<div class="card">${tbl(['الكود', 'النوع', 'الموضوع', 'التفاصيل', 'الحالة', 'القرار', ''], (D.iss || []).map(i => [i.code, i.kind === 'risk' ? 'خطر' : 'تعارض', H(i.title), H(i.details), can.issue() ? `<select data-c="iss" data-id="${i.id}">${[['open', 'مفتوح'], ['in_progress', 'قيد المتابعة'], ['resolved', 'محسوم']].map(o => `<option value="${o[0]}"${o[0] === i.status ? ' selected' : ''}>${o[1]}</option>`).join('')}</select>` : i.status, H(i.resolution_note), can.issue() ? `<button class="b s" data-a="resIss" data-id="${i.id}">قرار</button>` : '']))}</div>`;
  },
  users() {
    return `<p><button class="b" data-a="invite">+ دعوة عضو</button></p><div class="card">${tbl(['الاسم', 'البريد', 'الدور', 'فعّال'], (D.profiles || []).map(p => [H(p.full_name), H(p.email), `<select data-c="role" data-id="${p.id}">${Object.keys(RL).map(r => `<option value="${r}"${r === p.role ? ' selected' : ''}>${RL[r]}</option>`).join('')}</select>`, `<input type="checkbox" data-c="act" data-id="${p.id}" ${p.active ? 'checked' : ''} ${p.id === me.id ? 'disabled' : ''}>`]))}</div><p class="mu">الدعوة تصل بالبريد ليعيّن العضو كلمة مروره بنفسه. لا تُرسل كلمات المرور في أي مكان.</p>`;
  },
  audit() {
    const diff = a => a.action !== 'UPDATE' ? '' : Object.keys(a.new_data || {}).filter(k => JSON.stringify((a.new_data || {})[k]) !== JSON.stringify((a.old_data || {})[k])).join('، ');
    return `<div class="card">${tbl(['الوقت', 'المستخدم', 'الدور', 'العملية', 'الجدول', 'الحقول المتغيرة'], (D.audit || []).map(a => [when(a.at), H(a.user_email), H(a.user_role), a.action, H(a.table_name), H(diff(a))]))}</div><p class="mu">آخر 200 عملية. السجل لا يُعدَّل ولا يُحذف.</p>`;
  },
};

V.rep = function () {
  const r = repData(repSel), names = [['1', 'مالي شامل'], ['2', 'الدفعات'], ['3', 'المصروفات'], ['4', 'المراحل'], ['5', 'الميزانية مقابل الفعلي'], ['6', 'التأخير والمخاطر']];
  return `<div class="card nop">${names.map(x => `<button class="b ${x[0] === repSel ? '' : 's'}" data-a="repSel" data-id="${x[0]}">${x[1]}</button>`).join('')} <span style="float:left"><button class="b" data-a="repCsv">تصدير Excel (CSV)</button><button class="b" data-a="repPrint">PDF / طباعة</button><button class="b s" data-a="repSnap">حفظ لقطة</button></span></div>
  <div class="card"><h3>${H(r.t)} <span class="mu">${today()}</span></h3>${tbl(r.h, r.r.map(x => x.map(v => typeof v === 'number' ? N(v) : H(v))))}</div>
  <div class="card nop"><h3>لقطات محفوظة</h3>${tbl(['النوع', 'التاريخ', 'أصدرها'], (D.snaps || []).map(x => [H(x.report_type), when(x.generated_at), PNm(x.generated_by)]))}</div>`;
};
V.set = function () {
  const p = (D.proj || [])[0] || {}, ow = me.role === 'owner';
  return `<div class="card"><h3>إعدادات المشروع</h3>${tbl(['الإعداد', 'القيمة'], [['اسم المشروع', H(p.name)], ['تاريخ بدء المشروع', p.start_date || 'غير محدد'], ['ميزانية تطوير المنتج (معتمدة — للقراءة فقط)', R(p.product_budget)], ['الاحتياطي (للقراءة فقط)', N(p.reserve_pct) + '% = ' + R(p.reserve_amount)], ['تكلفة العميل الأول (معتمدة — للقراءة فقط)', R(p.client1_budget)], ['الربط الإضافي', N(p.extra_integration_usd) + ' دولار للعملية (سعر الصرف ' + p.fx_rate + ')'], ['السيرفر', p.server_users + ' مستخدمًا / ' + R(p.server_annual_cost) + ' سنويًا'], ['تسليم النسخة الأولية', p.first_delivery_weeks + ' أسابيع'], ['مدة المشروع الكاملة', 'حتى ' + p.total_months + ' أشهر']])}
  <p class="mu">جميع المبالغ بدون ضريبة القيمة المضافة. أرقام الميزانية والاحتياطي وتكلفة العميل الأول لا تُعدَّل من الواجهة؛ تغييرها قرار موثّق يجريه المالك على قاعدة البيانات ويُسجَّل في سجل العمليات.</p>
  ${ow ? '<p><button class="b" data-a="editSet">تعديل الإعدادات</button> ' : '<p>'}${can.plan() ? '<button class="b s" data-a="fixDates">تثبيت التواريخ المخططة للمهام من تاريخ البدء</button>' : ''}</p></div>
  ${ow ? `<div class="card"><h3>نسخة احتياطية</h3><button class="b" data-a="exportJson">تنزيل نسخة JSON كاملة</button><p class="mu">تشمل كل الجداول المرئية للمالك وآخر 1000 سجل تدقيق. احفظها في مكان آمن خارج النظام.</p></div>` : ''}`;
};
function render() {
  const ts = tabsFor(); if (!ts.includes(tab)) tab = ts[0];
  $('#nav').innerHTML = `<h1>FGS HIS</h1><p>Project Management</p>` + ts.map(t => `<button class="${t === tab ? 'on' : ''}" data-t="${t}">${tabName(t)}</button>`).join('');
  $('#ttl').textContent = tabName(tab);
  try { $('#app').innerHTML = V[tab](); } catch (e) { $('#app').innerHTML = `<div class="card warn">تعذّر العرض: ${H(msg(e))}</div>`; }
}

/* ---------------- actions (UI only; the database decides what is allowed) ---------------- */
const stageOpts = () => [['', '— بدون —']].concat((D.pays || []).map(p => [p.id, p.code + ' – ' + p.name]));
const phaseOpts = () => [['', '— بدون —']].concat((D.phases || []).map(p => [p.id, p.name]));
const A = {
  recPay(id) { ask('تسجيل دفعة (ستكون «بانتظار الاعتماد»)', [['amount', 'المبلغ', 'number', ''], ['paid_date', 'تاريخ الدفع', 'date', today()], ['payee', 'المستفيد', 'text', ''], ['ref', 'رقم الفاتورة/السند', 'text', ''], ['notes', 'ملاحظات', 'ta', '']], v => v.amount > 0 ? run(sb.from('payment_records').insert({ payment_id: id, amount: v.amount, paid_date: v.paid_date, payee: v.payee, ref: v.ref, notes: v.notes })) : (toast('أدخل مبلغًا صحيحًا'), false)); },
  editPay(id) { const p = D.pays.find(x => x.id === id); ask('تعديل بيانات الدفعة', [['due_date', 'تاريخ الاستحقاق', 'date', p.due_date || ''], ['due_flag', 'مستحقة؟', 'sel', p.due_flag, [[false, 'لا'], [true, 'نعم']]], ['payee', 'المستفيد', 'text', p.payee], ['ref', 'سند', 'text', p.ref], ['notes', 'ملاحظات', 'ta', p.notes]], v => run(sb.from('payments').update({ due_date: v.due_date || null, due_flag: v.due_flag === 'true', payee: v.payee, ref: v.ref, notes: v.notes }).eq('id', id))); },
  async dec(id, b) {
    const t = b.dataset.t, status = b.dataset.s, note = prompt(status === 'approved' ? 'ملاحظة الاعتماد (اختياري)' : 'سبب الرفض'); if (note === null) return;
    const u = { status, decision_note: note || null };
    let { error } = await sb.from(t).update(u).eq('id', id);
    if (error && t === 'expenses' && /EXCEEDS_BUDGET/.test(error.message)) {
      const why = prompt('هذا المصروف يتجاوز الميزانية المعتمدة. اكتب مرجع موافقة المستثمر/سبب التجاوز للمتابعة:'); if (!why) return toast('لم يُعتمد');
      ({ error } = await sb.from(t).update({ ...u, override_reason: why }).eq('id', id));
    }
    if (error) return toast(msg(error)); await refresh();
  },
  newExp() { ask('مصروف جديد (سيكون «بانتظار الاعتماد»)', [['name', 'اسم المصروف', 'text', ''], ['category', 'التصنيف', 'sel', 'تطوير', ['تطوير', 'موديولات', 'ربط وتكامل', 'بنية تحتية', 'واجهات وتصميم', 'إدارة المنتج والمشروع', 'تنفيذ ودعم', 'سيرفر التشغيل', 'ربط إضافي', 'أخرى'].map(x => [x, x])], ['scope', 'النطاق', 'sel', 'product', [['product', 'تطوير المنتج'], ['client1', 'العميل الأول']]], ['stage_payment_id', 'المرحلة المالية (الدفعة)', 'sel', '', stageOpts()], ['phase_id', 'المرحلة التقنية (اختياري)', 'sel', '', phaseOpts()], ['payee', 'المورد/المستفيد', 'text', ''], ['amount', 'المبلغ', 'number', ''], ['expense_date', 'التاريخ', 'date', today()], ['method', 'طريقة الدفع', 'text', ''], ['ref', 'رقم الفاتورة/السند', 'text', ''], ['notes', 'ملاحظات', 'ta', '']], v => (!v.name || !(v.amount > 0)) ? (toast('الاسم والمبلغ مطلوبان'), false) : run(sb.from('expenses').insert({ ...v, stage_payment_id: v.stage_payment_id || null, phase_id: v.phase_id || null }))); },
  newRes() { ask('طلب استخدام الاحتياطي (يعتمده المالك)', [['amount', 'المبلغ', 'number', ''], ['usage_date', 'التاريخ', 'date', today()], ['note', 'المبرر', 'ta', '']], v => v.amount > 0 ? run(sb.from('reserve_usage').insert(v)) : false); },
  newC1() { ask('دفعة للعميل الأول (بانتظار الاعتماد)', [['amount', 'المبلغ', 'number', ''], ['paid_date', 'التاريخ', 'date', today()], ['payee', 'المستفيد', 'text', ''], ['ref', 'سند', 'text', ''], ['notes', 'ملاحظات', 'ta', '']], v => v.amount > 0 ? run(sb.from('client1_payments').insert(v)) : false); },
  editPh(id) { const p = D.phases.find(x => x.id === id); ask('مدة المرحلة — ' + H(p.name), [['week_from', 'من أسبوع', 'number', p.week_from], ['week_to', 'إلى أسبوع', 'number', p.week_to], ['owner_label', 'المسؤول', 'text', p.owner_label]], v => run(sb.from('phases').update(v).eq('id', id))); },
  appr(id) { ask('اعتماد المرحلة', [['approved_on', 'تاريخ الاعتماد', 'date', today()], ['doc_ref', 'رقم المحضر/المرجع', 'text', ''], ['client_approver', 'المعتمِد من جهة العميل', 'text', '']], v => run(sb.from('phase_approvals').insert({ phase_id: id, ...v }))); },
  unappr(id) { if (confirm('إلغاء اعتماد المرحلة؟')) run(sb.from('phase_approvals').update({ revoked_at: new Date().toISOString() }).eq('id', id)); },
  editTask(id) {
    const t = D.tasks.find(x => x.id === id), act = (D.profiles || []).filter(p => p.active);
    ask('تعديل/إسناد: ' + H(t.title), [['assignee_id', 'المسؤول', 'sel', t.assignee_id || '', [['', '— غير مسند —']].concat(act.map(p => [p.id, (p.full_name || p.email) + ' — ' + RL[p.role]]))], ['priority', 'الأولوية', 'sel', t.priority, Object.keys(PRIO).map(k => [k, PRIO[k]])], ['status', 'الحالة', 'sel', t.status, Object.keys(TSTAT).map(k => [k, TSTAT[k]])], ['planned_start', 'تاريخ البداية', 'date', t.planned_start || ''], ['planned_end', 'تاريخ النهاية', 'date', t.planned_end || ''], ['week_from', 'من أسبوع', 'number', t.week_from ?? ''], ['week_to', 'إلى أسبوع', 'number', t.week_to ?? ''], ['duration_text', 'المدة بالأيام (مثال 7–10)', 'text', t.duration_text || '']],
      v => run(sb.from('tasks').update({ assignee_id: v.assignee_id || null, priority: v.priority, status: v.status, planned_start: v.planned_start || null, planned_end: v.planned_end || null, week_from: v.week_from, week_to: v.week_to, duration_text: v.duration_text || null }).eq('id', id)));
  },
  notes(id) {
    const t = D.tasks.find(x => x.id === id), d = $('#dlg'), ns = D.notes.filter(n => n.task_id === id);
    d.innerHTML = `<h3>ملاحظات: ${H(t.title)}</h3>` + (ns.map(n => `<p><b>${H(PNm(n.author_id))}</b> <span class="mu">${when(n.created_at)}</span><br>${H(n.body)}</p>`).join('') || '<p class="mu">لا توجد ملاحظات</p>') + `<label>إضافة ملاحظة</label><textarea id="nb" rows="3"></textarea><p><button class="b" id="nok">إضافة</button> <button class="b s" id="fno">إغلاق</button></p>`;
    $('#fno').onclick = () => d.close();
    $('#nok').onclick = async () => { const body = $('#nb').value.trim(); if (!body) return; if (await run(sb.from('task_notes').insert({ task_id: id, body }))) { d.close(); A.notes(id); } };
    d.showModal();
  },
  files(id) {
    const t = D.tasks.find(x => x.id === id), d = $('#dlg'), fl = D.att.filter(a => a.entity_id === id);
    d.innerHTML = `<h3>مرفقات: ${H(t.title)}</h3>` + (fl.map(a => `<div>${H(a.file_name)} <button class="b s" data-open="${H(a.storage_path)}">فتح</button></div>`).join('') || '<p class="mu">لا توجد مرفقات</p>') + `<label>رفع ملف (PDF/PNG/JPG حتى 10MB)</label><input type="file" id="up" accept=".pdf,.png,.jpg,.jpeg"><p><button class="b" id="upb">رفع</button> <button class="b s" id="fno">إغلاق</button></p>`;
    $('#fno').onclick = () => d.close();
    d.querySelectorAll('[data-open]').forEach(b => b.onclick = async () => { const { data, error } = await sb.storage.from('attachments').createSignedUrl(b.dataset.open, 60); if (error) return toast(msg(error)); window.open(data.signedUrl, '_blank', 'noopener'); });
    $('#upb').onclick = async () => {
      const f = $('#up').files[0]; if (!f) return; if (f.size > 10485760) return toast('الحد الأقصى 10MB');
      const path = `task/${id}/${Date.now()}-${f.name.replace(/[^A-Za-z0-9._-]/g, '_')}`;
      const up = await sb.storage.from('attachments').upload(path, f, { contentType: f.type }); if (up.error) return toast(msg(up.error));
      if (await run(sb.from('attachments').insert({ entity_type: 'task', entity_id: id, storage_path: path, file_name: f.name, mime_type: f.type, size_bytes: f.size }))) { d.close(); A.files(id); }
    };
    d.showModal();
  },
  newIss() { ask('إضافة خطر أو تعارض', [['kind', 'النوع', 'sel', 'risk', [['risk', 'خطر'], ['conflict', 'تعارض']]], ['title', 'الموضوع', 'text', ''], ['details', 'التفاصيل', 'ta', '']], v => { if (!v.title) return false; const code = (v.kind === 'risk' ? 'R' : 'C') + (100 + (D.iss || []).length + 1); return run(sb.from('issues').insert({ ...v, code })); }); },
  resIss(id) { const i = D.iss.find(x => x.id === id); ask('قرار / ملاحظة', [['resolution_note', 'النص', 'ta', i.resolution_note]], v => run(sb.from('issues').update({ resolution_note: v.resolution_note }).eq('id', id))); },
  invite() { ask('دعوة عضو جديد', [['email', 'البريد الإلكتروني', 'email', ''], ['full_name', 'الاسم', 'text', ''], ['role', 'الدور', 'sel', 'team_member', Object.keys(RL).map(r => [r, RL[r]])]], async v => { if (!v.email) return false; const { data, error } = await sb.functions.invoke('admin-users', { body: { action: 'invite', ...v } }); if (error || (data && data.error)) { toast((data && data.error) || msg(error)); return false; } toast('أُرسلت الدعوة'); await refresh(); }); },
};

A.files = function (id, b) {
  const et = (b && b.dataset && b.dataset.et) || 'task', d = $('#dlg');
  const src = { task: D.tasks, expense: D.exps || [], payment_record: D.recs || [], client1_payment: D.c1p || [] }[et] || [];
  const row = src.find(x => x.id === id) || {}, label = row.title || row.name || row.ref || String(id).slice(0, 8);
  const canUp = et === 'task' ? ['owner', 'project_manager', 'team_member'].includes(me.role) : et === 'expense' ? ['owner', 'finance', 'project_manager'].includes(me.role) : ['owner', 'finance'].includes(me.role);
  const fl = (D.att || []).filter(a => a.entity_type === et && a.entity_id === id);
  d.innerHTML = `<h3>مرفقات: ${H(label)}</h3>` + (fl.map(a => `<div>${H(a.file_name)} <button class="b s" data-open="${H(a.storage_path)}">فتح</button></div>`).join('') || '<p class="mu">لا توجد مرفقات</p>')
    + (canUp ? `<label>رفع ملف (PDF/PNG/JPG حتى 10MB)</label><input type="file" id="up" accept=".pdf,.png,.jpg,.jpeg"><p><button class="b" id="upb">رفع</button> <button class="b s" id="fno">إغلاق</button></p>` : `<p><button class="b s" id="fno">إغلاق</button></p>`);
  $('#fno').onclick = () => d.close();
  d.querySelectorAll('[data-open]').forEach(x => x.onclick = async () => { const { data, error } = await sb.storage.from('attachments').createSignedUrl(x.dataset.open, 60); if (error) return toast(msg(error)); window.open(data.signedUrl, '_blank', 'noopener'); });
  if (canUp) $('#upb').onclick = async () => {
    const f = $('#up').files[0]; if (!f) return; if (f.size > 10485760) return toast('الحد الأقصى 10MB');
    const path = `${et}/${id}/${Date.now()}-${f.name.replace(/[^A-Za-z0-9._-]/g, '_')}`;
    const up = await sb.storage.from('attachments').upload(path, f, { contentType: f.type }); if (up.error) return toast(msg(up.error));
    if (await run(sb.from('attachments').insert({ entity_type: et, entity_id: id, storage_path: path, file_name: f.name, mime_type: f.type, size_bytes: f.size }))) { d.close(); A.files(id, { dataset: { et } }); }
  };
  d.showModal();
};
A.repSel = id => { repSel = id; render(); };
A.repCsv = () => { const r = repData(repSel), q = v => '"' + String(v ?? '').replace(/"/g, '""') + '"'; dl('FGS-HIS-report-' + repSel + '-' + today() + '.csv', '\ufeff' + [r.h].concat(r.r).map(x => x.map(q).join(',')).join('\r\n'), 'text/csv;charset=utf-8'); };
A.repPrint = () => window.print();
A.repSnap = async () => { const r = repData(repSel); await run(sb.from('report_snapshots').insert({ report_type: repSel + ' – ' + r.t, params: {}, payload: { title: r.t, headers: r.h, rows: r.r } })); toast('حُفظت اللقطة'); };
A.phCost = id => { const ph = D.phases.find(x => x.id === id), cur = ((D.pcost || []).find(c => c.phase_id === id) || {}).cost || 0; ask('تكلفة المرحلة التقنية (اختيارية) — ' + H(ph.name), [['cost', 'التكلفة (ر.س)', 'number', cur]], v => (v.cost == null || v.cost < 0) ? false : run(sb.from('phase_costs').upsert({ phase_id: id, cost: v.cost }))); };
A.editSet = () => { const p = D.proj[0]; ask('تعديل إعدادات المشروع', [['start_date', 'تاريخ بدء المشروع', 'date', p.start_date || ''], ['extra_integration_usd', 'الربط الإضافي (دولار للعملية)', 'number', p.extra_integration_usd], ['fx_rate', 'سعر الصرف (ريال/دولار)', 'number', p.fx_rate], ['server_users', 'سعة السيرفر (مستخدمين)', 'number', p.server_users], ['server_annual_cost', 'تكلفة السيرفر السنوية', 'number', p.server_annual_cost], ['first_delivery_weeks', 'تسليم النسخة الأولية (أسابيع)', 'number', p.first_delivery_weeks], ['total_months', 'مدة المشروع (أشهر)', 'number', p.total_months]], v => run(sb.from('projects').update({ ...v, start_date: v.start_date || null }).eq('id', p.id))); };
A.fixDates = async () => {
  const st = projStart(); if (!st) return toast('حدّد تاريخ بدء المشروع أولًا (تعديل الإعدادات)');
  const ts = D.tasks.filter(t => t.week_from && !t.planned_start && !t.planned_end); if (!ts.length) return toast('لا توجد مهام تحتاج تثبيت');
  if (!confirm('تثبيت التواريخ المخططة لـ ' + ts.length + ' مهمة من تاريخ البدء؟ يمكن تعديل كل مهمة بعدها.')) return;
  const res = await Promise.all(ts.map(t => sb.from('tasks').update({ planned_start: pStart(t), planned_end: pEnd(t) }).eq('id', t.id)));
  const bad = res.find(x => x.error); if (bad) toast(msg(bad.error)); await refresh();
};
A.exportJson = async () => {
  const { data: aud } = await sb.from('audit_log').select('*').order('id');
  const out = { exported_at: new Date().toISOString(), exported_by: me.email, projects: D.proj, phases: D.phases, phase_costs: D.pcost, phase_approvals: D.appr, payments: D.pays, payment_records: D.recs, expenses: D.exps, reserve_usage: D.res, client1_items: D.c1i, client1_payments: D.c1p, tasks: D.tasks, task_notes: D.notes, attachments: D.att, issues: D.iss, profiles: D.profiles, budget_reference: D.bref, audit_log: aud || [] };
  dl('fgs-his-backup-' + today() + '.json', JSON.stringify(out, null, 1), 'application/json');
};
const C = {
  prog(id, v) { run(sb.from('tasks').update({ progress: +v }).eq('id', id)); },
  iss(id, v) { run(sb.from('issues').update({ status: v }).eq('id', id)); },
  async role(id, v) { const { data, error } = await sb.functions.invoke('admin-users', { body: { action: 'set_role', user_id: id, role: v } }); if (error || (data && data.error)) toast((data && data.error) || msg(error)); await refresh(); },
  async act(id, v, el) { const { data, error } = await sb.functions.invoke('admin-users', { body: { action: 'set_active', user_id: id, active: el.checked } }); if (error || (data && data.error)) toast((data && data.error) || msg(error)); await refresh(); },
};
$('#nav').onclick = e => { const t = e.target.dataset.t; if (t) { tab = t; render(); if (t === 'audit') loadAudit(); } };
$('#app').onclick = e => { const b = e.target.closest('[data-a]'); if (b && A[b.dataset.a]) A[b.dataset.a](b.dataset.id, b); };
$('#app').onchange = e => { const s = e.target.closest('[data-c]'); if (s && C[s.dataset.c]) C[s.dataset.c](s.dataset.id, s.value, s); };
$('#out').onclick = () => sb.auth.signOut();

(async () => {
  const { data: { session } } = await sb.auth.getSession();
  if (!session) return showLogin();
  if (/type=(invite|recovery)/.test(INITIAL_HASH)) return showSetPassword();
  await start();
})();

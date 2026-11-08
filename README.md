# FGS HIS – Project Management

نظام إدارة ومتابعة مشروع FGS HIS: واجهة ويب ثابتة (HTML/JS/CSS) + Supabase (PostgreSQL + Auth + Realtime + Storage).
الميزانية 95,750 ر.س (أربع دفعات)، الاحتياطي 19,150 ر.س مستقل، تكلفة العميل الأول 35,000 ر.س مستقلة. جميع المبالغ بدون ضريبة القيمة المضافة.

## بنية المجلد
| المسار | المحتوى |
|---|---|
| `web/` | التطبيق: `index.html` `app.js` `style.css` `config.js` `_headers` |
| `supabase/migrations/` | ملفات SQL مرتبة بالطابع الزمني (001→007) = ما طُبّق فعليًا على المشروع |
| `supabase/functions/admin-users/` | دالة إدارة المستخدمين (TypeScript/Deno) — المفتاح السري يبقى داخل Supabase |
| `supabase/tests/rls_smoke.sql` | اختبار صلاحيات يُنفّذ داخل معاملة تُلغى (لا يترك أثرًا) |
| `scripts/` | `bootstrap-owner.sql` `restore-check.sql` `vendor.mjs` |
| `.github/workflows/external-backup.yml` | قالب نسخ احتياطي خارجي مشفّر (يدوي حتى تُنشأ الأسرار) |
| `docs/` | الصلاحيات، إقامة البيانات |
| `legacy/fgs-his-pm.html` | النسخة القديمة (أرشيف مرجعي فقط) |

## التشغيل محليًا
```bash
npm run serve        # يخدم web/ على http://localhost:8080
```
يتصل بمشروع Supabase المحدد في `web/config.js` (قيم عامة فقط). لا توجد خطوة بناء.

## إعداد Supabase (مشروع جديد أو القائم)
1. طبّق الترحيلات بالترتيب: `supabase link --project-ref <REF>` ثم `supabase db push` (أو الصق الملفات 001→007 في SQL Editor بالترتيب).
2. انشر الدالة: `supabase functions deploy admin-users` (verify_jwt مفعّل).
3. Authentication: عطّل **Allow new users to sign up**، واضبط **Site URL** و**Redirect URLs** على رابط الاستضافة، واضبط SMTP للدعوات، وكلمة مرور ≥ 10 خانات.
4. أنشئ المالك الأول: `scripts/bootstrap-owner.sql` (لا تضع بريدًا حقيقيًا في المستودع).
5. حدّث `web/config.js` بعنوان المشروع والمفتاح **العام** (publishable) فقط.

## النشر (Cloudflare Pages)
Pages → Create → Direct Upload (أو ربط المستودع) → Build command: *(فارغ)* → Output directory: `web`. ملف `web/_headers` يفرض CSP وترويسات الأمان. بعد النشر أضف رابط الموقع إلى Redirect URLs في Supabase.
قبل الإطلاق: `npm install && npm run vendor` ثم غيّر `index.html` إلى `vendor/supabase.js` واحذف `cdn.jsdelivr.net` من `_headers`.

## الدفع إلى GitHub (مستودع Private)
```bash
cd FGS-HIS
git init -b main
git add . && git status          # راجع القائمة: لا يوجد .env ولا مفاتيح
git commit -m "Initial import: FGS HIS Project Management"
git remote add origin https://github.com/MoayadAlasoul/FGS-HIS.git
git push -u origin main
```
تأكد من أن المستودع Private وأن المصادقة الثنائية مفعّلة، وفعّل حماية الفرع `main`.

## الأمان
- لا توجد أي مفاتيح سرية في الحزمة؛ `config.js` يحوي عنوان المشروع والمفتاح العام فقط.
- الصلاحيات مطبّقة في قاعدة البيانات (RLS + Triggers) وليست في الواجهة. الحذف إخفاء مسجّل، وسجل التدقيق للإلحاق فقط.
- الاعتمادات المالية للمالك فقط، ولا يعتمد أحد عملية سجّلها بنفسه، ولا تدخل الإجماليات إلا العمليات المعتمدة.
- لا تُدخل بيانات مرضى حقيقية في هذا النظام.

## النسخ الاحتياطي والاستعادة
المالك: الإعدادات ← تنزيل نسخة JSON. الخارجي: `external-backup.yml` (يلزمه SUPABASE_DB_URL وAGE_PUBLIC_KEY كأسرار GitHub). للتحقق: شغّل `scripts/restore-check.sql` على المصدر وعلى القاعدة المستعادة؛ يجب أن يتطابق الناتجان.

## قيود معروفة
- تصدير «Excel» حاليًا CSV (UTF-8) يفتحه Excel؛ تصدير xlsx يحتاج مكتبة تُضاف لاحقًا.
- استعادة JSON من داخل التطبيق غير منفّذة (الاستعادة عبر pg_restore).
- لم تُجرَّب الواجهة في متصفح مقابل قاعدة حيّة بعد؛ أول تشغيل = اختبار قبول (انظر docs/PERMISSIONS.md لقائمة الحالات).

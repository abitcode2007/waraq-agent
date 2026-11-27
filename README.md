# WARAQ — مساعد ورق

تطبيق ويب عربي لإدارة المواد والمحاضرات والامتحانات والمهام، مع مساعد ذكي يعمل بالعربية.
الواجهة ثابتة بالكامل وتُنشر على **GitHub Pages**، والبيانات تُخزّن محلياً وتُزامن مع Supabase عند تسجيل الدخول.

## البنية

```
index.html                       الواجهة كاملة (HTML + CSS + JS)
config.js                        رابط Supabase والمفتاح العام (آمن للنشر)
supabase/schema.sql              الجداول وسياسات RLS و Storage وتحديد المعدل
supabase/functions/chat/         Edge Function وكيل Gemini
.github/workflows/deploy-function.yml   نشر الدالة تلقائياً
push.ps1 / رفع التحديث.cmd       رفع التعديلات بضغطة واحدة
```

## التحديث اليومي (بدون نقل ملفات يدوياً)

1. عدّل الملفات داخل هذا المجلد.
2. انقر مرتين على `رفع التحديث.cmd`، أو نفّذ:
   ```powershell
   .\push.ps1 "وصف التعديل"
   ```
3. يرفع السكربت التغييرات إلى `main`، ويتولى GitHub Pages تحديث الموقع تلقائياً.

> إذا كنت تعدّل من نسخة أخرى من الملفات، انسخ التعديل إلى هذا المجلد أولاً — هذا المجلد هو المستودع المرتبط بالموقع المنشور.

## إعداد Supabase (مرة واحدة)

1. افتح **SQL Editor** ونفّذ محتوى `supabase/schema.sql`.
2. تأكد من إعدادات الأمان في لوحة Supabase:
   - `Confirm email` و`Secure email change` = ON
   - `Leaked password protection` و`CAPTCHA` = ON
   - مدة صلاحية JWT = 3600 ثانية
3. أضف السر `GEMINI_API_KEY` في **Project Settings → Edge Functions → Secrets**.
4. انشر الدالة:
   ```powershell
   supabase functions deploy chat
   ```
   أو اترك GitHub Action ينشرها عند تعديل مجلد `supabase/functions`.

### أسرار GitHub Actions (لنشر الدالة تلقائياً)

في **Settings → Secrets and variables → Actions** أضف:

| الاسم | القيمة |
|---|---|
| `SUPABASE_ACCESS_TOKEN` | من https://supabase.com/dashboard/account/tokens |
| `SUPABASE_PROJECT_REF` | معرّف المشروع من رابط لوحة التحكم |

⚠️ لا تضع أبداً `sb_secret_...` أو `service_role` داخل `config.js` أو أي ملف في هذا المستودع.

## المساعد الشخصي والذاكرة

- المساعد يحفظ ما تخبره به عنك في `profile.facts` عبر أداتي `remember` / `forget`، ويرسله مع كل طلب في `context.profile`.
- سياق المستخدم يُرسل إلى Gemini داخل `systemInstruction`، لذلك يعرف اسمك وتفضيلاتك وبياناتك أثناء المحادثة.
- المعلومات تُحفظ محلياً وتُزامن مع حسابك في `user_data` مثل بقية البيانات.
- لتغيير موديل Gemini أضف السر `GEMINI_MODEL` (مثلاً `gemini-2.5-flash-lite`) دون تعديل الكود.

ترتيب التبويبات: الرئيسية، الجدول، المواد، المساعد، المزيد. عند دخول أي محادثة تظهر أول رسالة فيها (لا يتم التمرير للأسفل تلقائياً).

## ملاحظات أمنية

- `config.js` يحتوي على **مفتاح عام** فقط، وهو آمن في مستودع عام.
- الحماية الفعلية تعتمد على سياسات RLS في `schema.sql` — بدونها أي مفتاح عام يكشف بيانات المستخدمين.
- الدالة `chat` تتحقق من JWT وتفرض حداً 15 طلب/دقيقة و200 طلب/يوم لكل مستخدم.
- ملفات PDF خاصة، ومجلد كل مستخدم معزول، والحد الأقصى 15MB ونوع الملف مُقيّدان على الخادم.
- أضيفت رؤوس CSP و`referrer` وSRI لسكربت Supabase في `index.html`.

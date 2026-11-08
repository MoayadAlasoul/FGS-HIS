insert into public.projects(code,name,product_budget,client1_budget,reserve_pct,extra_integration_usd,fx_rate,server_users,server_annual_cost,first_delivery_weeks,total_months) values ('FGS-HIS','FGS HIS – Project Management',95750,35000,20,1500,3.75,40,8000,6,4);

insert into public.phases(code,seq,name,week_from,week_to,owner_label,description,outputs,approval_condition) values
('PH1',1,$q$التخطيط والتحليل$q$,1,2,$q$Product Manager + Project Manager$q$,$q$اجتماع بدء؛ جمع المتطلبات؛ تحديد النطاق؛ تحليل العمليات؛ تحديد التكاملات؛ إعداد BRD وSOW$q$,$q$وثيقة المتطلبات BRD؛ نطاق المشروع SOW؛ خطة المشروع؛ سجل المخاطر$q$,$q$اعتماد النطاق والمتطلبات والأولويات من ممثل العميل والإدارة$q$),
('PH2',2,$q$تجهيز النظام والتطوير الأساسي$q$,3,6,$q$Project Manager + Technical Lead$q$,$q$تهيئة Odoo Community؛ تجهيز Backend والموديولات؛ الصلاحيات؛ المحاسبة والموارد البشرية؛ التقارير؛ بيئة الاختبار$q$,$q$نسخة أولية؛ قائمة الموديولات؛ سجل التخصيصات؛ بيئة اختبار تعمل$q$,$q$قبول الوظائف الأساسية في عرض تجريبي وتوثيق الملاحظات الحرجة (تسليم النسخة الأولية للعميل: 6 أسابيع)$q$),
('PH3',3,$q$التكاملات الخارجية$q$,7,10,$q$Technical Lead + Integration Developers$q$,$q$تحليل API؛ إعداد الاتصال؛ تطوير التكاملات؛ معالجة الأخطاء؛ سجلات التبادل؛ اختبارات الجهات$q$,$q$وثائق API؛ نتائج اختبار لكل تكامل؛ سجل أخطاء؛ إثبات تبادل البيانات$q$,$q$نجاح اختبارات التكامل المتاحة وتوثيق ما يتطلب اعتمادًا أو بيانات من طرف ثالث$q$),
('PH4',4,$q$الاختبار والقبول النهائي$q$,11,13,$q$QA Lead + Implementation Consultant$q$,$q$اختبار وظيفي؛ اختبار صلاحيات؛ اختبار أمان أساسي؛ اختبار التكامل؛ UAT؛ معالجة العيوب$q$,$q$خطة اختبار؛ حالات اختبار؛ سجل عيوب؛ محضر UAT$q$,$q$إغلاق العيوب الحرجة والعالية واعتماد UAT من العميل$q$),
('PH5',5,$q$التشغيل والتدريب والتسليم$q$,14,16,$q$Project Manager + Implementation Consultant$q$,$q$تهيئة الإنتاج؛ نقل البيانات المعتمدة؛ تدريب؛ تشغيل تجريبي؛ دعم الإطلاق؛ تسليم الوثائق$q$,$q$بيئة إنتاج؛ محاضر تدريب؛ خطة رجوع؛ محضر Go-Live؛ وثائق التسليم$q$,$q$اعتماد التشغيل والتسليم وتحديد تاريخ بدء الدعم (المشروع كاملًا: حتى 4 أشهر)$q$);

insert into public.payments(code,seq,name) values
('P1',1,$q$بدء المشروع والتجهيز$q$),
('P2',2,$q$الربط والتكامل وتجهيز التشغيل$q$),
('P3',3,$q$التخصيصات والتصميم$q$),
('P4',4,$q$التسليم النهائي$q$);

insert into public.payment_items(payment_id,seq,description,amount) values
((select id from public.payments where code='P1'),1,$q$تجهيز السيرفر التجريبي$q$,750),
((select id from public.payments where code='P1'),2,$q$شراء الموديول الأساسي للنظام$q$,5625),
((select id from public.payments where code='P1'),3,$q$شراء موديولات النظام (الموارد البشرية والمحاسبة وغيرها)$q$,2000),
((select id from public.payments where code='P1'),4,$q$إدارة المنتج بالكامل ومتابعة المتطلبات$q$,6000),
((select id from public.payments where code='P1'),5,$q$مدير المشروع والإشراف على بدء التنفيذ$q$,3000),
((select id from public.payments where code='P2'),1,$q$الربط مع الجهات الخارجية: نفيس، وصفتي، صحتي، رصد، وزاتكا$q$,26000),
((select id from public.payments where code='P2'),2,$q$السيرفر الفعلي للتشغيل لمدة سنة، بسعة تقديرية تصل إلى 40 مستخدمًا$q$,8000),
((select id from public.payments where code='P2'),3,$q$إدارة المنتج بالكامل ومتابعة المتطلبات$q$,6000),
((select id from public.payments where code='P2'),4,$q$مدير المشروع والإشراف على التنفيذ$q$,3000),
((select id from public.payments where code='P3'),1,$q$تخصيص التقارير ومخرجات الشاشات وفق متطلبات السوق السعودي$q$,3375),
((select id from public.payments where code='P3'),2,$q$تخصيص واجهات النظام بما يتناسب مع الهوية البصرية والعلامة التجارية$q$,14000),
((select id from public.payments where code='P3'),3,$q$إدارة المنتج بالكامل ومتابعة المتطلبات$q$,6000),
((select id from public.payments where code='P3'),4,$q$مدير المشروع ومتابعة التنفيذ$q$,3000),
((select id from public.payments where code='P4'),1,$q$إدارة المنتج والإشراف على التسليم النهائي$q$,6000),
((select id from public.payments where code='P4'),2,$q$مدير المشروع ومتابعة التسليم والاعتماد النهائي$q$,3000);

insert into public.client1_items(seq,description,amount) values
(1,$q$موظف تنفيذ المشروع لمدة 4 أشهر$q$,23000),
(2,$q$موظف الدعم الفني المسائي لمدة 4 أشهر$q$,12000);

insert into public.tasks(phase_id,code,seq,title,owner_label,week_from,week_to,duration_text,acceptance_note) values
((select id from public.phases where code='PH1'),'T01',1,$q$اجتماع Kick-off وتحديد أصحاب المصلحة$q$,$q$Project Manager$q$,1,1,null,$q$محضر اجتماع وأسماء المسؤولين$q$),
((select id from public.phases where code='PH1'),'T02',2,$q$جمع وتحليل متطلبات العيادات والمجمعات$q$,$q$Product Manager$q$,1,1,null,$q$قائمة متطلبات وظيفية وغير وظيفية$q$),
((select id from public.phases where code='PH1'),'T03',3,$q$تحديد الموديولات وسير العمل الطبي والإداري$q$,$q$Product Manager$q$,1,2,null,$q$خرائط العمليات وقائمة الموديولات$q$),
((select id from public.phases where code='PH1'),'T04',4,$q$تحديد نطاق التكاملات ومتطلبات الوصول وبيانات الجهات$q$,$q$Technical Lead$q$,2,2,null,$q$مصفوفة التكاملات والمسؤوليات$q$),
((select id from public.phases where code='PH1'),'T05',5,$q$إعداد واعتماد BRD وSOW والجدول الأساسي$q$,$q$Project Manager$q$,2,2,null,$q$اعتماد مكتوب من العميل$q$),
((select id from public.phases where code='PH2'),'T06',6,$q$تجهيز مستودع Git وإدارة الصلاحيات والفروع$q$,$q$Technical Lead$q$,3,3,null,$q$صلاحيات فردية ونسخ احتياطي للكود$q$),
((select id from public.phases where code='PH2'),'T07',7,$q$تجهيز بيئة التطوير والاختبار وOdoo Community$q$,$q$DevOps / Technical Lead$q$,3,3,null,$q$بيئة قابلة للدخول والتجربة$q$),
((select id from public.phases where code='PH2'),'T08',8,$q$تجهيز Backend والموديولات الطبية الأساسية$q$,$q$Odoo Developers$q$,3,5,null,$q$قائمة وظائف تم اختبارها$q$),
((select id from public.phases where code='PH2'),'T09',9,$q$تجهيز المحاسبة والموارد البشرية$q$,$q$Odoo Developer / Consultant$q$,4,5,null,$q$تجربة السيناريوهات المتفق عليها$q$),
((select id from public.phases where code='PH2'),'T10',10,$q$تخصيص التقارير والشاشات الأولية$q$,$q$Odoo Developers$q$,5,6,null,$q$اعتماد عينات التقارير$q$),
((select id from public.phases where code='PH2'),'T11',11,$q$عرض النسخة الأولية وجمع الملاحظات$q$,$q$Implementation Consultant$q$,6,6,null,$q$محضر عرض وملاحظات مصنفة$q$),
((select id from public.phases where code='PH3'),'T12',12,$q$تجهيز وثائق API وبيانات الاختبار لكل جهة$q$,$q$Integration Lead$q$,7,7,null,$q$توفر الوثائق وبيانات الوصول$q$),
((select id from public.phases where code='PH3'),'T13',13,$q$تنفيذ تكامل نفيس NPHIES$q$,$q$Integration Developers$q$,7,9,null,$q$اختبار السيناريوهات المتفق عليها؛ يتطلب جاهزية الجهة$q$),
((select id from public.phases where code='PH3'),'T14',14,$q$تنفيذ تكامل رصد RSD$q$,$q$Integration Developers$q$,7,9,null,$q$تأكيد المتطلبات الفنية والاعتماد$q$),
((select id from public.phases where code='PH3'),'T15',15,$q$تنفيذ تكامل وصفتي Wasfaty$q$,$q$Integration Developers$q$,8,10,null,$q$اختبار تبادل البيانات حسب الواجهات المتاحة$q$),
((select id from public.phases where code='PH3'),'T16',16,$q$تنفيذ تكامل ZATCA$q$,$q$Integration Developers$q$,8,10,null,$q$اختبارات الفوترة الإلكترونية المطلوبة$q$),
((select id from public.phases where code='PH3'),'T17',17,$q$توثيق نتائج الاختبارات ومعالجة أخطاء التكامل$q$,$q$QA + Integration Lead$q$,10,10,null,$q$تقارير اختبار وسجل أخطاء$q$),
((select id from public.phases where code='PH4'),'T18',18,$q$إعداد خطة الاختبار وحالات الاختبار$q$,$q$QA Lead$q$,11,11,null,$q$حالات اختبار مرتبطة بالمتطلبات$q$),
((select id from public.phases where code='PH4'),'T19',19,$q$اختبار الوظائف الطبية والإدارية والصلاحيات$q$,$q$QA + Consultant$q$,11,12,null,$q$نتائج ناجح/فاشل موثقة$q$),
((select id from public.phases where code='PH4'),'T20',20,$q$اختبار التكاملات والأمان الأساسي والأداء$q$,$q$QA + Technical Lead$q$,12,12,null,$q$إغلاق العيوب الحرجة والعالية$q$),
((select id from public.phases where code='PH4'),'T21',21,$q$تنفيذ UAT وتوقيع محضر القبول$q$,$q$Client + PM$q$,13,13,null,$q$اعتماد العميل أو قائمة استثناءات$q$),
((select id from public.phases where code='PH5'),'T22',22,$q$تجهيز سيرفر الإنتاج والنسخ الاحتياطي والمراقبة$q$,$q$DevOps$q$,14,14,null,$q$اختبار الاستعادة وخطة النسخ$q$),
((select id from public.phases where code='PH5'),'T23',23,$q$ترحيل البيانات المعتمدة والتحقق منها$q$,$q$Data Lead$q$,14,15,null,$q$مطابقة عينات البيانات واعتمادها$q$),
((select id from public.phases where code='PH5'),'T24',24,$q$تدريب المستخدمين وتسليم أدلة الاستخدام$q$,$q$Implementation Consultant$q$,15,15,null,$q$سجل حضور ومواد تدريب$q$),
((select id from public.phases where code='PH5'),'T25',25,$q$التشغيل التجريبي ومعالجة ملاحظات الإطلاق$q$,$q$PM + Support$q$,15,16,null,$q$قائمة متابعة يومية للملاحظات$q$),
((select id from public.phases where code='PH5'),'T26',26,$q$Go-Live ومحضر التسليم وبدء الدعم$q$,$q$Project Manager$q$,16,16,null,$q$توقيع محضر التسليم وتاريخ بدء الدعم$q$),
((select id from public.phases where code='PH3'),'T27',27,$q$تنفيذ تكامل صحتي Sehhaty$q$,$q$Integration Developers$q$,null,null,$q$7–10$q$,$q$يعتمد التنفيذ على توفر API والموافقات الفنية؛ المدة قابلة للتعديل من الإدارة ولا يوجد تاريخ مثبّت$q$);

insert into public.issues(code,kind,title,details,status,resolution_note) values
('C1','conflict',$q$ملخص «لوحة التحكم» في Excel لا يطابق ورقة «الميزانية»$q$,$q$لوحة التحكم: دون الثيم 110,750 / الثيم 8,000 / الشامل 118,750 / احتياطي 10% = 11,075 و15% = 16,612.5. ورقة الميزانية: دون الثيم 116,750 / الثيم 14,000 / الشامل 130,750 / احتياطي 20% = 23,350. ورقة الميزانية تطابق مستند الدفعات، ولم أعتمد أرقام لوحة التحكم.$q$,'resolved',$q$قرار الإدارة: تُعتمد ورقة الميزانية ومستند الدفعات (95,750)، وملخص لوحة التحكم القديم في Excel غير معتمد.$q$),
('C2','conflict',$q$الثيم/تخصيص الواجهات (14,000): اختياري في Excel، ومضمّن في الدفعة الثالثة$q$,$q$Excel يشترط موافقة مستقلة قبل اعتماده، بينما مستند الدفعات يدخله ضمن 95,750. المطلوب قرار: هل 95,750 تشمله فعليًا؟ (الأرقام هنا كما في طلبك: يشمله).$q$,'resolved',$q$قرار الإدارة: الثيم (14,000) مشمول ضمن الميزانية الإجمالية 95,750 وفق مستند الدفعات، وليس بندًا اختياريًا خارجها.$q$),
('C3','conflict',$q$أساس الاحتياطي 20%$q$,$q$19,150 = 20% من 95,750 (حسب طلبك ومستند الدفعات). Excel يحسبه 23,350 على 116,750 الذي يشمل تكلفة العميل الأول. لم يُحتسب أي احتياطي ضمن المصروفات.$q$,'resolved',$q$قرار الإدارة: الاحتياطي 19,150 محسوب على 95,750، ولا يُستخدم مبلغ 23,350.$q$),
('C4','conflict',$q$إعادة توزيع 625 ريال بين بندين$q$,$q$بند «إدارة المشروع والتطوير + الموديول»: 17,000 في Excel مقابل 17,625 في الدفعات (3,000×4 + 5,625). بند «التخصيصات والتقارير»: 4,000 مقابل 3,375. الإجمالي متطابق.$q$,'resolved',$q$قرار الإدارة: يُعتمد توزيع مستند الدفعات: الإدارة والتطوير 17,625 والتخصيصات 3,375.$q$),
('C5','conflict',$q$تكامل «صحتي» بلا مهمة$q$,$q$مذكور ضمن بند الربط (26,000) ومستند الدفعات، لكن ورقة المهام تتضمن 4 تكاملات فقط (نفيس، رصد، وصفتي، ZATCA). لم أضف مهمة من عندي.$q$,'resolved',$q$قرار الإدارة: مهمة مستقلة لتكامل صحتي، مدتها 7–10 أيام قابلة للتعديل دون تاريخ مثبّت؛ التنفيذ يعتمد على توفر API والموافقات الفنية.$q$),
('C6','conflict',$q$ربط الدفعات بالمراحل غير محدد$q$,$q$لا يوجد ربط صريح بين الدفعات الأربع ومراحل Excel الخمس. ترتيب الدفعات (الربط ثم التخصيصات) يخالف الجدول الزمني (التخصيصات أسبق من التكاملات). ولا توجد تكلفة صريحة لمرحلة الاختبار. لذلك التكلفة المعتمدة لكل مرحلة تُدخل بقرارك (غير موزعة حاليًا).$q$,'resolved',$q$قرار الإدارة (نهائي): مستند الدفعات هو المرجع المالي؛ المراحل المالية هي الدفعات الأربع بإجمالي 95,750 دون مبلغ غير موزّع، ولا يُعاد توزيع إدارة المنتج ومدير المشروع على المراحل التقنية. تكلفة المرحلة التقنية اختيارية.$q$),
('C7','conflict',$q$تكلفة العميل الأول (35,000) بلا جدول دفعات$q$,$q$تنفيذ 23,000 + دعم 12,000، منفصلة عن 95,750، ولا يوجد جدول استحقاق لها. تُسجَّل مصروفاتها بنطاق «العميل الأول».$q$,'resolved',$q$قرار الإدارة: تكلفة العميل الأول (35,000) مستقلة تمامًا؛ تُسجَّل دفعاتها يدويًا دون جدول استحقاق افتراضي.$q$),
('C8','conflict',$q$بنود غير مشمولة$q$,$q$ضريبة القيمة المضافة غير مشمولة. الربط الإضافي بعد استهلاك الاحتياطي: من 1,500 دولار لكل عملية (≈ 5,625 ر.س بسعر 3.75). سعة السيرفر 40 مستخدمًا مذكورة في مستند الدفعات فقط.$q$,'resolved',$q$قرار الإدارة: جميع المبالغ تعرض بدون ضريبة القيمة المضافة ولا تُحتسب ضمن التكاليف. الربط الإضافي يبدأ من 1,500 دولار للعملية بعد استهلاك الاحتياطي ويحتاج موافقة المستثمر مسبقًا؛ السيرفر 40 مستخدمًا وتكلفته السنوية 8,000 كبند مستقل.$q$),
('R1','risk',$q$عدم وضوح شمول تكلفة المطورين ضمن بند 17,000$q$,$q$ارتفاع التكلفة الفعلية عن الميزانية — متوسط/عالٍ | المعالجة: تأكيد كتابي: عدد المطورين ومددهم ورواتبهم وهل هي ضمن البند أم تكلفة إضافية (الإدارة + PM)$q$,'open',$q$$q$),
('R2','risk',$q$عدم توفر موافقات أو بيانات API من الجهات الصحية$q$,$q$تأخر التكاملات والجدول الزمني — عالٍ/عالٍ | المعالجة: تحديد متطلبات كل جهة ومسؤول توفير الحسابات والبيئة التجريبية (Integration Lead)$q$,'open',$q$$q$),
('R3','risk',$q$عدم تحديد تفاصيل نطاق كل تكامل ضمن 26,000$q$,$q$طلبات تغيير وتكاليف إضافية — متوسط/عالٍ | المعالجة: وثيقة مستقلة لكل تكامل تشمل السيناريوهات والاستثناءات والاختبار (Technical Lead)$q$,'open',$q$$q$),
('R4','risk',$q$تأخر العميل في اعتماد المتطلبات أو UAT$q$,$q$تأخير التسليم — متوسط/متوسط | المعالجة: تحديد مدة مراجعة واعتماد متفق عليها وآلية تصعيد (Project Manager)$q$,'open',$q$$q$),
('R5','risk',$q$عدم وضوح مواصفات السيرفر والحماية والنسخ الاحتياطي$q$,$q$ضعف الأداء أو فقد البيانات — متوسط/عالٍ | المعالجة: اعتماد مواصفات السعة والأمان والنسخ وخطة الاستعادة قبل الإنتاج (DevOps)$q$,'open',$q$$q$),
('R6','risk',$q$زيادة نطاق العمل بعد اعتماد BRD$q$,$q$زيادة الوقت والتكلفة — عالٍ/عالٍ | المعالجة: اعتماد آلية Change Request بموافقة مكتوبة (Product Manager)$q$,'open',$q$$q$),
('R7','risk',$q$رسوم الجهات أو الموديلات الجاهزة غير مدرجة$q$,$q$تكاليف إضافية — متوسط/متوسط | المعالجة: التحقق من التراخيص والاشتراكات ورسوم الجهات قبل الشراء (Procurement / PM)$q$,'open',$q$$q$),
('R8','risk',$q$اعتماد الثيم الاختياري دون حاجة مؤكدة$q$,$q$زيادة الميزانية 14,000 ريال — منخفض/منخفض | المعالجة: تأجيل قرار الثيم حتى مراجعة النسخة الأولية (الإدارة)$q$,'open',$q$$q$);

create table public.budget_reference (seq int primary key, description text not null, excel_amount numeric(14,2) not null, payment_doc_amount numeric(14,2));
alter table public.budget_reference enable row level security;
create policy bref_select on public.budget_reference for select to authenticated using ((select app_private.is_mgmt()));
create policy bref_write on public.budget_reference for all to authenticated using ((select app_private.is_owner())) with check ((select app_private.is_owner()));
revoke all on public.budget_reference from anon; revoke delete, truncate on public.budget_reference from authenticated;
create trigger z_audit after insert or update or delete on public.budget_reference for each row execute function app_private.audit_row();
insert into public.budget_reference values
(1,$q$إدارة المنتج$q$,24000,24000),
(2,$q$إدارة المشروع والتطوير والـ Backend + سعر الموديول$q$,17000,17625),
(3,$q$التخصيصات الأولية والتقارير ومخرجات الشاشات$q$,4000,3375),
(4,$q$موديول المحاسبة والموارد البشرية$q$,2000,2000),
(5,$q$الربط والتكامل$q$,26000,26000),
(6,$q$السيرفر التجريبي$q$,750,750),
(7,$q$سيرفر التشغيل الفعلي$q$,8000,8000),
(8,$q$تخصيص الواجهات والثيم$q$,14000,14000),
(9,$q$موظف التنفيذ 4 أشهر$q$,23000,null),
(10,$q$موظف الدعم المسائي 4 أشهر$q$,12000,null);
# 終結技連續動作設計：Batch B

本文件把 Combo 名稱、既有 icon 的主輪廓與資料描述，轉成可按時間軸製作的戰鬥演出。時間以效果啟動後的秒數計；所有幾何必須逐步變成有功能語意的物體，不能只停留在抽象光紋。

## 1. returning_counterguard／返照歸身

1. **意境核心**：以「石像記住打擊，再把同一股力量逐筆退回」表達反擊。主體不是一般護盾，而是一面中線剖開、內藏三層活動石板的守衛碑；每層石板對應一段被記錄的來襲招式。
2. **開場環境反應（0.00–0.22 秒）**：場地亮度先降一級，受術者腳下碎石違反重力上浮 10–20 公分；敵方攻擊方向的地面粉塵被吸向受術者，而不是向外吹散。0.14 秒時，受術者前方留下三道由近到遠的扁平壓痕，表示衝擊正在被壓入空間。
3. **幾何組成（0.08–0.42 秒）**：兩條象牙白折線由腳邊向上擠出，先形成左右承重脊；六塊不等邊梯形石片沿脊線卡榫拼合，最後由一條細金縫把左右半部鎖成直立守衛碑。碑內三片楔形金屬石板依序向後滑開，清楚形成可活動的「反擊匣」，不能排成圓環或刻度盤。
4. **主物體、連續動作與景深（0.28–1.08 秒）**：鏡頭平面固定在受術者前方 3/4 視角。前景是擦過鏡頭下緣的吸入碎石；中景守衛碑先前傾 8 度承受打擊，再被壓回直立；後景三片楔板依收到的衝擊先後，各向攻擊來源轉 12–20 度。0.70 秒起，楔板由後向前逐片彈出，沿原攻擊向量逆向飛行，形成三個有厚度、有陰影間隔的重擊殘像。
5. **命中變形／破壞（0.82–1.26 秒）**：每片楔板命中時不是消失，而是前端壓扁、龜裂並崩成拳頭大小的石塊；崩裂中心把吸收時保留的琥珀衝擊壓成扇形波向敵側推走。第三次命中後，守衛碑中線金縫由上向下熄滅，左右半碑向內合攏，證明記錄已釋放完畢。
6. **餘韻（1.20–1.75 秒）**：敵人腳邊留下三條平行石屑溝與仍發熱的金屬薄片；受術者前方只剩一小段直立石樁，兩秒內風化成粗砂。具體殘留物是石灰粉、灰褐石塊與冷卻後的暗金碎片。
7. **主光／材質／色彩轉換**：開場以冷灰石材和低飽和象牙白為主；吸收瞬間從攻擊側灌入琥珀光，沿裂縫走到三片楔板；返還時楔板前端由暗金升到白金，命中破碎後迅速退成焦褐。石材表面需有粗粒、缺角與鑿痕，不能像平滑塑膠或純發光線。
8. **粒子物理來源**：向內粉塵來自地面被負壓抽起；細碎石屑來自碑面承受衝擊後的剝落；金色火星來自楔板卡榫高速摩擦；扇形亮屑來自楔板前端壓碎時暴露的灼熱金屬層。四類粒子方向、速度與產生時點不得混用。
9. **禁止元素**：禁止通用魔法圓、同心環、鐘面刻度、無來源漂浮符文、對稱羽翼、盾牌 icon 放大、石像人臉、文字與傷害數字；禁止把三次返還畫成沒有厚度的三條光線。
10. **Impact material prompt**：`Square additive-blend combat impact material on perfectly pure black: a monumental cleft ivory stone guardian slab absorbs an amber strike into its cracked left face while three thick gilded stone counter-wedges physically spring outward in sequence, crushing and shedding heavy rubble, hot metal seams, directional dust and cinematic white-gold rim light; one readable defensive-return silhouette, deep 2.5D layers, generous black padding, no character, text, UI, border, circles, runes or generic magic diagram.`

## 2. inferno_cremation／流火照夜

1. **意境核心**：把既有燃燒層數具象成一條會追獵倒下目標的熔火河；河流不是背景裝飾，而會轉彎、聚流、爬升成焚化刃，並在擊倒點把儲存熱量炸回場上。
2. **開場環境反應（0.00–0.20 秒）**：所有燃燒目標腳下先滲出暗紅熔珠，附近陰影向火源反方向拉長；地表沿目標之間出現乾裂，不直接發光。0.12 秒後裂縫才從最深處亮橙，熱浪使後景水平抖動，空氣中的灰燼向最低血量目標偏流。
3. **幾何組成（0.08–0.38 秒）**：每層燃燒生成一枚有厚度的橢圓熔火團，熔火團沿地裂互相拉成寬窄不均的液態帶；三條帶先合成 S 形主河道，再由河心拉出一片狹長、前尖後寬的白熱刃脊。任何幾何都必須被熔液覆蓋，不可留下抽象線框。
4. **主物體、連續動作與景深（0.30–1.06 秒）**：鏡頭略低，平面方向由左前景流向右後景。前景熔流先擦過畫面下緣，液面結痂被速度撕開；中景主河道蛇行繞過第一個敵人，於 0.62 秒突然收窄並向上抽升；後景白熱刃脊追向下一名燃燒目標，像被河流推送的直立火刃。河道轉彎應有外側堆高、內側露出黑紅結痂的流體慣性。
5. **命中變形／破壞（0.72–1.28 秒）**：火刃命中時先彎曲包覆目標輪廓，再從下向上塌成焚化柱；若目標倒下，柱體中央形成壓縮白核，0.10 秒後炸成貼地的熔火扇，扇面把附近燃燒層引燃。爆發物質包含液態火、半固態火山渣與煙，不能只是一張放射光片。
6. **餘韻（1.18–1.85 秒）**：地面留下 S 形黑曜結痂河床，裂縫內還有緩慢流動的橙紅熔線；擊倒點殘留幾塊外黑內紅的火山渣，偶爾塌落並吐出短煙。灰燼最後沿原河道方向落下，顯示熱流已移動而非原地爆炸。
7. **主光／材質／色彩轉換**：開場暗酒紅，河心升至橙金，火刃核心在命中前 3 幀轉成近白黃；擊倒爆發後亮部降回深橙，外殼迅速轉黑。材質必須同時呈現透明薄焰、黏稠熔液與多孔火山渣三種狀態，亮度最高處位於液體最薄或壓力最高位置。
8. **粒子物理來源**：長尾火星由熔流高速刮過地面產生；片狀灰燼是地面植被與既有灼燒物剝落；旋轉火山渣由擊倒爆心拋出，遵守拋物線；黑煙由熔液包住冷表面時的不完全燃燒產生；熱扭曲僅貼著白熱河心向上。
9. **禁止元素**：禁止普通火球、完整火焰劍 icon、均勻圓形爆炸、火焰魔法陣、無來源火星雨、龍或鳳凰剪影、純紅色濾鏡、文字與火焰符號；禁止把所有火材質做成相同透明筆刷。
10. **Impact material prompt**：`Square additive-blend JRPG combat impact material on uniform pure black: a broad S-shaped river of viscous molten fire sweeps diagonally, its cracked obsidian crust peeling open as the white-hot current rises into one towering blade-shaped cremation flare and collapses into a grounded fan of lava, ember chunks and dark combustion smoke; concrete fluid inertia, orange-gold-white core, deep red shadows, cinematic HD-2D depth, generous black padding, no character, UI, text, circle, rune or magic diagram.`

## 3. frozen_burial／履霜凝華

1. **意境核心**：霜緩不是單純凍結，而是先用薄霜量測目標輪廓，再把輪廓長成有重量的冰棺；重擊沿棺材晶格傳遞，使附近冰棺依相同裂紋順序連鎖崩碎。
2. **開場環境反應（0.00–0.24 秒）**：敵人呼氣先凝成短白霧，腳下水分沿移動方向逆爬成霜；環境聲光在 0.12 秒短暫變鈍，地面細砂被冰黏住而停止滾動。受霜緩越重，鞋底向外長出的六角霜片越厚，但不形成完整圓。
3. **幾何組成（0.10–0.46 秒）**：兩片透明梯形冰板從腳邊斜插上升，先夾住側面；四片不規則五邊板沿肩高接合，最後一塊尖頂晶體自上方落下封口，構成可辨識的直立冰棺。冰內一條深藍細柱沿身形凝成「封存脊」，負責把後續重擊導向棺體裂紋。
4. **主物體、連續動作與景深（0.36–1.10 秒）**：鏡頭平面先在中景正側面看冰板合攏，0.58 秒輕微推近並下降，讓棺體顯得壓地。前景有低矮霜脊向鄰近目標爬行；中景主冰棺內部氣泡停止上升；後景沿霜脊依序抽出較小冰棺。重擊到達前，主棺向內收縮 3%，顯示壓力累積。
5. **命中變形／破壞（0.78–1.34 秒）**：重擊先在命中面壓出白色凹點，裂紋不是放射圓，而沿晶格折成三段鋸齒，穿過封存脊後由底部反折回頂部。0.08 秒後棺體分成六到九塊厚冰板向外翻倒；裂紋光沿地面霜脊抵達下一棺，再重演「凹點—折裂—翻倒」。碎塊需旋轉顯示厚度與內部折射。
6. **餘韻（1.28–1.95 秒）**：命中地點留下半透明厚冰板、細密雪粉和一條仍嵌在地面的深藍封存脊；大塊冰先從邊緣霧化，中心則滴出少量冷水。連鎖路徑留有鋸齒狀白霜凹槽，便於觀眾讀懂傳遞順序。
7. **主光／材質／色彩轉換**：結霜初期是低亮青灰；冰板完成時邊緣轉白藍、內部維持深鈷藍；受擊凹點瞬間出現近白冷光，裂紋走過後則退成灰藍。材質包含清澈冰面、被困氣泡、霧化內層與銳利斷面，不能全部高曝光成白色。
8. **粒子物理來源**：薄雪粉由冰板封合時擠出的空氣刮落；針狀冰屑來自裂紋高速穿過晶格；大板碎片來自棺體面板翻倒；短白霧是較暖空氣碰到新斷面的凝結；地面水珠是餘熱融化最薄碎冰。
9. **禁止元素**：禁止雪花圖標、完整六芒幾何、冰系魔法陣、隨機水晶王冠、均勻放射冰刺、角色臉孔被清楚封入畫面、文字、符文或沒有厚度的藍色碎線；禁止把冰棺做成裝飾寶石盒。
10. **Impact material prompt**：`Square additive-blend combat impact material on perfectly pure black: one heavy translucent faceted ice coffin-monolith containing a dark frozen spine is struck into a white pressure dent, jagged lattice fractures race down and rebound upward, then six thick crystal plates hinge outward into a chain-breaking field of cobalt shards, condensed frost and hard blue-white caustics; readable physical ice mass, 2.5D cinematic depth, generous black padding, no character, text, UI, circle, snowflake icon, rune or magic diagram.`

## 4. thunder_prison_pierce／雷動春醒

1. **意境核心**：先用多根雷柱建立能反覆跳躍的「導電牢籠」，每次跳雷都在柱面削出一條導流槽；所有導流槽最後對準中央，壓成一柄具有重量感的雷槍貫穿敵陣。
2. **開場環境反應（0.00–0.20 秒）**：地面鬆散金屬與水珠先向上顫動，毛髮和布邊朝不同雷柱方向豎起；環境光以兩次短促青光閃爍，第二次比第一次延遲 0.06 秒。敵人腳邊出現不規則焦點，焦點之間沒有圓形連線。
3. **幾何組成（0.08–0.40 秒）**：四到五枚黑藍楔形基座由地面翻起，每枚基座抽出一根粗厚、斷面不規則的等離子柱；柱體由內層白核、青色導電殼、外層紫藍電暈三層組成。每次跳雷都在柱面切出一條斜槽；槽線逐步朝中央交會，形成一個狹長金色槍尖胚，而不是完整圓環。
4. **主物體、連續動作與景深（0.32–1.12 秒）**：鏡頭平面以低角度斜看敵陣。前景最近雷柱先被一道弧電擊中並向後彎；中景兩柱接力，把弧電沿敵人排列左右折返；後景最遠柱收到最後一跳後向中央放電。0.78 秒起，所有柱體被抽細，電漿像熔金屬流入中央槍胚；雷槍由畫面上後方向下前方加速，穿過柱間空隙而非從正中央靜止落雷。
5. **命中變形／破壞（0.88–1.36 秒）**：槍尖先壓出一個窄長白色切口，槍身隨後像伸縮桿般節節擠入；命中平面被向兩側劈開成 V 形電漿裂谷。雷柱在槍尾通過後自上而下崩塌，碎成帶金邊的玻璃狀導電殼；剩餘跳雷沿碎片再彈兩次才接地熄滅。
6. **餘韻（1.28–1.90 秒）**：地面留下狹長燒蝕溝、四到五塊冒煙的黑藍基座，以及表面仍偶爾爬過青弧的透明殼片。空氣殘留細長臭氧霧柱，方向與雷槍軌跡一致；不能留下永續旋轉電環。
7. **主光／材質／色彩轉換**：開場柱體以冷青白為主、陰影帶深紫；跳雷切槽時槽內短暫金黃；聚槍階段青光被抽走，中央槍芯由金轉白；命中後亮部驟降，殘骸只保留低亮藍弧。電漿需要厚實過曝核心、半透明外殼與被照亮的煙，不可只用細線閃電。
8. **粒子物理來源**：細青電枝由柱面電位差放出；金色液滴由槍胚高溫導體甩出；黑色碎片是基座受熱剝落；透明殼片來自柱外導電層崩解；紫藍煙是地表有機物與濕氣被瞬間電離。每類粒子必須沿局部電場或重力運動。
9. **禁止元素**：禁止雷電魔法圓、規則圓柱柵欄、鐘面刻度、八方向對稱雷線、雷神角色或武器持有者、文字、數字、假符文；禁止用一根普通閃電取代雷柱蓄積與中央雷槍。
10. **Impact material prompt**：`Square additive-blend combat impact material on uniform pure black: five broken thick plasma pillars at staggered depth form an open lightning prison, irregular cyan arcs carve conductive grooves between them while their white cores collapse into one gold-cyan condensed spear driving diagonally down through a narrow impact cut, shedding glassy charged shell fragments, violet ion vapor and grounded electric branches; strong physical energy mass, cinematic 2.5D lighting, generous black padding, no character, UI, text, circle, radial grid, rune or magic diagram.`

## 5. orchid_corrosion／蘭芷成蝕

1. **意境核心**：把目標體內尚未結算的毒傷抽成腐蝕性汁液，養成一朵具有肉質厚度的毒蘭；花瓣不是裝飾，會依剩餘毒量鼓脹、破裂，把霧與藥性分送給敵我兩側。
2. **開場環境反應（0.00–0.24 秒）**：中毒敵人的傷口與地面毒斑先向內收縮，像液體被虹吸；附近草葉從尖端向根部轉深綠，水珠表面生出油膜色。0.15 秒時，敵人陰影內出現一次紫綠脈動，周圍空氣下沉，低處先積一層薄霧。
3. **幾何組成（0.10–0.48 秒）**：三到五股黏稠毒液從敵人體表與毒斑抽出，沿螺旋但不閉合的路徑擰成一根半透明花梗；五片不等大的舟形肉質片依序翻開，形成可辨識蘭花。花心由多枚液滴壓成一個垂墜囊，囊表有縱向脈絡，代表尚未結算的毒傷量；根部同時長出兩片朝友方彎曲的淡金綠萼片。
4. **主物體、連續動作與景深（0.38–1.12 秒）**：鏡頭平面略俯視。前景低霧沿地面避開友方腳下；中景毒蘭先面向中毒敵人收合一次，吸走毒液後花囊下墜、花梗彎曲；後景兩片萼片朝隊友方向抬起。0.78 秒花梗反彈，整朵花像濕鞭般向上甩，花瓣由內向外依序翻面，深紫敵向表面與金綠友向背面清楚區分。
5. **命中變形／破壞（0.84–1.34 秒）**：花囊先從縱脈裂成三瓣，噴出向敵方貼地滾動的濃重毒霧；厚花瓣隨壓力由邊緣撕開，甩出具重量的酸液滴。若敵人倒下，花梗根部爆裂，霧浪再推遠一段；兩片金綠萼片則不破裂，而被反作用力壓成薄膜，向友方彈出數滴清亮藥露表示治療。
6. **餘韻（1.26–1.95 秒）**：敵方地面留下起泡的深綠腐蝕液、塌軟的紫色瓣肉與冒白煙的小凹坑；友方側只留下透明金綠露珠，落地後被吸收，不形成毒漬。花梗逐節失水變黑，最後倒向敵側。
7. **主光／材質／色彩轉換**：抽毒階段以暗紫、墨綠與低亮濕反光為主；花囊充滿時內部升起酸性黃綠；裂開瞬間敵向花瓣亮紫轉黑綠，友向萼片從青綠轉暖金。材質需呈現厚瓣蠟質、黏液拉絲、半透明酸霧與清澈藥露四種差異。
8. **粒子物理來源**：紫黑液絲來自既有毒傷被抽出；大酸滴來自花瓣撕裂，受重力下墜並在落地濺開；低霧來自花囊內高濃度腐蝕液減壓汽化；白煙來自酸滴接觸地表；金綠露珠來自萼片過濾後的液體，方向只朝友方。
9. **禁止元素**：禁止可愛花朵 icon、整齊花環、毒系魔法圓、骷髏符號、無來源泡泡、隨機螢光蝴蝶、角色人臉、文字或藥水瓶；禁止讓治療和毒霧使用同一顏色與同一擴散方向。
10. **Impact material prompt**：`Square additive-blend combat impact material on perfectly pure black: one heavy waxy orchid grown from braided viscous poison, its swollen emerald-violet central sac splits along three veins and rolls dense corrosive fog and acid droplets toward one side while two intact warm gold-green sepals flick clean healing dew in the opposite direction; torn fleshy petals, bubbling residue, wet cinematic highlights, readable asymmetric function, generous black padding, no character, UI, text, circle, skull, rune or magic diagram.`

## 6. sunbearing_dawn／朝光載陽

1. **意境核心**：一束黎明光依序尋找生命最低者，先填滿傷口，再把無處容納的光壓成具厚度的護盾葉殼；最後在殼內留下一顆可重新發芽的復起種核。
2. **開場環境反應（0.00–0.22 秒）**：戰場陰影先向東側縮短，金色晨塵只在最低生命隊友附近上升；地面冷色逐格回暖，但不整屏泛白。0.12 秒後，四名隊員腳下各出現一枚細小葉尖，其中最低生命者的葉尖最先抬頭。
3. **幾何組成（0.08–0.46 秒）**：三片狹長金色梯形光板在畫面上方錯位拼成一束有截面的晨光柱；光柱底端折成柔和弧面，像可移動的聚光葉。受療者胸前由兩片半透明綠金葉片合出杯狀容器；當生命填滿，杯沿多出的光被六片較硬的盾葉逐片接住，交疊成卵形護殼，殼底保留一顆白金種核。
4. **主物體、連續動作與景深（0.34–1.18 秒）**：鏡頭平面保持隊伍側前方。後景晨光束先落到最低生命目標；中景光束沿隊伍間一條折線滑向下一人，每次移動都先收窄再重新張開，避免瞬移；前景治療完成者的盾葉由下而上疊合。0.90 秒光束最後回到第一人，白金種核在護殼內下沉至心口高度，留下復起力量。
5. **命中／變形（0.56–1.34 秒）**：治療接觸傷口時，光柱底端被傷口輪廓切出缺口，缺口隨生命恢復逐漸補平；溢補開始後，過量光撞上杯沿，像熔玻璃般攤成盾葉。若觸發復起，卵形護殼被外力壓裂但不爆炸，種核從裂口抽出一根短芽，兩片新葉把角色輪廓托回直立。
6. **餘韻（1.22–1.90 秒）**：每個受療者腳邊留下兩三片薄金葉影，隨呼吸明滅一次後融入地面；有復起保留者胸前留下實體感較強的白金種核與一條短綠芽。空氣只殘留向上緩落的暖塵，不留下太陽徽章。
7. **主光／材質／色彩轉換**：主光從淡蜜金晨光開始，治療接觸點升到乳白；光被轉成盾時由流動白金變成半透明祖母綠邊、金色葉脈；種核平時白金，復起時中心轉嫩綠。材質需區分柔軟光柱、熔玻璃狀溢補與有韌性的葉殼。
8. **粒子物理來源**：暖金塵是地面被晨光加熱後揚起的細塵；乳白微滴是傷口被填平時排出的過剩光液；綠金薄片來自盾葉邊緣受撞擊剝落；復起時的小露珠來自種核破殼凝結，沿新芽滑落。
9. **禁止元素**：禁止完整太陽圓盤、放射刻度、天使翅膀、十字架、復活文字、生命條、治療加號、通用治療魔法圓、無來源星星；禁止全隊同時被同一個均勻光罩包覆，必須讀出依序治療與溢補轉盾。
10. **Impact material prompt**：`Square additive-blend healing impact material on uniform pure black: three offset slabs of warm dawn light descend into a translucent leaf-shaped cup, overflow pours like molten white-gold glass into six overlapping emerald-edged shield leaves around a small luminous seed core, with a short fresh sprout emerging through one pressure crack; concrete sequential-heal and overflow-shield materials, cinematic volumetric depth, honey-gold to green-white transition, generous black padding, no character, UI, text, sun disk, cross, wings, circle, rune or magic diagram.`

## 7. returning_spring_spirits／春靈來復

1. **意境核心**：復甦之靈不是人形幽魂，而是由水氣、嫩葉與種子纖維組成的三股季節流；它們沿隊伍巡行，逐一帶走污物，完成一圈後在最後一站長成春芽並把治療花潮反送全隊。
2. **開場環境反應（0.00–0.25 秒）**：乾裂地面先從裂縫滲出一線清水，低垂葉片恢復張力；隊員身上的煙塵、毒灰或負面色斑被微風推向腳邊。0.16 秒時三粒種子纖維從水線浮起，各拖著不同長度的翠綠水尾。
3. **幾何組成（0.12–0.48 秒）**：每粒種子先展開一片半透明舟形葉，葉脊成為流線骨架；清水沿骨架包覆成頭寬尾細的「春靈」，沒有臉、手腳或文字。三股春靈一大兩小，尾部混入嫩藤纖維；完成第一次淨化後，被帶走的污物壓成尾端一粒深色泥珠，讓淨化功能可見。
4. **主物體、連續動作與景深（0.36–1.28 秒）**：鏡頭平面以隊伍排列方向橫移。前景小春靈先貼地滑過第一名隊員腳邊，尾流把污物捲成泥珠；中景主春靈沿身體外側向上螺旋一次，從肩後躍向下一人；後景第三股提前抵達下一站，壓低葉身等待接力。每站停 0.12 秒完成治療，尾流由混濁轉清；最後三股在隊伍末端首尾相接，但只形成不閉合的芽莖曲線。
5. **命中／變形（0.90–1.48 秒）**：到達最後一站時，三顆泥珠被甩入地面，春靈葉身疊成一個飽滿花苞；花苞由底部吸水膨脹，五片厚水葉依序向外掀開，形成一波貼地花潮逆著巡行路徑返回。花潮碰到隊員時被腿部輪廓分流，分出的水膜爬到傷口後被吸收，而不是穿模穿過。
6. **餘韻（1.40–2.05 秒）**：最後一站留下三株具體嫩芽，根部壓著失去顏色的泥珠；巡行路徑上散落清水滴與兩三片嫩葉，水滴逐一滲入地面。受淨化者身上的污物碎屑變成灰白薄殼，落地後裂成粉末。
7. **主光／材質／色彩轉換**：初始水線冷青，春靈成形後葉脊為嫩綠、腹部為乳白水光；吸收污物時尾端轉灰紫，完成淨化即恢復透明；最終花潮由翠綠底色過渡到暖白核心。材質需同時有水的折射、嫩葉的筋脈和纖維種子的霧面質感。
8. **粒子物理來源**：清水滴由春靈急轉時的尾流甩出；嫩葉屑來自葉身摩擦污物後換下的外膜；深色泥粒來自負面狀態被壓縮；白色霧絲來自花苞展開時水面蒸發；任何粒子都應跟著巡行路徑或重力，不可全場均勻漂浮。
9. **禁止元素**：禁止人形小精靈、翅膀、卡通臉、蝴蝶群、生命加號、閉合綠色魔法環、花瓣無來源滿屏飄散、文字與符文；禁止把巡行簡化為同一個綠色光球依序閃現。
10. **Impact material prompt**：`Square additive-blend healing impact material on perfectly pure black: three faceless spring spirits built from translucent water bodies, veined jade leaves and trailing seed fibers converge into one swollen bud, expel dark purified mud beads downward, then unfold five thick water-leaves into a grounded warm-white healing flower wave flowing back along their path; readable fluid bodies, physical cleansing residue, cinematic 2.5D depth, generous black padding, no humanoid fairy, wings, butterfly, text, UI, circle, rune or magic diagram.`

## 8. shared_bloodline／同枝共脈

1. **意境核心**：全隊生命被一株共同根系接通：攻擊汲取的生命像血液在實體脈管中流回每個分枝；致命傷發生時，最粗的母枝會壓扁、破裂，替目標承擔一次衝擊。
2. **開場環境反應（0.00–0.22 秒）**：隊員腳下陰影先向彼此伸出不規則根尖，心跳節奏以地面兩次低亮紅脈衝呈現；受傷越重者附近脈衝越慢。敵人受到攻擊時，少量深紅液滴不是飛向施術者，而是被地面根尖接住。
3. **幾何組成（0.10–0.50 秒）**：四到六條帶纖維壁的粗根從隊伍位置沿地表長出，在中間交織成一段主幹；主幹剖面可見三條半透明液管，分別把液體導向不同隊員。根與人相接處長出叉形紅晶接頭，接頭像植物節點而非 UI 圓點；上方兩條母枝彎成不閉合的護蓋輪廓。
4. **主物體、連續動作與景深（0.38–1.22 秒）**：鏡頭平面低俯視，讓根系方向可讀。前景一滴吸血液落入根尖，沿內管形成可追蹤的亮紅液柱；中景液柱到主幹後分成數股，較低生命分枝取得較寬流量；後景母枝隨每次吸血收縮一次，把液體像幫浦推走。當某人遭致命攻擊，該人的分枝瞬間抽緊，母枝從畫面中央橫向壓到其前方。
5. **命中變形／破壞（0.82–1.40 秒）**：致命衝擊先把母枝壓成扁帶，外皮沿纖維方向裂開，內部血色液體被擠回其他分枝；母枝接著折斷三分之一，斷面長出多股拉絲狀纖維，將目標從倒下姿態拉回。被承擔的傷害沿主幹化成一段焦黑壞死區，而不是在所有人身上同時爆炸。
6. **餘韻（1.32–2.00 秒）**：地面保留一段暗紅根網、焦黑主幹與仍慢速脈動的透明液管；折斷母枝垂在致命目標前方，末端滴下兩三滴已變暗的血液，隨後木質化。共享吸血結束時，根尖依隊員順序縮回，留下叉形淺溝。
7. **主光／材質／色彩轉換**：外皮以暗赤木質和黑紫陰影為主，內管液體是飽和猩紅；吸血液流過時局部升到白紅高光；承擔致命傷後母枝高光熄滅、轉焦褐，受救分枝則短暫轉暖金紅。材質必須區分粗糙樹皮、濕潤血液、韌性纖維和透明脈管。
8. **粒子物理來源**：液滴由敵方傷口或命中處被根尖捕捉；木屑由母枝被壓裂；濕纖維絲來自斷面拉伸；暗紅霧是熱血接觸冷空氣的微細霧化；焦灰只來自主幹承傷壞死區。避免所有粒子從無意義中心點噴出。
9. **禁止元素**：禁止心形 icon、紅色魔法圓、UI 連線節點、心電圖、血滴符號、器官寫實獵奇、人體血管解剖圖、文字或數字；禁止讓根系排成完美對稱冠冕或把共享傷害畫成全員同時紅閃。
10. **Impact material prompt**：`Square additive-blend combat support material on uniform pure black: one thick crimson-black living root network with translucent liquid channels divides a captured blood stream into several uneven branches, while a massive protective mother-branch is crushed flat by a lethal impact, splits along wet fibers and pulls taut around the endangered branch, leaving charred bark, red-white pressure light and physical droplets; readable shared lifeline, cinematic 2.5D depth, generous black padding, no anatomy diagram, heart icon, UI nodes, text, circle, rune or magic diagram.`

## 9. evergreen_court／青庭長春

1. **意境核心**：一座會判讀生命狀態的常青庭園從戰場長出：下層苔床替低生命者加厚、減震並補水，上層樹冠把滿生命者多餘養分壓成銳利葉光，轉為傷害增幅。
2. **開場環境反應（0.00–0.25 秒）**：隊伍範圍內地表先吸收散落水分，乾土顏色加深；低生命者腳下長出柔軟苔斑，滿生命者腳邊則先冒出直立硬葉。空氣流動被樹冠未成形的上升暖流拉高，細塵呈柱狀而非環狀旋轉。
3. **幾何組成（0.12–0.54 秒）**：三塊不規則苔床像厚墊般從地面隆起，邊緣互相咬合但不閉合成圓；苔床縫隙抽出兩根粗實木枝，向左右分叉成不對稱樹冠。低生命區的枝條長出寬厚、向下覆蓋的盾葉；滿生命區的枝端長出狹長、斜向外的刃葉。中央木節開口形成可見的發光樹液泉，負責持續供給兩種葉片。
4. **主物體、連續動作與景深（0.46–1.34 秒）**：鏡頭平面略低俯視。前景苔床在低生命者受擊前隆高並側向壓縮，像真正吸震墊；中景樹液沿木紋上升，到分叉處依生命狀態分流；後景樹冠每次治療時向內覆一次，每次滿血者攻擊時刃葉向攻擊方向彈直。0.98 秒中央樹液泉泵動，前景盾葉與後景刃葉以不同節奏回應，讓兩種增益可辨。
5. **命中／變形（0.72–1.46 秒）**：低生命者受擊時，盾葉先被壓出寬凹面，葉脈將力傳到苔床，苔床向周圍鼓起卸力；凹葉邊緣撕出少量綠纖維但不碎裂。滿血者出手時，刃葉從葉柄處翻面，將積存金綠樹液甩成一條有寬度的斜切葉光；使用後刃葉變薄、短暫失色，再由樹液補滿。
6. **餘韻（1.38–2.10 秒）**：庭園消退時先落下用過的薄刃葉，再由樹冠縮回粗枝；低生命區留下具厚度的濕苔與被壓平的盾葉，滿生命區留下尖細葉鞘。中央樹液泉最後凝成一小塊暖綠琥珀，沉入土中。
7. **主光／材質／色彩轉換**：低生命區以冷祖母綠、濕苔暗部和乳白樹液為主；滿生命區由深綠逐步轉金綠，刃葉釋放時邊緣升到暖黃白；中央木質保持低飽和棕綠，避免整片螢光。材質要有吸水苔絨、粗糙樹皮、厚蠟盾葉、薄硬刃葉與黏稠樹液。
8. **粒子物理來源**：水霧由苔床受壓擠出；綠纖維來自盾葉撕裂；薄金葉屑由刃葉高速翻面剝落；木屑只在枝條大幅彎曲處出現；乳白小滴由樹液泉泵動時濺出並優先落向低生命區。
9. **禁止元素**：禁止對稱花園圓環、精靈樹人、王冠、生命加號、綠色護盾 icon、無來源花瓣雨、魔法陣、符文、文字；禁止滿血增傷與低血治療都使用相同葉型、相同光色或相同動作。
10. **Impact material prompt**：`Square additive-blend support impact material on perfectly pure black: an asymmetric evergreen court rises as a thick wet moss basin, one rough branching trunk and a luminous sap fountain, with broad waxy shield leaves compressing into a cool emerald cushion below while narrow gold-green blade leaves snap outward above and shed a physical cutting sheet of light; differentiated healing and damage materials, cinematic 2.5D depth, generous black padding, no character, crown, UI, text, circle, rune or magic diagram.`

## 10. silent_feather_cadence／希聲繁羽

1. **意境核心**：把加速攻擊的節拍壓進三種羽毛的羽軸；每一拍讓羽枝鎖緊、羽片變成回聲刃，依「短、短、長」節奏追擊，而非用音符或抽象聲波表示節奏。
2. **開場環境反應（0.00–0.18 秒）**：第一次攻擊後，空氣中沿武器軌跡留下短暫壓縮槽，附近衣角延遲一拍才被氣流掀動；第二拍時地面細塵形成兩道相隔很近的窄痕，第三拍則拉出一條較長痕跡。環境聲光視覺上以三次不同長度的曝光脈衝呼吸，不出現音符。
3. **幾何組成（0.08–0.40 秒）**：三枚具體羽毛從壓縮槽中析出：鏽紅短羽、象牙中羽、金色長羽。每枚羽軸先變直、加厚成刃脊，左右羽枝由根部往尖端逐排扣合，形成有鋸齒邊與厚度的羽刃。前兩枚短而前傾，第三枚長而略後仰，三者錯位排列成可讀的短短長節奏，不排成扇形徽章。
4. **主物體、連續動作與景深（0.30–1.08 秒）**：鏡頭平面沿攻擊方向側看。前景鏽紅羽刃在第一短拍直線掠過，留下很短的壓縮尾；中景象牙羽刃在 0.12 秒後沿稍高平面追上，切過第一刃尾端；後景金色長羽先蓄在畫面後上方，第三拍才以較長弧線壓下。每枚命中後不消失，而折返半個身位，從其尾流分裂出一枚尺寸較小、透明度較低的回聲刃追擊同一落點。
5. **命中變形／破壞（0.54–1.24 秒）**：羽刃接觸時羽尖先彎成鉤狀貼住目標平面，羽枝隨後由前到後逐片折斷，折斷線形成可見的切割進程；回聲刃命中同一裂口，把已彎曲的羽軸壓成扁平金屬片並向兩側彈走。第三枚長羽命中後，其羽軸沿長度裂成兩半，兩半交錯剪切而非產生圓形爆炸。
6. **餘韻（1.16–1.78 秒）**：落點留下三道短短長的平行切痕、數片有具體羽枝紋理的碎片，以及一條逐漸回彈的空氣壓縮帶；鏽紅碎片最先落地，象牙碎片稍後旋落，金色長羽的半軸最後像薄金屬片插入地面。
7. **主光／材質／色彩轉換**：鏽紅羽為低亮暖銅，象牙羽帶冷白邊，金羽在蓄力時由暗金升到白金；每枚回聲刃比母刃偏紫灰且更透明，命中瞬間才恢復母色。材質需保留真實羽枝的柔韌紋理，同時讓加厚羽軸具有金屬硬度，不能全部變成平滑雷射。
8. **粒子物理來源**：細羽絨由羽枝扣合與折斷時脫落；長條亮屑來自金屬化羽軸被剪裂；灰白空氣絲是高速羽刃壓縮水氣；地面塵屑由近地掠過的第一羽帶起；各粒子必須遵循短短長三段速度與延遲。
9. **禁止元素**：禁止音符、五線譜、節拍 UI、羽翼徽章、圓形聲波、均勻扇形羽毛、天使意象、角色持羽武器、文字、符文或魔法圓；禁止三枚羽刃同時齊射，必須保留節奏延遲與回聲追擊。
10. **Impact material prompt**：`Square additive-blend offensive impact material on uniform pure black: three concrete feather-blades in a readable short-short-long cadence—a compact rust feather, an ivory mid feather and a long white-gold feather—race across staggered depth, their metal-thick shafts bending at one shared cut while barbs snap sequentially and each trail releases one smaller delayed echo blade; compressed vapor, real feather fibers, metallic slivers, cinematic directional lighting, generous black padding, no character, wing emblem, music notes, UI, text, circle, rune or magic diagram.`

## 11. skyward_returning_feathers／天光回羽

1. **意境核心**：先由一片巨大弧羽像犁刀般把敵人推向中央，再讓八片從不同高度與深度放出的回聲羽刃越過目標、折返、以羽軸先後插向同一核心；重點是「出去後回來」的可讀路徑，不是八方向圖標。
2. **開場環境反應（0.00–0.22 秒）**：敵人周圍地面碎屑先被一股側向弧風推移，所有鬆散物沿同一弧線滑向聚集點；上方雲塵被切出一條明亮缺口，天光只照亮弧線前緣。0.14 秒時，敵人衣角與煙霧先向外倒，再被回壓拉向中心。
3. **幾何組成（0.10–0.48 秒）**：一條銀藍厚弧板由數片重疊羽枝拼成大型聚敵弧羽，羽軸為金白硬脊；其後八枚回聲刃不是同心排布，而分成前景三枚、中景三枚、後景兩枚，各由一條狹長銀藍羽片包住金色羽軸。每枚先朝外，越過指定頂點後羽軸中段折出明確關節，為折返做準備。
4. **主物體、連續動作與景深（0.38–1.24 秒）**：鏡頭平面略俯視並朝聚集點推近。前景大弧羽自左下切到右上，厚弧板掀起碎屑並把敵人推入中景核心；後景兩枚回聲刃最先向上外側射出，中景三枚次之，前景三枚最後擦過鏡頭邊緣。0.82 秒各刃越過目標後，關節折 35–60 度，尾端受天光拉扯而翻面；折返順序反轉為前景、 中景、後景，形成由近到遠的八次中心收束。
5. **命中變形／破壞（0.88–1.42 秒）**：每枚回羽以金色羽軸先刺入同一狹小核心，外側銀藍羽枝因急停向前包覆；八次命中把核心逐層壓成白金薄片。最後大弧羽從後方追上，厚弧板沿羽軸裂開成上下兩片，像巨剪般把薄片縱向切開，形成一條筆直天光裂口；不能用圓形爆炸收尾。
6. **餘韻（1.34–2.00 秒）**：中心留下八截朝不同深度傾斜、但插入同一裂口的金色短羽軸；地面保留大弧羽犁出的弧形碎屑溝，以及裂口中央一條逐漸變窄的銀白天光。折斷的銀藍羽枝按命中先後落下，靠近鏡頭的碎片較大且先失焦。
7. **主光／材質／色彩轉換**：聚敵弧羽初始深銀藍，前緣帶冷白；外射時回聲刃羽軸為暗金、羽枝為月白藍；折返翻面後羽軸升成白金、背面帶淡紫陰影；八次壓縮使核心從青白轉暖白，最後天光裂口再退回冷銀。材質需兼有柔韌羽枝、硬質羽軸與被壓成薄片的高亮物質。
8. **粒子物理來源**：地面碎屑由大弧羽犁動；細長銀羽屑由回聲刃急停時羽枝折斷；金色短屑由羽軸刺入核心時刮落；白色水氣帶由高速外射形成，折返點因壓力反轉而出現短促渦尾，但不可閉合成環；天光微塵只從上方裂口下落。
9. **禁止元素**：禁止八等分輪盤、放射刻度、完整圓形羽環、星形 UI、天使翅膀、音符、無來源光劍、角色剪影、文字、符文或魔法陣；禁止所有羽刃同一平面同時向心，必須有外射、翻面、折返與前中後景順序。
10. **Impact material prompt**：`Square additive-blend offensive impact material on perfectly pure black: one massive silver-blue feathered crescent physically plows debris toward a tight center while eight separate feather-blades at foreground, midground and background have visibly hinged after flying outward and now return shaft-first into the same compressed white-gold slit, their flexible barbs wrapping forward before the crescent splits like giant shears; concrete feather matter, cold sky light, gold shafts, strong 2.5D depth, generous black padding, no character, wing emblem, radial wheel, UI, text, circle, rune or magic diagram.`

## 完成檢查

- [x] returning_counterguard
- [x] inferno_cremation
- [x] frozen_burial
- [x] thunder_prison_pierce
- [x] orchid_corrosion
- [x] sunbearing_dawn
- [x] returning_spring_spirits
- [x] shared_bloodline
- [x] evergreen_court
- [x] silent_feather_cadence
- [x] skyward_returning_feathers

# Finisher Choreography — Batch A

本批次涵蓋 `data/combo_finishers.json` 的前 11 個 Combo Finishers。每段時間均為
單次終結技內的 normalized timeline；runtime 可依實際秒數等比例映射，但不得把
不同 beat 同時淡入。所有畫面皆為純 2.5D：地面、後景、中景、前景使用獨立
CanvasItem 深度與視差，不使用真正 3D 或 SubViewport。

## 1. `silent_battle_rhythm` — 戰律希聲

1. **意境核心**：把本輪戰鬥的三次重擊壓縮為「三根逐次增大的鍛造刃肋」。它們不是音符或節拍 UI；每一肋都是前一次斬壓留下的實體銅鋼壓痕，第三肋承載並重演最高傷害。
2. **開場環境反應（0.00–0.14）**：戰場聲音感先被抽空；角色前方地面灰塵沿同一方向貼地後退，近景火星短暫懸停。暗紅銅煙由後景向中心被吸入，形成三段相隔不均的壓力凹槽。
3. **語意物體構成（0.10–0.34）**：第一條細象牙光刃先由左下向右上鍛出；第二條在其後方以較厚的紅銅背脊合攏；第三條由兩片弧形金屬面咬合成最大刃肋。接縫先暗、再被內部熱光焊亮，明確讀成三次遞增重擊，而非三個同心圓。
4. **連續動作與 2.5D（0.30–0.66）**：後景第一肋先向前掠過，中景第二肋追上並部分覆蓋，前景第三肋最後加速，把前兩道殘壓推成同一個向右的厚重刃浪。三者速度為 `1.0 : 1.25 : 1.65`，深度尺寸為 `0.72 : 0.9 : 1.15`，視差方向一致。
5. **命中變形／破壞（0.64–0.76）**：第三刃肋接觸時不是白色爆閃，而是前緣先扁平壓縮、金屬面沿受力方向出現三條熱裂；隨後三肋瞬間套合成一個最厚的象牙金衝擊月牙，將銅煙與金屬屑向右扇形推出。
6. **具體餘韻（0.76–1.00）**：留下一道緩慢冷卻的紅銅刃痕、三片仍旋轉的鍛屑，以及沿地面滑行後熄滅的熱粉。最大刃肋的外緣由白轉橙、再轉暗紅，最後斷成不規則冷鐵片。
7. **主光／材質／色彩**：蓄勢為暗紅銅與低亮象牙；追擊時銅鋼面出現方向性金屬高光；最高傷害重演時核心升為象牙白，刃背維持紅銅，背光陰影保留深褐黑。不可整體變成金色光圈。
8. **粒子物理來源**：紅銅煙來自三次壓痕摩擦空氣；橙色火星來自刃肋焊接接縫；片狀金屬屑來自第三肋命中開裂；貼地粉塵只由衝擊前緣刮地產生。
9. **禁止元素**：音符、五線譜、節拍刻度、鐘面、無來源星點、裝飾性同心圓、三格分鏡、徽章邊框、中央貼圖示、細線霓虹月牙。
10. **Impact material prompt**：`Square 2.5D JRPG combat impact material on perfectly pure black for additive blending: three tangible forged bronze-and-ivory blade ribs compressed into one massive forward shock crescent at contact, the third rib visibly largest and replaying the strongest strike, beveled red-copper backs, ivory-hot welded cores, directional metal fracture, copper pressure smoke and real forged chips, strong single silhouette, foreground debris / middle impact rib / rear smoke depth, generous black padding; no character, weapon hilt, text, UI, frame, badge, magic circle, clock ticks, generic rings, thin vector lines, or white flash hiding the object.`

## 2. `horizon_stream` — 天際流光

1. **意境核心**：先用一條橫跨戰場的「地平線刃流」把敵人與空氣壓向中央，再由反向斬線撕開同一條流光；主體是兩個因果相反的水平切面，不是交叉裝飾。
2. **開場環境反應（0.00–0.13）**：遠近景煙塵同時被壓成水平薄層；地面草葉與碎紙先朝中央伏倒。畫面中央只出現一個極細金白亮點，左右兩側的空氣折射逐步拉長。
3. **語意物體構成（0.10–0.28）**：數條短金色流絲從左右接成一條連續、微帶厚度的象牙地平線；線的上下各形成一片透明壓縮氣膜，邊緣帶淡藍稜彩。反向斬尚未出現，先讓水平主物體讀清楚。
4. **連續動作與 2.5D（0.26–0.64）**：後景水平刃流由左至右高速延展；中景煙雲被吸向中心線；0.48 起，前景第二道較厚的弧斬由右下反向掃回左上，穿過既有地平線。前景弧斬遮擋中景線，但兩者交會點只佔畫面小區域。
5. **命中變形／破壞（0.62–0.75）**：水平線在交點先收窄成高密度白金刃芯，再被反向弧斬剪成上下兩層；破韌以厚片稜彩碎片沿水平方向剝落，不使用圓形爆炸。
6. **具體餘韻（0.75–1.00）**：一條筆直金白殘線在空中延遲消失；上下兩片壓縮雲分向兩側舒展；少量透明稜鏡片繼續水平滑行，亮面翻轉兩次後熄滅。
7. **主光／材質／色彩**：主線為象牙白熱光，邊緣是香檳金；壓縮氣膜採煙灰金與極淡冷藍；反向弧斬在接觸前保持金色，破韌瞬間才出現彩虹稜鏡邊。
8. **粒子物理來源**：金絲來自主刃流拉伸；煙塵來自戰場空氣與地表被壓縮；稜彩碎片來自兩個切面互剪後的凝結光片；不得加入無來源火花雨。
9. **禁止元素**：完整圓環、星盤、水平線上的刻度、交叉準星、字母、地平線風景、三格展示、中央徽章、均勻放射線。
10. **Impact material prompt**：`Square 2.5D JRPG combat impact material on perfectly pure black: one razor-thin ivory-gold battlefield horizon cut compressed into a tangible hot plasma line, crossed at contact by one thicker reverse crescent from the opposite direction, the horizon shearing into upper and lower pressure sheets with prismatic armor-breaking slabs and smoky gold air, strong horizontal silhouette, foreground reverse slash / middle horizon core / rear compressed cloud, generous black padding; no landscape, character, sword, text, UI, border, badge, circle, radial grid, ticks, runes, panels, or flat neon line art.`

## 3. `sudden_rain_cadence` — 驟雨繁音

1. **意境核心**：被壓縮的攻擊間隔化成具有重量與節奏群組的「藍鋼刃雨」，積蓄斬擊在最低點一次結算成水鋼撞擊冠。它必須是由上而下的重力事件。
2. **開場環境反應（0.00–0.12）**：上方黑暗先出現低頻冷藍反光；地面細水珠反重力抬起，敵人附近霧氣被向上抽成細絲，預告下一刻向下釋放。
3. **語意物體構成（0.08–0.30）**：第一批三根長藍鋼雨刃在後景凝成尖錐；第二批五至七根在中景由水膜包覆的金屬脊咬合；最後幾根前景英雄刃從冷霧中拔出。長短、傾角與間距不均，依 `3 → 5 → 密集群` 的節奏建立驟雨。
4. **連續動作與 2.5D（0.28–0.68）**：後景小刃先落、中景群刃再落、前景三根最大刃最後穿過鏡頭下緣；每群之間保留清楚的 0.04–0.07 節拍空隙。落下尾跡是濕潤金屬拉出的水膜，不是純光線。
5. **命中變形／破壞（0.64–0.78）**：每根刃先刺入同一低位區域，水膜沿刃脊向外翻；最後群落下時，積蓄斬擊把水與金屬碎面共同推成寬而低的鈷藍撞擊冠。英雄刃尖可碎成銳角水晶鋼片，但主體不可全變白。
6. **具體餘韻（0.78–1.00）**：地面留下短暫沸動的深藍水窪、斜插後溶解的三根半透明刃尖，以及受重力落回的粗水滴。撞擊霧貼地散開，不能向上形成通用蘑菇雲。
7. **主光／材質／色彩**：上方是深海軍藍，刃芯為冷白藍鋼，水膜為鈷藍；命中才增加少量銀白高光。前景刃有清楚濕金屬面，後景尾跡更暗更柔。
8. **粒子物理來源**：水滴來自包覆刃脊的水膜；藍鋼碎片來自刃尖撞裂；底部霧來自水膜高速汽化；上升微滴只出現在蓄勢抽吸階段。
9. **禁止元素**：雨滴圖示、圓形法陣、雷電、冰柱替代金屬刃、均勻垂直線簾、無節奏的粒子填滿、中央寶劍徽章、邊框。
10. **Impact material prompt**：`Square 2.5D JRPG combat impact material on perfectly pure black: staggered clusters of heavy blue-steel rain blades descend with real gravity and wet specular water skins, three crisp foreground hero blades piercing a shared low contact zone while accumulated slashes erupt into a broad cobalt-white water-and-metal impact crown, sharp steel-water fragments and grounded mist, top sparse / middle dense / bottom explosive depth, generous black padding; no character, hilt, icon sword, text, UI, frame, magic circle, rings, grid, runes, uniform line curtain, ice stalactites, or gray background.`

## 4. `falling_moon_arc` — 月輪垂光

1. **意境核心**：一塊有厚度、重量與月面質感的「月輪斷片」從上方垂落，先劈開姿態，再以接地壓力推出環形衝擊。月輪不是裝飾背景，而是實際墜落的巨大刃體。
2. **開場環境反應（0.00–0.15）**：上方環境光由暖轉冷，地面影子向兩側拉長；銀灰月霧向高處集中，附近碎屑先輕微浮起，呈現巨大物體正在上方成形。
3. **語意物體構成（0.10–0.33）**：一道細金邊先描出弧形切面；銀灰月岩由內向外填充，月坑、裂紋與霧層只沿弧體生長；背面維持冷暗，切刃下緣被壓成厚實象牙金。完成時只是一段不閉合的大月弧，不形成徽章圓月。
4. **連續動作與 2.5D（0.30–0.66）**：後景月霧先向下拖長；中景月輪斷片以近垂直、略偏斜的路徑墜落並放大；前景小月岩碎屑因視差更快掠過。主弧體下緣始終朝接觸點，禁止原地旋轉展示。
5. **命中變形／破壞（0.64–0.78）**：切刃先壓扁成白金接觸線，月岩正面從接觸點向上爆出放射裂紋；隨後弧體底端削去一角，碎成有月坑質感的厚片。環形擊退只用一圈低矮橢圓壓力浪，且必須從接觸點沿地面推出。
6. **具體餘韻（0.78–1.00）**：半段殘月刃在空中化為銀灰粉末；落地月岩片翻轉顯示金亮斷面後變暗；低空留有一條冷銀霧痕，地面橢圓浪逐步變薄消失。
7. **主光／材質／色彩**：月面主體是冷銀灰與藍黑陰影，切刃為象牙金；接觸裂紋由金白轉琥珀；餘韻只留冷銀，不維持全畫面金光。
8. **粒子物理來源**：月岩厚片來自弧體接觸開裂；銀粉來自月岩表面風化；地面塵浪來自實體墜落；金色細粒來自過熱切刃崩落。
9. **禁止元素**：完整圓月、中央寶劍、月相 UI、星盤、同心圓波紋、多圈法陣、隨機星星、漂浮文字、三格演示。
10. **Impact material prompt**：`Square 2.5D JRPG combat impact material on perfectly pure black: one colossal thick moonstone crescent fragment falling steeply into contact like a lunar guillotine, cratered cold silver face, deep blue-black back, ivory-gold cutting underside compressed at the ground, cracks racing upward and ejecting heavy moonstone slabs while one low physically sourced elliptical pressure wave pushes outward, foreground lunar debris / middle crescent / rear moon mist, generous black padding; no full moon emblem, sword, character, UI, text, border, star chart, generic rings, multiple shock circles, runes, or flat wireframe crescent.`

## 5. `thousand_blade_kill` — 千羽相應

1. **意境核心**：羽毛輪廓其實是鍛成羽脈的「刃羽」；它們全向放出、在戰場邊界彎折，再由不同深度折返中心，回聲逐次增幅。主意象是一群可辨識的金屬刃羽，不是放射線花朵。
2. **開場環境反應（0.00–0.13）**：中心氣流先向內旋吸，細小金屬屑沿彎曲路徑聚攏；四周遠景出現幾個快速掠過的冷白反光，預告邊界折返路線。
3. **語意物體構成（0.08–0.30）**：中心先鍛出一片大型主刃羽：中央鋼脊、左右不對稱羽片、舊金細邊；其後依同一結構分裂出大小不同的刃羽。每片都有尖端與羽脈切槽，禁止用葉片或純光三角替代。
4. **連續動作與 2.5D（0.28–0.68）**：後景小刃羽先向四周飛出；中景中型刃羽形成不對稱翼扇；前景三至五片英雄刃羽掠過鏡頭。到邊界後，每片不是反彈直線，而是沿銀色弧形尾跡轉向，分批折返中心；第二批回聲尺寸與亮度略大於第一批。
5. **命中變形／破壞（0.64–0.80）**：折返刃羽在中心交錯剪切，主刃羽的羽片沿羽脈裂成更細的增幅刃；命中輪廓是多方向金屬穿刺與兩條彎曲返程剪線，中央亮點保持小而銳利，不能白光覆蓋所有刃羽。
6. **具體餘韻（0.80–1.00）**：幾片未命中的刃羽繼續沿邊界滑行後化為冷鋼粉；中心留下兩條逐漸收窄的銀色返程尾跡；舊金羽脈碎片緩慢翻轉、亮面熄滅。
7. **主光／材質／色彩**：主體為象牙鋼、冷青高光、舊金羽脈與少量暗紅磨痕；外放階段偏冷，折返增幅時羽脈逐片升為暖金，中心剪切只短暫出現白光。
8. **粒子物理來源**：冷鋼粉來自刃羽高速磨損；舊金片來自羽脈開裂；銀色尾跡來自金屬刃切開空氣的凝結線；所有星點都必須是翻轉中的微小刃屑。
9. **禁止元素**：真鳥、柔軟羽毛、完整翅膀生物、均勻放射輪、魔法陣、星盤、圓形邊界線、葉子、徽章、看不出折返因果的隨機飛刃。
10. **Impact material prompt**：`Square 2.5D JRPG combat impact material on perfectly pure black: a flock of tangible forged feather-shaped blade shards completes a curved boundary return and cross-cuts through one compact center, large engraved ivory-steel hero blade-feathers in foreground, amplified warm-gold returning crescents in middle depth, smaller cold metallic echoes behind, feather spines splitting into additional sharp blades at contact, asymmetric wing-and-crossfire silhouette, generous black padding; no bird, soft feathers, character, hilt, UI, text, frame, badge, circle, radial wheel, magic runes, leaves, or random evenly spaced spokes.`

## 6. `still_mountain` — 靜岳無移

1. **意境核心**：防禦不是罩子，而是一座由層疊黑岩與暗鐵承壓形成的「不動山體」；所有硬直與擊退被山腹壓縮，結束時從山腳斷層釋放為震地波。
2. **開場環境反應（0.00–0.16）**：角色周圍地面先下沉少量，碎石向中心滾動而非漂浮；遠景風與煙在山體範圍外繞行，近景塵土貼住地面，表現不可擊倒的重量。
3. **語意物體構成（0.10–0.36）**：低矮黑岩板由地面向上互相插合，先形成寬山腳，再逐層咬成不對稱山峰；暗鐵壓條只沿主要承重裂面出現。幾何線條是岩層邊與鐵縫，必須填成有厚度材質，不能停在線框山形。
4. **連續動作與 2.5D（0.34–0.70）**：後景高峰幾乎不動；中景山腹每承受一次攻擊便向內壓縮一層，琥珀裂光被推向山腳；前景岩板因壓力輕微抬起又落回。攝影平面以山腳最大、山腹次之、峰頂最暗，建立重量而非浮空縮放。
5. **命中變形／破壞（0.68–0.81）**：儲存壓力到達山腳後，中央斷層先發出低亮琥珀線，再把前景厚岩板成排掀起；震地波是由實體岩層翻轉形成的低扇形破壞帶，不是圓形光波。山峰上半仍保持完整，證明「無移」。
6. **具體餘韻（0.81–1.00）**：被掀岩板按重量落回，留下發熱的鋸齒斷層；琥珀粉塵沿地表爬行後冷卻；山體由峰頂向山腳逐層退回黑岩碎片，最後只剩一道暗鐵壓痕。
7. **主光／材質／色彩**：主體為深灰黑板岩與冷鋼邊，蓄力只在山腹深處出現低亮琥珀；釋放時琥珀由內向山腳增亮，峰頂保持冷暗，避免整座山變成發光水晶。
8. **粒子物理來源**：重岩片來自山腳斷層；細灰來自岩層摩擦；琥珀熱粉來自壓力縫；不得出現上升魔法星塵或無重力碎石。
9. **禁止元素**：盾牌徽章、寶劍、圓形護罩、地元素法陣、漂浮山、均勻岩柱環、符文、發光山峰輪廓、通用爆炸球。
10. **Impact material prompt**：`Square 2.5D JRPG defensive finisher impact material on perfectly pure black: one immense asymmetric mountain bulwark of layered black slate and hammered dark-iron seams remains immovable above while stored knockback ruptures only from its base, rows of heavy foreground rock slabs flipping outward from a hot amber fault and a low grounded fan of grit, cold dark peak / compressed glowing middle faults / foreground quake debris, generous black padding; no character, shield emblem, sword, building, UI, text, border, magic circle, ring, runes, floating rocks, crystal mountain, or generic explosion.`

## 7. `stone_ring_guard` — 石環守一

1. **意境核心**：厚重玄武岩片與青銅扣件構成可受擊的「破口石環」，每塊石片都實際擋下一次攻擊；破碎後，受力方向決定碎石追蹤反射路徑。
2. **開場環境反應（0.00–0.15）**：附近碎石被地面震動推向中心，在低空短距離翻滾；暖金核心光先照亮石片朝內面，背面保持冷灰，顯示保護中心而非召喚裝飾。
3. **語意物體構成（0.10–0.34）**：第一塊大玄武岩板在左前景卡入青銅扣；其餘不等尺寸石片依受力結構逐塊鎖合，形成有明顯前後遮擋、保留一個可讀破口的近閉合護環。閉合線不均勻，青銅箍只跨越相鄰石縫。
4. **連續動作與 2.5D（0.32–0.70）**：後景石片先鎖定，中景兩側補合，前景最大石板最後擋住核心。每次受擊時對應石片向內沉、裂光沿青銅扣傳到核心；其他石片只被牽動少量。護環可緩慢調整朝向，但不得機械式等速旋轉。
5. **命中變形／破壞（0.68–0.82）**：受擊最多的前景石片先沿天然層理破裂，青銅扣被拉直成發亮導軌；碎片翻出露出暖金礦脈斷面，沿記錄的攻擊方向加速，離環後再略彎向目標，形成追蹤反射。
6. **具體餘韻（0.82–1.00）**：未破石片失去核心支撐後依序落下；反射碎石拖著短促金色礦粉尾跡離場；核心光縮成一塊熄滅的礦石，地面留下青銅扣與碎屑。
7. **主光／材質／色彩**：粗糙玄武岩面是深灰，背面帶冷藍；核心與斷面為暖金，青銅扣偏舊褐。受擊時只點亮傳力路線，不能讓整環均勻發光。
8. **粒子物理來源**：玄武岩屑來自受擊石片；金色礦粉來自新鮮斷面；青銅火花來自扣件拉伸；灰塵來自石片落地。追蹤尾跡不能是無材質雷射。
9. **禁止元素**：完美等分石圈、十二刻度、盾牌或劍徽章、固定旋轉法陣、相同尺寸重複石塊、環外無來源符號、整體金色光圈。
10. **Impact material prompt**：`Square 2.5D JRPG defensive finisher impact material on perfectly pure black: an irregular near-closed guard orbit of thick chipped basalt and slate blocks held by stressed oxidized-bronze clamps, one foreground block crushed inward then bursting outward into tracked counter-projectiles with hot gold mineral fracture faces, protected dense core visible through the functional breach, clear rear intact blocks / middle core / foreground launched fragments, generous black padding; no perfect circle, evenly repeated stones, character, sword, shield icon, UI, text, badge, frame, clock ticks, magic runes, radial grid, or flat line geometry.`

## 8. `tempered_bones` — 金骨含章

1. **意境核心**：減免傷害會沿一副「鍛金肋骨甲」逐節淬鍊；結束時肋骨從防禦形態依序解鎖、重疊鍛成一記破韌拳骨。防與攻必須是同一份骨材的連續變形。
2. **開場環境反應（0.00–0.14）**：周圍暖光被吸到身前狹窄區域，空氣中的鐵粉沿脊柱方向排成縱列；外部攻擊火星接近後速度降低，像撞上高密度骨甲壓力。
3. **語意物體構成（0.10–0.36）**：中央暗金脊骨由多節短金屬椎體扣合；左右肋條從上到下逐對鍛出，每根先是暗骨芯，再包覆金色淬火面；胸骨最後閉合。輪廓應像厚實胸甲骨架，不是骷髏角色或宗教徽章。
4. **連續動作與 2.5D（0.34–0.70）**：後景脊骨固定，中景肋骨承受攻擊時逐根向內彈性彎曲，前景胸骨吸收衝擊並把金光傳到最下方。每次減免都令一根肋條由暗金轉亮金，形成可數但非 UI 化的淬鍊進度。
5. **命中變形／破壞（0.68–0.82）**：肋條由下至上脫離脊骨，沿前後深度套疊成五指與拳骨輪廓；胸骨壓成拳面，脊骨縮成前臂。金骨拳向前短距爆發，接觸時拳面出現鍛裂、將厚實金屬片與敵方破韌碎片推出。
6. **具體餘韻（0.82–1.00）**：拳骨解體回到冷卻肋條，亮金表面沿邊緣退成暗青銅；少量鍛皮剝落旋轉，留下暗紅熱痕與一縷鐵粉煙。
7. **主光／材質／色彩**：初期為骨白暗芯、青銅外層；每次減免增加一段暖金淬火色；出拳時拳面為象牙金高光、背面維持深褐。不可使用血肉紅或骷髏綠光。
8. **粒子物理來源**：鐵粉來自骨甲鍛造；金屬火星來自外部攻擊撞擊肋骨；鍛皮薄片來自淬火層剝落；破韌厚片只在拳面接觸時產生。
9. **禁止元素**：完整骷髏、人物軀體、死亡意象、翅膀、鹿角裝飾、法陣圓框、骨頭雨、拳頭圖示、全畫面金色爆炸。
10. **Impact material prompt**：`Square 2.5D JRPG defensive-to-offensive finisher impact material on perfectly pure black: a forged golden ribcage armor continuously transforms into one heavy spectral knuckle structure, paired tempered ribs nesting into five finger bones, sternum compressed into the striking face, spine becoming the short forearm, the gold-bone fist cracking at contact and ejecting thick armor-breaking metal slabs and quenched scale flakes, clear rear releasing ribs / middle forged fist / foreground contact chips, generous black padding; no character body, skeleton, skull, gore, wings, antlers, text, UI, badge, circle, runes, bone rain, cartoon fist icon, or generic gold explosion.`

## 9. `trackless_gale` — 扶搖無跡

1. **意境核心**：角色化為三條彼此錯位的「風痕航道」穿越敵陣，航道本身在通過後收縮成延遲風刃。重點是三次位移路徑與延遲切開的因果，而不是一隻風獸或一團龍捲風。
2. **開場環境反應（0.00–0.12）**：地面葉片與塵絲先沿三條窄路徑向前伏倒；遠景空氣出現三道透明折射溝，路徑之間保留黑色負空間。
3. **語意物體構成（0.08–0.28）**：第一道青綠風痕由兩片壓縮氣膜夾成尖長航道；第二道在較高、較後景位置形成；第三道從近景低位切入。每條都有較厚的前端風喙與逐漸變薄的尾膜，讀成高速通路而非三條霓虹線。
4. **連續動作與 2.5D（0.26–0.66）**：後景航道先穿過，中景第二道交錯，前景第三道最後掠過並產生最大視差；三者不完全平行，分別穿越敵陣不同深度。通過後尾膜沒有立即消失，而是由兩側向中線慢慢夾緊。
5. **命中變形／破壞（0.64–0.80）**：每條殘留航道按穿越順序延遲閉合，兩側氣膜碰合時變成一片厚青白風刃，從路徑尾端向前爆開；命中物被風壓切出的薄物質片沿原路徑滑出，三次爆發時間明確錯開。
6. **具體餘韻（0.80–1.00）**：三條航道留下透明扭曲熱霧般的空氣縫，依後、中、前景順序回彈；被捲起的葉片與灰塵失去升力後落下，最後只剩一兩條青綠細流快速逸散。
7. **主光／材質／色彩**：氣膜主體為透明青綠與冷白壓力邊，內部黑色負空間要保留；延遲閉合時才出現高亮青白切刃，尾端可帶極少金屬青高光。
8. **粒子物理來源**：葉片與灰塵來自地面被航道捲起；水氣微粒來自空氣壓縮凝結；青白碎片是氣膜閉合時剝離的薄層；不得加入無來源星塵或羽毛。
9. **禁止元素**：風龍、鳥、羽翼、完整龍捲風、三條等距霓虹線、圓形風法陣、葉片填滿畫面、同步爆炸、速度刻度。
10. **Impact material prompt**：`Square 2.5D JRPG combat impact material on perfectly pure black: three offset teal-white compressed-air lanes at distinct rear, middle, and foreground depths have already passed through and now close sequentially into delayed thick wind blades, each lane made of two tangible translucent pressure membranes squeezing toward a dark center seam, the nearest blade bursting last with sheared air flakes, grounded leaves and dust that have a physical source, strong three-path forward silhouette and generous black padding; no dragon, bird, wings, tornado, equal neon stripes, character, UI, text, frame, magic circle, runes, speedometer ticks, or simultaneous generic burst.`

## 10. `enduring_arcane_breath` — 綿息若存

1. **意境核心**：星脈像呼吸一樣「倒流入一枚靛青金雙螺旋氣核」，急速補回 AP；第一次耗盡時，氣核內保留的一小股金色備用呼吸反向釋放。它是循環呼吸的物質，不是 mana UI。
2. **開場環境反應（0.00–0.15）**：周圍微弱光點停止外散，沿彎曲路徑倒退；角色附近布料與煙霧先向內收，再短促放鬆一次，建立吸氣節奏。地面不出現法陣。
3. **語意物體構成（0.10–0.36）**：兩條靛青半透明星脈帶從上下反向纏繞，逐段形成雙螺旋；交會節點凝成小型金色星砂核。幾何線只作為螺旋骨架，隨後被有厚度的絲質 mana 膜包覆；中段保留一個較暗的備用氣囊。
4. **連續動作與 2.5D（0.34–0.70）**：後景遠端星點先沿螺旋倒流；中景靛青脈帶向核心收緊；前景幾顆金色節點穿過鏡頭、回到核心。核心每吸入一段便膨脹一次，但整體位置穩定，像呼吸而非旋轉 logo。
5. **命中變形／破壞（0.68–0.80）**：補滿瞬間，雙螺旋不爆炸，而是收束成一枚透明靛青氣珠；外層脈帶斷開並向內融入。第一次 AP 耗盡的預備表現由氣珠內部金色小核反向翻面，吐出一條較短、較暖的回復脈衝。
6. **具體餘韻（0.80–1.00）**：主氣珠縮小並保留金色備用核；靛青絲帶尾端像液態絲綢般回捲，少量星砂沿原路緩慢外吐後熄滅。不可留下常駐圓形 HUD。
7. **主光／材質／色彩**：吸氣階段為深靛青、紫藍透光絲膜與冷銀星點；核心補滿轉為象牙金；備用回復只用小面積暖金，與主靛青形成清楚功能對比。
8. **粒子物理來源**：冷銀星點來自遠端星脈被倒吸；靛青霧滴來自 mana 絲膜表面剝離；金色節點來自核心儲存量；備用脈衝粒子只從內部小核吐出。
9. **禁止元素**：AP 字樣、數字、進度環、無限符號、星盤、劍徽章、圓形 mana 法陣、DNA 科學圖風格、均勻螺旋線、全畫面紫霧。
10. **Impact material prompt**：`Square 2.5D JRPG support finisher material on perfectly pure black: two tangible indigo translucent mana-silk streams reverse-flow into a compact double-helix breath core, cold star-meridian droplets traveling inward across rear/middle/foreground depth, the filled core condensing into one glassy indigo breath pearl with a small warm-gold reserve pulse visibly sealed inside, silk tails curling back from real fluid tension, generous black padding; no character, sword, AP letters, numbers, UI, progress ring, infinity sign, star chart, magic circle, DNA diagram, text, frame, or generic purple fog.`

## 11. `inexhaustible_reservoir` — 靈泉不窮

1. **意境核心**：靈泉從深層「金邊水脈盆」向上湧出，先突破容量、補滿，再把未消耗水量翻成包覆外側的厚水盾。主體要從泉盆、上湧水柱到盾膜連續轉化。
2. **開場環境反應（0.00–0.15）**：地面細小水珠向中心爬行，空氣中的青藍霧向下沉；中心下方出現一個低位、帶重量的深水凹陷，周圍反光像水底焦散向上移動。
3. **語意物體構成（0.10–0.36）**：兩條青藍水脈由左右流入，金色礦物邊沿其接觸處凝成不完全對稱的泉盆；盆內先形成深青旋流，再有一股厚實水柱向上鼓起。線條是水脈流向與盆緣結構，禁止直接畫無限符號。
4. **連續動作與 2.5D（0.34–0.70）**：後景細水脈先注入，中景泉盆水位快速抬升，前景大水舌越過盆緣後向上翻；水柱在頂端分成左右兩股回落，形成前後交錯的循環，但不閉合為平面 `∞`。突破上限時泉盆稍微擴張，金邊被水壓推亮。
5. **命中變形／破壞（0.68–0.82）**：補滿後仍持續湧出的水不爆炸，而是從水柱頂端向外翻成厚透明盾膜；未消耗力量越多，盾膜由下向上增加第二層水皮。外部撞擊會在盾膜表面壓出凹坑與環狀水冠，凹坑隨後回彈。
6. **具體餘韻（0.82–1.00）**：泉盆停止注入，中央水位下降；外層水盾保留較久，沿表面流下粗水珠回到盆中；金色礦物邊冷卻成暗金，最後留下幾滴帶青光的水與一片薄濕痕。
7. **主光／材質／色彩**：深層水為靛青，活水為青綠與青白焦散，盆緣與 AP 節點意象只用少量暖金礦物；形成盾膜時高光轉為柔和青白，不能整體變成金色護罩。
8. **粒子物理來源**：水滴來自水柱越過盆緣與盾膜回流；細泡來自泉底壓力釋放；金色小片來自盆緣礦物受水壓剝離；青霧來自高速水面霧化。
9. **禁止元素**：平面無限符號、AP 字樣、容量刻度、圓形護盾 UI、對稱噴泉建築、魚、蓮花、魔法陣、無來源金星、重複水環。
10. **Impact material prompt**：`Square 2.5D JRPG support finisher material on perfectly pure black: a deep teal living wellspring overflows a tangible asymmetric dark-gold mineral basin, thick cyan water rising in one volumetric column then folding outward into a layered transparent water shield from the excess, foreground cresting water skin / middle bright spring column / rear feeding currents, realistic caustic light, bubbles from pressure and heavy droplets returning to the basin, generous black padding; no flat infinity symbol, AP text, numbers, meter ticks, UI shield circle, fountain building, fish, lotus, magic circle, repeated water rings, frame, badge, or generic blue glow.`

# Finisher 2.5D Choreography — Batch C

This batch covers recipes 23–32 from `data/combo_finishers.json`. Timing is
normalized to a single Finisher timeline from `0.00` to `1.00`. Every stroke,
particle, and light below must belong to a named object or a physical event in
the choreography; decorative circles, pasted icon frames, and universal center
bursts are not valid substitutes.

## 23. 守一返照 (`guarding_reflection`)

1. **意境核心**：四片有重量的鏡盾把來襲力量「記在鏡面傷痕裡」，再把每道傷痕依原角度翻面射回。重點不是一面發光盾，而是可看見「接住、留下方向、反射」的因果。
2. **開場環境反應（0.00–0.14）**：角色周圍的地面亮度先降低；四個斜向窄反光分別出現在左前、右前、左後、右後。靠近攻擊來源的一側先被照亮，背向側維持暗面，空氣中的灰塵沿來襲方向被壓成短直線。
3. **語意物體組成（0.10–0.30）**：每道反光先折成一個不閉合菱形，再向內長出厚實金屬邊框與灰白鏡面，依序成為四片斜置鏡盾。四盾以開口堡形包住中心，彼此不靠圓環連接；鏡面上的細裂線只從真實受擊點向外生長。
4. **連續動作與 2.5D（0.28–0.68）**：前景兩盾向鏡頭微傾，遮住後景盾的下角；中景兩盾先後承受不同方向的光楔並向內退半個盾厚，後景盾以較小比例接住穿透餘光。每次承傷後，裂線沿原方向變亮並停留，四盾逐步轉向，讓鏡面法線對準各自的反射出口。
5. **命中變形／破壞（0.66–0.82）**：四盾同時沿垂直軸翻面，裂線從中心向外收束成四枚尖銳光楔；鏡面沒有爆成白球，而是像彈簧釋放般回正，光楔沿記錄方向射出。最強一楔擦過前景，帶走一小片金屬包角，形成可讀的近景速度。
6. **餘韻物質（0.80–1.00）**：留下一地薄而暗的鏡屑、四片逐漸失去反光的盾面，以及沿反射路徑緩慢冷卻的短金色刮痕；鏡屑只從盾緣與裂點脫落。
7. **光／材質／色彩轉換**：主光由受擊點的象牙白高光提供，盾框是舊金與深青銅，背面是暗酒紅。吸收期高光被困在裂線；翻面時才轉成金白方向光，釋放後快速降為茶褐餘光。鏡面必須保留灰度與裂紋，不可被純白過曝吃掉。
8. **粒子物理來源**：金屬火星來自光楔擦過盾框；玻璃薄片來自鏡面裂點；短灰塵線來自來襲空氣壓縮；離場金屑只來自被削掉的前景包角。
9. **禁止捷徑**：禁止萬用護盾泡泡、無來源環形波、鐘面刻度、放射網格、把 icon 圓框貼到場景、四盾同時淡入、白色中心爆光掩蓋翻面動作。
10. **Impact material prompt**：`Square 2.5D cinematic JRPG combat VFX material sprite on pure #000000 black for additive blending. Guarding Reflection at the exact counter-impact: four large slanted bronze-framed mirror shields form an open fortress in shallow three-quarter depth; each mirror contains a different directional crack scar from a caught attack, and the panels are visibly flipping to fire four sharp ivory-gold reflected wedges back along those recorded angles. Front shields overlap rear shields, one foreground metal corner is being shaved into sparks, mirror gray values and fracture detail remain readable without white overexposure. One dominant concrete shield-and-reflection silhouette, premium HD-2D painterly lighting, generous black padding. No character, UI, text, border, icon frame, generic bubble, magic circle, concentric rings, ticks, radial grid, mandala, three-panel sequence, or watermark.`

## 24. 扶搖泉湧 (`gale_reservoir`)

1. **意境核心**：疾行留下的風痕不是裝飾尾巴，而是把地面水氣捲成一條可被回收的「移動靈泉」；沿途凝出的 AP 星脈被逐枚拾取，最後泉水倒灌入核心並翻成溢流護層。
2. **開場環境反應（0.00–0.12）**：地面先出現三段被風壓掀開的細水膜，草屑與水珠都朝同一移動方向傾斜；最靠近鏡頭的水膜反射亮青色，遠景只留低亮藍黑濕痕。
3. **語意物體組成（0.08–0.30）**：三條不同高度的 S 型風水線依移動順序長出，線條外緣翻卷成具厚度的水羽／泉脊，而不是閉合圓。每隔固定距離，兩股水線交叉並擠出一枚四角金色 AP 結晶；每枚結晶都坐在真實路徑節點上。
4. **連續動作與 2.5D（0.26–0.68）**：後景第一股泉紋先向前滑，中景第二股越過它，前景第三股以較粗的青綠水脊掠過鏡頭下緣。五枚 AP 結晶由遠至近依序被吸回中心，拖出弧形水滴尾跡；路徑在結晶離開後塌成向內流的淺溝。
5. **命中變形／破壞（0.64–0.82）**：最後一枚結晶進入核心時，三股 S 泉脊從尾端開始反向折返，像水鞭般向上合成一支尖長的青金泉柱；柱頂溢出的水膜朝外翻成一面半透明弧形護層，清楚表現突破 AP 上限而非爆炸。
6. **餘韻物質（0.80–1.00）**：路徑留下濕亮細溝、數枚尚未落地的小水珠與金色結晶粉；護層向下滴回泉眼，最後只剩一條逐漸乾掉的青色風痕。
7. **光／材質／色彩轉換**：主材質從深藍水膜轉為青綠泉脊，AP 節點是暖金；拾取時金光沿水體內部逆流，溢流護層邊緣呈淡青白，內部保留透明水厚度與折射，不做霓虹塑膠。
8. **粒子物理來源**：懸浮水滴由風壓從水膜剝離；金色微粒由 AP 結晶被吸收時崩落；草屑只從地面受風處起飛；護層滴珠只從弧面下緣生成。
9. **禁止捷徑**：禁止無限符號直接貼圖、通用藍色旋渦、無節點來源的星雨、同心水環、隨機泡泡填滿畫面、把 icon 水羽原樣放大。
10. **Impact material prompt**：`Square 2.5D cinematic JRPG combat VFX material sprite on pure #000000 black for additive blending. Gale Reservoir at overflow impact: three tangible S-shaped wind-water trails from rear, middle, and foreground reverse direction and braid upward into one sharp teal wellspring column; five small four-point gold AP crystals are visibly being collected along the real path, with the nearest crystal entering the core and sending warm light backward through the water. The column crest folds outward into one translucent protective water sheet, with readable refraction, droplets torn from the trail, and wet grooves below. Strong asymmetrical path silhouette, premium HD-2D painterly material and depth, generous black margins. No character, UI, text, border, icon frame, generic whirlpool, infinity-symbol decal, concentric circles, radial grid, magic circle, random star field, montage, or watermark.`

## 25. 水火既濟 (`balanced_elements`)

1. **意境核心**：水、火、雷不是同時混成三色煙花，而是三段狀態互相改造：水壓迫火形成蒸氣熱震，火反推水造成瞬間凍裂，最後雷沿裂縫把兩種物質鎖成短暫循環天候。
2. **開場環境反應（0.00–0.14）**：左側地面凝出低伏水霧，右側地面因熱膨脹出現橙紅空氣扭曲；中央狹長區域先變暗，細小毛髮狀靜電只在水霧與熱流接觸邊界跳動。
3. **語意物體組成（0.10–0.32）**：左側兩條厚水弧向中央捲成半輪浪壁，右側三片火舌沿相反曲率合成半輪火壁；兩者不是裝飾圓框，而是有厚度、方向和飛濺來源的兩面物質壁。中央由一道細長紫白雷脊自上而下接合兩壁的接縫。
4. **連續動作與 2.5D（0.28–0.68）**：後景水壁先越過中央壓住火壁，產生中景白熱蒸氣楔；前景火舌隨後反捲，蒸發部分水體並把水珠拋向鏡頭。雷脊沿交界由上往下分三次點亮，讓水面結霜、火焰內緣收窄，三相變化依序可見。
5. **命中變形／破壞（0.64–0.84）**：中央雷脊突然向左右分叉，沿水火接縫拉出鋸齒；水半壁碎成大塊冰水晶，火半壁被壓成熔融薄片，兩者被同一股扭力捲成向前的三相螺旋楔。命中點發生熱震斷面，而非白色球爆。
6. **餘韻物質（0.82–1.00）**：地面殘留一條冒蒸氣的濕裂縫，左側散落融化冰片，右側散落暗紅熔滴；紫藍電荷只沿裂縫跳兩次後熄滅。
7. **光／材質／色彩轉換**：水是深藍到青白的透射光，火是暗紅到橙白的體積光，雷是窄而高亮的紫藍邊光。三色只在接觸面產生短暫白熱，不把整個中心燒成白洞；最後餘韻降為冷青、暗橙與少量紫電。
8. **粒子物理來源**：水珠由浪壁前緣剪切；熔滴由火壁被壓薄後甩出；冰片由雷擊結霜的水壁斷裂；蒸氣由水火接觸面產生；電弧只沿濕裂縫和冰片導電。
9. **禁止捷徑**：禁止三色平均分區圓盤、太極 icon 放大、無因果的元素球、通用三角法陣、全畫面彩虹粒子、同時淡入三元素、中心白爆遮住材料轉換。
10. **Impact material prompt**：`Square 2.5D cinematic JRPG combat VFX material sprite on pure #000000 black for additive blending. Balanced Elements at the heat-shock impact: a thick blue water half-wall from the rear collides with a sculpted orange-red flame half-wall from the foreground, while one narrow violet-white lightning spine tears down their physical seam. The water side is visibly freezing and breaking into large translucent ice-water plates; the fire side is compressed into molten sheets; steam is born only at their contact and the split materials twist forward into one sharp three-phase impact wedge. Premium original HD-2D JRPG material rendering, layered shallow depth, controlled highlights, generous black padding. No character, UI, text, border, icon frame, yin-yang emblem, circular elemental chart, magic circle, concentric rings, radial ticks, generic rainbow burst, montage, or watermark.`

## 26. 流火雷音 (`heavenly_wheel_sever`)

1. **意境核心**：一枚向前滾動的三層斬輪，外層火焰開路、中層回聲羽刃分裂、內層雷齒在命中時閉合；三層是有前後深度的武器結構，不是三個發光圓圈。
2. **開場環境反應（0.00–0.12）**：地面先被一道橙紅熱痕向前切開，熱痕兩側的灰塵被推向外；上方金屬屑沿相同軸線懸停，細紫電在屑片間短接，預告三種材料會共用前進方向。
3. **語意物體組成（0.08–0.30）**：外層由三片厚熔火刃首尾錯開扣成開口大輪；中層由六枚銀白羽刃沿較小半徑交錯成切削扇；內層由紫藍雷齒沿一個可見金屬輪轂依次點亮。輪緣都有刃厚、斜面與旋轉方向，中央保持黑色通道。
4. **連續動作與 2.5D（0.26–0.66）**：後景外火輪先滾入中景並削開路徑，中層羽刃向前景分裂成兩列後再折返輪轂，內層雷齒最後高速追上。近側輪緣放大且遮住部分遠側輪緣，熔滴向後甩、銀屑沿切線飛、雷弧跨接相鄰齒。
5. **命中變形／破壞（0.64–0.82）**：外火輪先咬入命中面並變形成扁橢圓；中層羽刃從兩側剪合，把斷面切成六瓣；內雷齒在中央瞬間鎖死，將六瓣沿前進軸推出。輪轂不爆成球，而是崩掉三枚帶電齒片。
6. **餘韻物質（0.80–1.00）**：路徑留下熔紅刃痕、六道短銀切線與三枚在地面跳電的雷齒；暗煙從熔痕邊緣升起，羽刃殘片逐步失光後消失。
7. **光／材質／色彩轉換**：外層由暗紅金屬到橙白熔刃，中層為冷銀與淡青反光，內層為深紫到藍白電光。命中亮度依外→中→內分三拍，不同半徑保持獨立，白色只出現在雷齒閉合的窄接觸線。
8. **粒子物理來源**：熔滴從外刃離心甩出；銀屑從羽刃擦切面剝落；紫電只連接輪齒或斷裂齒片；暗煙只來自熔痕；不得添加無來源星點。
9. **禁止捷徑**：禁止三個平面同心圓、鐘面刻度、放射線填滿空白、generic portal、把輪形 icon 直接貼上、所有材料混成一團白爆、三層同步旋轉且無深度遮擋。
10. **Impact material prompt**：`Square 2.5D cinematic JRPG combat VFX material sprite on pure #000000 black for additive blending. Heavenly Wheel Sever at contact: a tangible forward-rolling three-layer cutting weapon in shallow perspective, not a magic circle. The large rear/outer wheel is assembled from three thick molten fire blades and deforms into an ellipse against the target plane; the middle layer is six cold silver echo-feather blades scissoring inward; the small front/inner hub is a toothed violet-blue lightning cutter locking shut and shedding three charged metal teeth. Show real blade thickness, occlusion, centrifugal ember droplets, tangent silver chips, and arcs only between teeth. Premium original HD-2D cinematic JRPG lighting, black center channel and generous outer padding. No character, UI, text, border, icon frame, flat concentric rings, clock ticks, radial grid, portal, mandala, white featureless explosion, montage, or watermark.`

## 27. 霜蘭流火 (`frost_orchid_flame`)

1. **意境核心**：冰蘭先把毒液封存在透明花瓣內，火刃再由下向上劈開花心；裂瓣落地不是消失，而是把保存的毒層種成腐蝕花區。
2. **開場環境反應（0.00–0.14）**：地面溫度驟降，六條霜脈由外向中心爬行；紫綠毒霧被冷凝成可見液珠，沿霜脈被吸向尚未成形的花心。背景熱流被壓低，近地面形成薄冷霧。
3. **語意物體組成（0.10–0.32）**：六片不同角度的冰晶花瓣由霜脈向上長出，前景兩瓣較大並遮住後瓣；每瓣內封有一至兩顆紫綠毒珠與毛細裂紋。中央由一條細橙線逐步鍛厚成向上的火刃，花瓣與火刃是具體物體而非符號。
4. **連續動作與 2.5D（0.28–0.66）**：冰蘭先完全閉合，把毒珠壓向花心；後景花瓣先結霜，中景毒珠受壓變扁，前景火刃從地面穿入並沿中央上切。火刃前緣照亮近側冰厚，背側仍保留深藍陰影，裂線由下而上追隨刀鋒。
5. **命中變形／破壞（0.64–0.84）**：火刃突破花頂，六瓣依序向外爆開成大塊冰片；受熱邊緣先融出水亮薄層，再碎裂。紫綠毒珠從冰內被擠出，隨落地冰瓣砸出五瓣不對稱腐花液泊；命中核心保持可見火刃，不做白球。
6. **餘韻物質（0.82–1.00）**：地面留下冒冷煙的融冰片、五瓣紫綠腐蝕液泊、橙紅火刃切痕與少量被毒染色的水珠。腐花邊緣緩慢起泡，冰片持續融化而非同步淡出。
7. **光／材質／色彩轉換**：冰瓣由深藍透明體轉成青白裂面，毒珠為內部吸光的紫綠，火刃由暗橙鋼芯升到橙白邊緣。命中時冷光與火光在裂面上形成分離反射；落地後整體降為暗紫綠與低亮橙痕。
8. **粒子物理來源**：霜塵由花瓣表面升華；大冰片由六瓣斷裂；毒滴由封存毒珠被擠出；火星由火刃擦過冰內礦物；腐蝕泡只從落地毒液生成。
9. **禁止捷徑**：禁止完整花 icon 放大、均勻六瓣法陣、藍紫橙粒子隨機混合、通用冰爆、無毒珠保存過程、火焰覆蓋全部冰材質、中心過曝。
10. **Impact material prompt**：`Square 2.5D cinematic JRPG combat VFX material sprite on pure #000000 black for additive blending. Frost Orchid Flame at the upward cut: a concrete six-petal translucent ice orchid is being split from bottom to top by one narrow forged orange-white fire blade. The nearest ice petals are large and overlap the rear petals; each petal visibly contains trapped violet-green toxin droplets and capillary cracks. Petals break sequentially into large melting plates, squeezing poison downward where fallen fragments seed an irregular five-petal corrosive puddle. Cold blue subsurface ice, hot orange reflected edges, toxic purple-green liquid, readable material transformation and generous black padding. Premium original HD-2D cinematic JRPG VFX. No character, UI, text, border, icon frame, pasted flower emblem, magic circle, radial grid, uniform particle burst, white center explosion, montage, or watermark.`

## 28. 春庭載陽 (`sunlit_spring_court`)

1. **意境核心**：一座由光、泉水與植物構成的短暫春庭依序完成淨化、治療、護盾；三層功能以庭拱、水盆、日輪冠三個具體建築／自然物件呈現。
2. **開場環境反應（0.00–0.14）**：地面暗塵先被一股低矮清風向外掃開，灰白負面薄屑從中心剝離；兩側地面各冒出一小束嫩芽，中央乾裂處滲出一線清水，後景亮度像晨光逐步升高。
3. **語意物體組成（0.10–0.34）**：左右藤枝先向上生長並互相靠攏，形成有開口的尖拱庭門；地面水線聚成淺而有厚度的石質泉盆，盆內水面向中心回流；拱門上方由數片金色光葉托起一枚小型實體日輪冠。三者不靠同心圓連接。
4. **連續動作與 2.5D（0.30–0.68）**：前景灰白薄屑被庭門向外推出；中景泉水由盆緣向內匯流，青綠水滴上升穿過治療區；後景日輪冠沿拱門中軸升高，投下三束由遠至近的暖光。藤葉受光依次展開，近景葉片遮住泉盆下緣。
5. **命中變形／破壞（0.66–0.82）**：日輪冠抵達拱頂時，三束光落入泉盆，水面向上翻成一片薄金綠穹膜並扣在庭門內側；不是爆炸，而是溢補凝固成盾。殘留灰屑在穹膜接觸時裂成暗粉並被泉水帶走。
6. **餘韻物質（0.80–1.00）**：庭門藤葉留下少量金色露滴，泉盆回落成淺水痕，穹膜邊緣凝成數枚貼附的盾點；灰色淨化粉末沿水痕流出畫面。
7. **光／材質／色彩轉換**：開場以低飽和青灰為主，淨化後轉成翡翠與嫩綠，日輪提供蜜金主光。盾膜是透明金綠而非純白；石盆維持米灰材質，葉脈、露滴和水面各有不同高光頻率。
8. **粒子物理來源**：灰白薄屑來自被剝離的負面狀態；青綠水滴來自泉盆回流；金露滴從受光葉尖滑落；盾點由溢出的水光凝在穹膜邊緣；不添加無來源星塵。
9. **禁止捷徑**：禁止三個治療圓環疊加、generic holy beam、植物 mandala、全綠粒子雨、貼上太陽花 icon、白光洗掉庭院結構、把三功能做成三格簡報。
10. **Impact material prompt**：`Square 2.5D cinematic JRPG healing finisher material sprite on pure #000000 black for additive blending. Sunlit Spring Court at shield formation: a tangible open pointed garden arch grown from two layered jade vines frames a shallow stone spring basin in the midground; three warm sunbeams descend from a small gold sun-crown supported above the arch and strike inward-flowing teal water, folding that water upward into one thin translucent gold-green protective canopy. Foreground gray cleanse flakes are being swept outward, near leaves overlap the basin, gold dew gathers on leaf tips, and the architecture, water, foliage, and shield remain separately readable. Premium original HD-2D cinematic JRPG lighting, generous black padding. No character, UI, text, border, icon frame, healing rings, magic circle, mandala, generic holy column, random sparkles, white overexposure, montage, or watermark.`

## 29. 同脈來復 (`returning_shared_pulse`)

1. **意境核心**：血契先把多方傷害收進一個生命結，慈光再把結打開，復甦之靈沿最短路徑把生命送回最低血目標；動作必須可讀為「內收傷害、轉色、定向返還」。
2. **開場環境反應（0.00–0.12）**：三個不同方向的暗紅傷害痕讓周圍空氣向中心凹陷；地面影子被拉成三角形，遠景暖光暫時變暗，只在預定返還方向留下極細金線。
3. **語意物體組成（0.08–0.30）**：三條有脈搏粗細變化的血晶導管從三角頂點向中心生長，中心編成一個雙弧生命結；導管不閉合成法陣。生命結內側由一枚小型金白慈光種子和一枚半透明綠金靈核逐步成形。
4. **連續動作與 2.5D（0.26–0.66）**：後景血晶點先沿導管向中心移動，中景第二路傷害稍晚到達，前景第三路以較大晶點掠過鏡頭。生命結每收一股就收緊一次；慈光種子從暗金升亮，靈核繞結半周後停到最低血方向的導引線入口。
5. **命中變形／破壞（0.64–0.82）**：中心生命結被慈光從內側撐開，暗紅晶體不爆散，而是融成金橙液滴；靈核帶著最窄、最亮的一束回復脈衝沿指定方向離場。其餘兩條導管回彈成較弱同心「波瓣」，不是完整圓環。
6. **餘韻物質（0.80–1.00）**：留下一小段由紅轉金的脈管皮、沿返還路徑落下的金橙液滴，以及半透明綠金靈核的短弧尾跡；中心只剩逐漸鬆開的暗紅纖維。
7. **光／材質／色彩轉換**：入場傷害是深紅血晶與暗紫陰影，慈光種子提供局部暖金內光；轉換瞬間由紅晶變成金橙液滴，返還靈核帶淡綠輪廓。白色只存在種子核心，不得吃掉脈管方向。
8. **粒子物理來源**：紅晶點來自三條傷害導管；金橙液滴由生命結融解；綠金小屑由靈核加速剝落；暗纖維來自生命結鬆開；不使用任意星爆。
9. **禁止捷徑**：禁止紅金雙色圓環、心形 icon 貼圖、全向治療波、沒有最低血方向的均勻爆散、隨機花瓣、通用中心白爆、三條脈管同時無節奏淡入。
10. **Impact material prompt**：`Square 2.5D cinematic JRPG healing finisher material sprite on pure #000000 black for additive blending. Returning Shared Pulse at the conversion moment: three tangible dark-red crystalline lifeline tubes arrive from different depth planes and knot into one tense double-arc life clasp at center. A small warm gold mercy seed inside is forcing the clasp open, melting red crystal into gold-orange healing droplets, while one translucent jade-gold spirit core departs along the single narrow brightest guidance line toward the lowest-health direction. Show inward damage flow and outward targeted return in one causal frame, with foreground crystal scale larger than rear lines, controlled internal light, and generous black margins. No character, UI, text, border, icon frame, heart-logo decal, full circular pulse, magic circle, concentric rings, radial grid, random petals, white explosion, montage, or watermark.`

## 30. 守一共脈 (`guarding_shared_pulse`)

1. **意境核心**：一面嵌有雙脈管的重盾把角色釘在原地；承傷累積在盾內，反擊時盾面張成向前楔，同一股壓力從背面擠出較小治療脈環送向友方。
2. **開場環境反應（0.00–0.14）**：盾前地面被壓出一道短凹槽，碎石向兩側滾而不是向後飛；後方友方方向亮起一點乳白低光。空氣中的紅晶點沿盾緣向下沉，強調不退。
3. **語意物體組成（0.10–0.32）**：中央先立起一條厚金屬盾軸並插入地面，左右兩片銅金盾面沿軸向外展開；盾內兩條暗紅導槽從肩位彎入中心，構成非寫實雙弧心脈。每條線都鑲在盾材內，不是浮空符號。
4. **連續動作與 2.5D（0.28–0.68）**：前景攻擊撞上盾面，盾軸向地面再沉一段，左右盾面只內凹不後退；中景紅晶點沿導槽累積到中心，後景乳白小脈管同步充盈。近側盾緣遮住遠側，地面凹槽朝鏡頭延伸，顯示重量。
5. **命中變形／破壞（0.64–0.84）**：累積值滿時，左右盾面沿中央鉸鏈向前張開成尖楔，把受擊碎片與金屑推出；同時盾背壓出一枚小型乳白脈環，沿後方友軍方向滑走。盾軸頂端出現永久凹痕但不崩碎。
6. **餘韻物質（0.82–1.00）**：地面留下盾軸凹槽、數枚沉重銅屑和少量暗紅結晶；治療脈環離場後只留兩滴乳白光液，盾面回合但保留命中凹痕。
7. **光／材質／色彩轉換**：盾材是舊金銅與深鐵陰影，受擊主光為暖白，積蓄導槽由暗紅轉亮紅；反擊楔前緣轉為金白，背面治療脈環是低亮乳白加淡金，不用綠色泛光混淆盾體。
8. **粒子物理來源**：碎石來自盾軸壓入地面；銅屑來自盾面受擊凹痕；紅晶點由內嵌導槽剝落；乳白液滴由治療脈環尾端滴下；禁止空中隨機火花。
9. **禁止捷徑**：禁止心形徽章懸空、通用圓盾泡泡、紅色 aura、全向震波、盾與治療同時爆白、把 icon 圓框放大、沒有前後方向的對稱粒子雨。
10. **Impact material prompt**：`Square 2.5D cinematic JRPG combat VFX material sprite on pure #000000 black for additive blending. Guarding Shared Pulse at the counter-release: a heavy old-gold and dark-iron shield is visibly anchored into a cracked ground groove by one thick vertical spine. Two shield halves containing embedded crimson lifeline channels are hinged open into a forward striking wedge, ejecting concrete impact chips and bronze shavings toward the enemy, while pressure from the shield back forms one much smaller ivory-gold healing pulse departing in the opposite ally direction. Preserve shield thickness, dented metal, foreground/rear overlap, red stored energy inside real channels, and a readable two-direction force exchange. Premium original HD-2D cinematic JRPG lighting, generous black padding. No character, UI, text, border, icon frame, floating heart emblem, bubble shield, magic circle, concentric rings, radial grid, symmetric particle rain, white overexposure, montage, or watermark.`

## 31. 扶搖月輪 (`gale_moon_arc`)

1. **意境核心**：高速繞場留下的是一條具方向與缺口的風斬軌跡；三個風標逐段確認圓周後，真正的殺招才從圓心推出一枚巨大月刃，把軌跡向外撕開。
2. **開場環境反應（0.00–0.12）**：地面灰塵沿圓周切線被掃成一個有缺口的弧帶，草葉分三次朝不同切線方向伏倒；中心保持靜止暗區，遠景月光只照亮弧帶外緣。
3. **語意物體組成（0.08–0.30）**：一條青白風線從缺口起跑，繞場生長成帶刃厚的圓周斬痕，但保留起終點間的明確斷口。三枚金色箭羽形風標依次釘在圓周不同位置；中心由兩道相背弧線合成厚實銀青月刃胚。
4. **連續動作與 2.5D（0.26–0.66）**：後景第一段弧先亮，中景第二風標接力，前景第三段弧以最大比例掠過鏡頭下緣；圓周上的稀疏速度點始終沿切線移動。三標全亮後，月刃胚在中心旋轉半圈，刃面由側薄變成可見厚度並對準外側缺口。
5. **命中變形／破壞（0.64–0.82）**：巨大月刃由圓心沿缺口方向高速推出，先切斷圓周風痕，再把兩端撕成向外翻卷的風帶；命中面形成一條扁長新月斷口，而不是圓形爆炸。近景風標被衝擊削掉一角。
6. **餘韻物質（0.80–1.00）**：留下斷裂的青白風帶、三枚逐漸熄滅的金色方向標、幾片扁長銀色月屑與沿地面滑行的薄霧；所有餘韻沿原切線或月刃前進方向離場。
7. **光／材質／色彩轉換**：風痕是低亮青綠邊光，月刃為銀白主光帶淡藍陰面，風標是克制暖金。推出瞬間銀白只集中於刃前緣；撕裂後降為冷青薄霧，不能把整個圓周均勻點亮。
8. **粒子物理來源**：速度點由風痕前緣剝離；月屑由月刃擦切命中面；金屑由風標被削角；薄霧由風帶壓低地表水氣；不添加無來源星空粒子。
9. **禁止捷徑**：禁止月牙 icon 放大、完整對稱圓環、鐘面刻度、通用風渦、圓心白爆、無方向的青色粒子圈、三風標同時出現、把「繞場」做成靜態 mandala。
10. **Impact material prompt**：`Square 2.5D cinematic JRPG combat VFX material sprite on pure #000000 black for additive blending. Gale Moon Arc at the decisive sever: a thick silver-cyan crescent blade has just launched from a dark center through the deliberate gap of a tangible circular wind-cut trail, ripping the trail ends outward into two curling teal ribbons. Three small gold arrow-feather wind markers sit at different depth positions on the track, with the nearest marker losing one corner into sparks; sparse velocity motes follow the actual tangent and flat silver moon chips follow the blade direction. The circle must read as a broken movement path, never as a magic diagram. Strong asymmetrical exit direction, premium original HD-2D cinematic JRPG material and layered occlusion, generous black padding. No character, UI, text, border, icon frame, pasted crescent emblem, closed symmetric ring, ticks, radial grid, vortex, mandala, center explosion, montage, or watermark.`

## 32. 綿息雷音 (`breathing_thunder_echo`)

1. **意境核心**：AP 星脈先像導電根系一樣供能；每枚回聲彈落在網路上成為實體雷標，之後雷不是隨機降下，而是逐標垂直擊落並沿既有導線串成一次連鎖。
2. **開場環境反應（0.00–0.14）**：地面出現數條由中心向外分岔的淡青導電濕痕，周圍金屬碎屑朝最近分枝微微轉向；上方暗雲只在節點正上方形成窄陰影，不先出現雷柱。
3. **語意物體組成（0.10–0.34）**：細青 AP 脈線依「主幹→支幹→末端」順序長出；四枚金色回聲彈沿不同弧線飛入，各自在脈線交會處壓成菱形金屬雷標。雷標底部伸出兩個導電鉤，確實扣住脈線。
4. **連續動作與 2.5D（0.30–0.68）**：後景第一彈先落標，中景兩彈左右錯時落下，前景第四彈以較大比例穿過鏡頭下方再扣住近端支線。每落一標，青光從 AP 主幹跑到該點；上方細紫電先在對應標的垂直軸聚集，尚未命中其他位置。
5. **命中變形／破壞（0.64–0.84）**：四支紫藍雷槍依標記順序垂直貫下，雷標被壓成發白的扁菱形並把碎片向上彈；最後主幹用一條細而清楚的橫向電弧串過四標，形成連鎖收尾。命中亮點分散在四個實體節點，不形成中央白球。
6. **餘韻物質（0.82–1.00）**：地面留下焦黑分枝脈線、四枚熔邊金屬雷標、向上飛回的青白針粒與兩三段逐漸熄滅的紫電；遠端節點先暗，近端最後暗。
7. **光／材質／色彩轉換**：AP 脈線是低亮青藍，回聲彈／雷標為暖金金屬，落雷是紫核配藍白邊。供能時金光沿青脈移動；雷擊時紫光只照亮相鄰地面與標面；餘韻轉為焦黑、暗金和稀薄青煙。
8. **粒子物理來源**：金色尾粒由回聲彈飛行摩擦剝落；紫電碎絲只從雷槍與雷標接觸點分叉；青白針粒由受熱雷標向上噴回；黑屑由地面脈線焦化剝落。
9. **禁止捷徑**：禁止隨機全屏落雷、通用雷法陣、圓形節點網格、沒有回聲彈落標過程、所有雷柱同時命中、中心過曝、把 icon 長槍直接放大、紫藍粒子亂灑。
10. **Impact material prompt**：`Square 2.5D cinematic JRPG combat VFX material sprite on pure #000000 black for additive blending. Breathing Thunder Echo at chained impact: a concrete branching cyan AP meridian network lies in shallow ground perspective, carrying warm gold current from its trunk into four physical diamond-shaped metal echo markers hooked onto separate junctions. Four narrow violet-blue lightning spears strike those markers at staggered depths; the nearest marker is flattened by contact and ejects hot cyan-white needles upward, while one thin lateral arc has just begun linking the struck markers in sequence. Preserve readable network hierarchy, individual marker materials, vertical depth spacing, localized light pools, scorched branches, and generous black margins. Premium original HD-2D cinematic JRPG VFX. No character, UI, text, border, icon frame, pasted spear emblem, circular node grid, magic circle, random full-screen lightning, simultaneous columns, center white explosion, montage, or watermark.`

const SVG_ASSETS = __TOWN_SVG_ASSETS__;
const REFERENCE_ASSETS = __TOWN_REFERENCE_ASSETS__;
const B2_REVIEW_ASSETS = __TOWN_B2_REVIEW_ASSETS__;
const B2_REFERENCE_ASSET = __TOWN_B2_REFERENCE_ASSET__;
const BASE_MAP_PREVIEW = __TOWN_BASE_MAP_PREVIEW__;

const B2_REVIEW_ITEMS = [
  ["material_yard_front_style_b2", "材料行 / MATERIAL YARD", "BUILDING · FRONT STYLE · 300 × 240"],
  ["player_forge_front_style_b2", "主角鐵匠鋪 / PLAYER FORGE", "BUILDING · FRONT STYLE · 360 × 316"],
  ["town_hall_front_style_base_v3", "村長家 / TOWN HALL", "BUILDING · MATERIAL-YARD BASE V3 · 342 × 288"],
  ["sword_soul_shop_front_style_base_v3", "劍魂商 / SWORD SOUL SHOP", "BUILDING · MATERIAL-YARD BASE V3 · 334 × 295"],
  ["equipment_blueprint_shop_front_style_base_v3", "裝備圖紙商 / BLUEPRINT SHOP", "BUILDING · MATERIAL-YARD BASE V3 · 334 × 295"],
  ["far_east_residence_front_style_base_v3", "東郊民宅 / EAST RESIDENCE", "BUILDING · MATERIAL-YARD BASE V3 · 298 × 331"],
  ["eternal_forge_monument_base_v4", "不滅火炬 / ETERNAL FLAME", "LANDMARK · MATERIAL-YARD BASE V4 · 345 × 560"],
  ["battle_portal_base_v4", "戰鬥傳送門 / BATTLE PORTAL", "LANDMARK · MATERIAL-YARD BASE V4 · 200 × 240"]
];

const C = {
  ink: "#10151D",
  panel: "#1B2029",
  stone: "#3B4148",
  stoneLight: "#676D72",
  gold: "#D99A2B",
  goldLight: "#FFD56A",
  fire: "#FF8A18",
  fireLight: "#FFE25A",
  portal: "#28A9FF",
  portalDark: "#124E9B",
  soul: "#A743FF",
  soulDark: "#3A1761",
  blueRoof: "#244C70",
  redRoof: "#793A32",
  wood: "#6B3E24",
  plaster: "#D2B78A",
  white: "#FFF4DA"
};

function rgb(hex) {
  const v = hex.replace("#", "");
  return {
    r: parseInt(v.slice(0, 2), 16) / 255,
    g: parseInt(v.slice(2, 4), 16) / 255,
    b: parseInt(v.slice(4, 6), 16) / 255
  };
}

function paint(hex, opacity = 1) {
  return [{ type: "SOLID", color: rgb(hex), opacity }];
}

function frame(parent, name, x, y, width, height, fill = null) {
  const node = figma.createFrame();
  node.name = name;
  node.resize(width, height);
  node.x = x;
  node.y = y;
  node.clipsContent = false;
  node.fills = fill ? paint(fill) : [];
  parent.appendChild(node);
  return node;
}

function component(parent, name, x, y, width, height) {
  const node = figma.createComponent();
  node.name = name;
  node.resize(width, height);
  node.x = x;
  node.y = y;
  node.clipsContent = false;
  node.fills = [];
  parent.appendChild(node);
  return node;
}

function rect(parent, name, x, y, width, height, fill, radius = 0, stroke = null, strokeWidth = 0) {
  const node = figma.createRectangle();
  node.name = name;
  node.resize(width, height);
  node.x = x;
  node.y = y;
  node.fills = paint(fill);
  node.cornerRadius = radius;
  if (stroke) {
    node.strokes = paint(stroke);
    node.strokeWeight = strokeWidth;
  }
  parent.appendChild(node);
  return node;
}

function ellipse(parent, name, x, y, width, height, fill, opacity = 1) {
  const node = figma.createEllipse();
  node.name = name;
  node.resize(width, height);
  node.x = x;
  node.y = y;
  node.fills = paint(fill, opacity);
  parent.appendChild(node);
  return node;
}

function triangle(parent, name, x, y, width, height, fill, rotation = 0) {
  const node = figma.createPolygon();
  node.name = name;
  node.pointCount = 3;
  node.resize(width, height);
  node.x = x;
  node.y = y;
  node.rotation = rotation;
  node.fills = paint(fill);
  parent.appendChild(node);
  return node;
}

async function text(parent, name, characters, x, y, size, fill = C.white, style = "Bold") {
  const node = figma.createText();
  node.name = name;
  node.fontName = { family: "Inter", style };
  node.characters = characters;
  node.fontSize = size;
  node.fills = paint(fill);
  node.x = x;
  node.y = y;
  parent.appendChild(node);
  return node;
}

function glow(node, color, radius = 26) {
  node.effects = [{
    type: "DROP_SHADOW",
    color: { ...rgb(color), a: 0.65 },
    offset: { x: 0, y: 0 },
    radius,
    spread: 4,
    visible: true,
    blendMode: "SCREEN"
  }];
}

function raster(parent, name, base64, x, y, width, height, locked = false) {
  const image = figma.createImage(figma.base64Decode(base64));
  const node = figma.createRectangle();
  node.name = name;
  node.resize(width, height);
  node.x = x;
  node.y = y;
  node.fills = [{ type: "IMAGE", imageHash: image.hash, scaleMode: "FIT" }];
  node.locked = locked;
  parent.appendChild(node);
  return node;
}

function plaque(parent, name, x, y, width, value, accent = C.gold, asComponent = false) {
  const root = asComponent
    ? component(parent, name, x, y, width, 68)
    : frame(parent, name, x, y, width, 68);
  rect(root, "Border", 0, 0, width, 62, C.gold, 8);
  rect(root, "Panel", 5, 5, width - 10, 52, C.panel, 5);
  ellipse(root, "Icon", 15, 15, 32, 32, accent);
  text(root, "Editable_Label", value, 58, 15, 24);
  return root;
}

function building(parent, options, asComponent = false) {
  const { name, x, y, width, height, roof, accent, chimney = false } = options;
  const root = asComponent
    ? component(parent, `Component/Building/${name}`, x, y, width, height)
    : frame(parent, `Building/${name}`, x, y, width, height);
  rect(root, "Foundation", 16, height - 38, width - 32, 38, C.stone, 4);
  rect(root, "Wall", 28, 120, width - 56, height - 150, C.plaster, 6, C.wood, 6);
  triangle(root, "Roof", 0, 10, width, 190, roof);
  rect(root, "Roof_Beam", 22, 132, width - 44, 14, C.wood, 3);
  rect(root, "Door_Frame", width / 2 - 44, height - 170, 88, 140, C.wood, 8, C.gold, 3);
  rect(root, "Door", width / 2 - 36, height - 160, 72, 130, C.panel, 6);
  for (let i = 0; i < 3; i += 1) {
    const wx = 48 + i * ((width - 150) / 2);
    rect(root, `Window_${i + 1}_Frame`, wx, height - 220, 54, 70, C.wood, 6);
    const pane = rect(root, `Window_${i + 1}_Glow`, wx + 7, height - 213, 40, 56, accent, 3);
    pane.opacity = 0.65;
    rect(root, `Window_${i + 1}_V`, wx + 25, height - 213, 4, 56, C.wood);
    rect(root, `Window_${i + 1}_H`, wx + 7, height - 188, 40, 4, C.wood);
  }
  if (chimney) {
    rect(root, "Chimney", width - 90, 44, 38, 94, C.stone, 4, C.gold, 2);
    ellipse(root, "Smoke_1", width - 96, 8, 48, 34, C.stoneLight, 0.5);
    ellipse(root, "Smoke_2", width - 75, -18, 56, 40, C.stoneLight, 0.3);
  }
  const signRoot = frame(root, "Editable_Sign", width / 2 - 125, 150, 250, 62);
  rect(signRoot, "Gold_Border", 0, 0, 250, 58, C.gold, 7);
  rect(signRoot, "Blank_Plaque", 5, 5, 240, 48, C.panel, 4);
  return root;
}

function eternalFlame(parent, x, y, scale = 1, asComponent = false) {
  const root = asComponent
    ? component(parent, "Component/Building/EternalFlame", x, y, 520 * scale, 620 * scale)
    : frame(parent, "Building/EternalFlame", x, y, 520 * scale, 620 * scale);
  rect(root, "Foundation_3", 40 * scale, 570 * scale, 440 * scale, 50 * scale, C.stone, 4);
  rect(root, "Foundation_2", 80 * scale, 530 * scale, 360 * scale, 42 * scale, C.stoneLight, 4);
  rect(root, "Foundation_1", 125 * scale, 495 * scale, 270 * scale, 38 * scale, C.stone, 4);
  rect(root, "Pillar", 165 * scale, 215 * scale, 190 * scale, 290 * scale, C.stone, 8, C.gold, 5);
  rect(root, "Banner_Left", 125 * scale, 310 * scale, 54 * scale, 145 * scale, C.redRoof, 3, C.gold, 3);
  rect(root, "Banner_Right", 341 * scale, 310 * scale, 54 * scale, 145 * scale, C.redRoof, 3, C.gold, 3);
  rect(root, "Brazier_Rim", 105 * scale, 175 * scale, 310 * scale, 62 * scale, C.gold, 18, C.ink, 5);
  const aura = ellipse(root, "Fire_Glow", 145 * scale, 0, 230 * scale, 230 * scale, C.fire, 0.2);
  glow(aura, C.fire, 42 * scale);
  triangle(root, "Flame_Outer", 170 * scale, 20 * scale, 180 * scale, 195 * scale, C.fire);
  triangle(root, "Flame_Inner", 215 * scale, 85 * scale, 95 * scale, 110 * scale, C.fireLight);
  for (let i = 0; i < 3; i += 1) {
    ellipse(root, `Rune_${i + 1}`, 244 * scale, (330 + i * 62) * scale, 32 * scale, 32 * scale, C.fire);
  }
  return root;
}

function portal(parent, x, y, asComponent = false) {
  const root = asComponent
    ? component(parent, "Component/Building/BattlePortal", x, y, 480, 470)
    : frame(parent, "Building/BattlePortal", x, y, 480, 470);
  rect(root, "Steps", 20, 420, 440, 50, C.stone, 5);
  rect(root, "Arch_Left", 55, 75, 70, 360, C.stone, 12, C.gold, 4);
  rect(root, "Arch_Right", 355, 75, 70, 360, C.stone, 12, C.gold, 4);
  triangle(root, "Arch_Top", 55, 0, 370, 185, C.stone);
  const core = ellipse(root, "Portal_Core", 120, 90, 240, 330, C.portal, 0.85);
  glow(core, C.portal, 40);
  ellipse(root, "Portal_Inner", 160, 132, 160, 250, C.portalDark, 0.85);
  ellipse(root, "Portal_Swirl", 195, 190, 90, 130, C.white, 0.35);
  return root;
}

function soulOrb(parent, name, x, y, color, glyph) {
  const root = component(parent, `SoulOrb/${name}`, x, y, 120, 150);
  const aura = ellipse(root, "Aura", 10, 10, 100, 100, color, 0.18);
  glow(aura, color, 22);
  ellipse(root, "Outer_Ring", 22, 22, 76, 76, C.gold);
  ellipse(root, "Core", 29, 29, 62, 62, color);
  text(root, "Glyph", glyph, 46, 38, 28);
  text(root, "Editable_Name", name, 15, 118, 16);
  return root;
}

function progressCard(parent, name, x, y, title, accent) {
  const root = component(parent, name, x, y, 420, 240);
  rect(root, "Border", 0, 0, 420, 240, C.gold, 12);
  rect(root, "Panel", 6, 6, 408, 228, C.panel, 8);
  rect(root, "Accent", 6, 6, 10, 228, accent, 5);
  text(root, "Title", title, 30, 24, 26);
  text(root, "Level", "Lv. 1", 320, 26, 22, accent);
  rect(root, "Progress_Track", 30, 92, 360, 24, C.ink, 12);
  rect(root, "Progress_Value", 30, 92, 210, 24, accent, 12);
  text(root, "Next_Unlock", "下一級解鎖：可編輯文字", 30, 140, 18, C.white, "Regular");
  return root;
}

function importSvg(parent, key, name, x, y, maxWidth) {
  if (!SVG_ASSETS[key]) return null;
  const node = figma.createNodeFromSvg(SVG_ASSETS[key]);
  node.name = name;
  node.x = x;
  node.y = y;
  if (node.width > maxWidth) {
    const ratio = maxWidth / node.width;
    node.resize(node.width * ratio, node.height * ratio);
  }
  parent.appendChild(node);
  return node;
}

function sky(parent, width, height) {
  const background = rect(parent, "BG/SkyGradient", 0, 0, width, height, "#6E9BD1");
  background.fills = [{
    type: "GRADIENT_LINEAR",
    gradientTransform: [[0, 1, 0], [-1, 0, 1]],
    gradientStops: [
      { position: 0, color: { ...rgb("#6E9BD1"), a: 1 } },
      { position: 1, color: { ...rgb("#F6C68E"), a: 1 } }
    ]
  }];
  for (let i = 0; i < 12; i += 1) {
    ellipse(parent, `BG/Cloud_${i + 1}`, 130 + i * 420, 100 + (i % 3) * 55, 250, 45, C.white, 0.5);
  }
  for (let i = 0; i < 9; i += 1) {
    triangle(parent, `BG/Mountain_${i + 1}`, i * 630, 280 + (i % 2) * 70, 650, 270, i % 2 ? "#60779A" : "#7D8FB0");
  }
}

function placeInstance(parent, source, name, x, y) {
  const node = source.createInstance();
  node.name = name;
  node.x = x;
  node.y = y;
  parent.appendChild(node);
  return node;
}

async function buildCover(page) {
  const root = frame(page, "Town / Eternal Forge / Editable v2 / Cover", 0, 0, 2560, 1080, C.ink);
  rect(root, "Gold_Rule", 120, 160, 220, 14, C.gold, 7);
  await text(root, "Title", "鐵匠之城", 120, 220, 112, C.goldLight);
  await text(root, "Subtitle", "ETERNAL FORGE TOWN · EDITABLE SOURCE", 128, 360, 34);
  await text(root, "Description", "橫向城鎮地圖 · 不滅火炬 · 鐵匠成長 · 劍魂精煉", 128, 430, 28, C.stoneLight, "Regular");
  eternalFlame(root, 1700, 210, 1.15);
  Object.entries(C).slice(0, 12).forEach(([name, color], i) => {
    const x = 128 + (i % 6) * 210;
    const y = 620 + Math.floor(i / 6) * 130;
    rect(root, `Token/${name}`, x, y, 180, 76, color, 10);
    text(root, `TokenLabel/${name}`, name, x, y + 86, 17, C.white, "Regular");
  });
  return root;
}

async function buildWorld(page, buildings, markers) {
  const root = frame(page, "Town / Eternal Forge / Editable v2 / World / 5200x720", 0, 0, 5200, 720, "#6E9BD1");
  root.clipsContent = true;
  sky(root, 5200, 720);
  rect(root, "FG/Road", 0, 590, 5200, 130, "#7B6A54");
  rect(root, "FG/Road_Highlight", 0, 590, 5200, 14, C.gold);
  for (let i = 0; i < 48; i += 1) {
    rect(root, `FG/Stone_${i + 1}`, 20 + i * 110, 625 + (i % 2) * 28, 82, 22, i % 2 ? "#665949" : "#8C7B63", 7);
  }
  placeInstance(root, buildings.MaterialYard, "Instance/Building/MaterialYard", 210, 240);
  placeInstance(root, buildings.PlayerBlacksmith, "Instance/Building/PlayerBlacksmith", 760, 150);
  placeInstance(root, buildings.EternalFlame, "Instance/Building/EternalFlame", 1510, 20);
  placeInstance(root, buildings.BattlePortal, "Instance/Building/BattlePortal", 2060, 160);
  placeInstance(root, buildings.TownHall, "Instance/Building/TownHall", 2620, 135);
  placeInstance(root, buildings.SwordSoulShop, "Instance/Building/SwordSoulShop", 3370, 170);
  placeInstance(root, buildings.BlueprintResearch, "Instance/Building/BlueprintResearch", 4050, 220);
  placeInstance(root, buildings.SoulRefinery, "Instance/Building/SoulRefinery", 4610, 235);
  [
    ["材料行", 210, 190],
    ["主角家／鐵匠鋪", 820, 90],
    ["不滅火炬", 1580, 20],
    ["戰鬥傳送門", 2120, 80],
    ["村長家", 2690, 75],
    ["劍魂商", 3440, 110],
    ["圖紙研究室", 4010, 160],
    ["劍魂精煉所", 4590, 175]
  ].forEach(([label, x, y]) => {
    placeInstance(root, markers[label], `Instance/LocationMarker/${label}`, x, y);
  });
  [
    ["材料行", 210, 240, 520, 390],
    ["主角家／鐵匠鋪", 760, 150, 720, 480],
    ["不滅火炬", 1510, 20, 494, 589],
    ["戰鬥傳送門", 2060, 160, 480, 470],
    ["村長家", 2620, 135, 690, 495],
    ["劍魂商", 3370, 170, 630, 460],
    ["圖紙研究室", 4050, 220, 520, 410],
    ["劍魂精煉所", 4610, 235, 480, 395]
  ].forEach(([label, x, y, width, height]) => {
    const zone = rect(root, `Interaction/${label}`, x, y, width, height, C.white, 10, C.gold, 3);
    zone.opacity = 0.08;
    zone.dashPattern = [12, 10];
  });
  const guide = rect(root, "GUIDES/Viewport_1920", 1640, 0, 1920, 720, C.white);
  guide.fills = [];
  guide.strokes = paint(C.white, 0.45);
  guide.strokeWeight = 4;
  guide.dashPattern = [16, 12];
  return root;
}

async function buildBuildings(page) {
  const root = frame(page, "Town / Eternal Forge / Editable v2 / Building Components", 0, 0, 4200, 2600, C.ink);
  const items = [
    ["MaterialYard", 520, 390, C.blueRoof, C.gold, false],
    ["PlayerBlacksmith", 720, 480, C.blueRoof, C.fire, true],
    ["TownHall", 690, 495, C.redRoof, C.gold, false],
    ["SwordSoulShop", 630, 460, C.soulDark, C.soul, false],
    ["BlueprintResearch", 520, 410, C.blueRoof, C.portal, false],
    ["SoulRefinery", 480, 395, C.soulDark, C.soul, true]
  ];
  const registry = {};
  items.forEach((item, i) => {
    registry[item[0]] = building(root, {
      name: item[0],
      x: 100 + (i % 3) * 1250,
      y: 140 + Math.floor(i / 3) * 780,
      width: item[1],
      height: item[2],
      roof: item[3],
      accent: item[4],
      chimney: item[5]
    }, true);
  });
  registry.EternalFlame = eternalFlame(root, 100, 1700, 0.95, true);
  registry.BattlePortal = portal(root, 900, 1760, true);
  importSvg(root, "town_buildings", "VectorSource/TownBuildings", 1650, 1540, 1400);
  importSvg(root, "eternal_flame", "VectorSource/EternalFlame", 2600, 1480, 520);
  return { root, registry };
}

async function buildUi(page) {
  const root = frame(page, "Town / Eternal Forge / Editable v2 / UI Components", 0, 0, 2400, 1600, C.ink);
  const markerRegistry = {};
  ["材料行", "主角家／鐵匠鋪", "不滅火炬", "戰鬥傳送門", "村長家", "劍魂商", "圖紙研究室", "劍魂精煉所"].forEach((value, i) => {
    markerRegistry[value] = plaque(root, `Component/LocationMarker/${value}`, 100 + (i % 3) * 700, 100 + Math.floor(i / 3) * 130, 560, value, i === 2 ? C.fire : i === 3 ? C.portal : i >= 5 ? C.soul : C.gold, true);
  });
  progressCard(root, "Component/EternalFlameProgress", 100, 560, "不滅火炬", C.fire);
  progressCard(root, "Component/BlacksmithProgress", 570, 560, "鐵匠技術", C.gold);
  const loadout = component(root, "Component/PortalLoadout", 1040, 560, 1120, 410);
  rect(loadout, "Border", 0, 0, 1120, 410, C.gold, 14);
  rect(loadout, "Panel", 6, 6, 1108, 398, C.panel, 10);
  text(loadout, "Title", "傳送門配置", 32, 24, 30);
  ["武器", "治療劍魂", "劍魂 1", "劍魂 2", "劍魂 3"].forEach((slot, i) => {
    const x = 32 + i * 150;
    rect(loadout, `Slot/${slot}`, x, 100, 124, 124, C.ink, 10, i === 1 ? "#49C878" : C.soul, 4);
    text(loadout, `SlotLabel/${slot}`, slot, x + 8, 240, 17, C.white, "Regular");
  });
  rect(loadout, "FinisherPreview", 810, 100, 270, 180, C.soulDark, 12, C.soul, 4);
  text(loadout, "FinisherTitle", "終結技預覽", 840, 122, 22);
  text(loadout, "FinisherName", "絕對零度的千刃殺", 834, 188, 21, C.portal);
  text(loadout, "Formula", "天賜效果 + 終結技 + Combo", 810, 315, 18, C.stoneLight, "Regular");
  importSvg(root, "town_ui_icons", "VectorSource/TownUIIcons", 100, 1060, 2100);
  return { root, markers: markerRegistry };
}

async function buildTokens(page) {
  const root = frame(page, "Town / Eternal Forge / Editable v2 / Icons and Tokens", 0, 0, 2200, 1400, C.ink);
  await text(root, "Heading", "劍魂與設計 Token", 100, 80, 48, C.goldLight);
  [
    ["Fire", C.fire, "火"],
    ["Ice", C.portal, "冰"],
    ["Storm", "#D5C3FF", "雷"],
    ["Venom", "#7BCB43", "毒"],
    ["Healing", "#49C878", "癒"]
  ].forEach((item, i) => soulOrb(root, item[0], 100 + i * 260, 190, item[1], item[2]));
  Object.entries(C).forEach(([name, color], i) => {
    const x = 100 + (i % 6) * 330;
    const y = 520 + Math.floor(i / 6) * 150;
    rect(root, `Color/${name}`, x, y, 280, 78, color, 10);
    text(root, `ColorLabel/${name}`, `${name}  ${color}`, x, y + 88, 17, C.white, "Regular");
  });
  importSvg(root, "town_ui_icons", "VectorSource/IconSheet", 100, 1030, 1900);
  return root;
}

async function buildReferences(page) {
  const root = frame(page, "Town / Eternal Forge / Editable v2 / Raster References (Locked)", 0, 0, 4200, 2500, "#222222");
  await text(root, "Warning", "參考圖（鎖定）— 可移動與替換，但不是可編輯向量", 80, 50, 34, C.goldLight);
  let index = 0;
  for (const [name, base64] of Object.entries(REFERENCE_ASSETS)) {
    const image = figma.createImage(figma.base64Decode(base64));
    const node = figma.createRectangle();
    node.name = `_REF/${name}`;
    node.resize(1900, 820);
    node.x = 80 + (index % 2) * 2000;
    node.y = 140 + Math.floor(index / 2) * 980;
    node.fills = [{ type: "IMAGE", imageHash: image.hash, scaleMode: "FIT" }];
    node.opacity = 0.35;
    node.locked = true;
    root.appendChild(node);
    await text(root, `ReferenceLabel/${name}`, name, node.x, node.y + 840, 22, C.white, "Regular");
    index += 1;
  }
  return root;
}

async function buildB2Review(page) {
  const root = frame(
    page,
    "Town / Base Modular Buildings + Town Map / FAST IMPORT",
    0,
    0,
    5200,
    4300,
    "#10151A"
  );
  await text(root, "Title", "TOWN / BASE MODULAR BUILDINGS + TOWN MAP", 100, 56, 54);
  await text(
    root,
    "Subtitle",
    "Runtime composition｜Locked A 背景排版｜Base 前景可替換｜y=672 共用基線",
    102,
    126,
    25,
    "#A5B0B8",
    "Regular"
  );
  await text(root, "ReferenceHeading", "01 / FULL MAP PLACEMENT AUDIT · 1942 × 809", 100, 206, 30, C.goldLight);
  raster(root, "Map/Full_Runtime_Composition", BASE_MAP_PREVIEW, 100, 250, 3884, 1618, true);

  await text(root, "ChecklistHeading", "PLACEMENT CHECK", 4100, 250, 30, C.white);
  const rules = [
    "1  Foundation y=672",
    "2  No stretched object",
    "3  No accidental gap",
    "4  No facade collision",
    "5  Background unchanged",
    "6  Portal + flame read as one",
    "7  Neutral Base lighting",
    "8  Each object replaceable"
  ];
  for (let index = 0; index < rules.length; index += 1) {
    await text(root, `Checklist/${index + 1}`, rules[index], 4100, 320 + index * 64, 23, "#A5B0B8", "Regular");
  }
  rect(root, "FastImportNote", 4070, 900, 1030, 300, "#1A2229", 22, "#40505D", 3);
  await text(root, "FastImportTitle", "FAST IMPORT", 4110, 948, 27, C.goldLight);
  await text(
    root,
    "FastImportBody",
    "重跑只替換本區。",
    4110,
    1044,
    22,
    C.white,
    "Regular"
  );
  await text(
    root,
    "FastImportBody2",
    "八張圖皆為獨立 layer。",
    4110,
    1096,
    22,
    "#A5B0B8",
    "Regular"
  );

  await text(root, "CandidateHeading", "02 / ISOLATED BASE OBJECTS", 100, 1950, 34, C.goldLight);
  const cardWidth = 1220;
  const cardHeight = 1050;
  const gap = 40;
  const startY = 2000;
  for (let index = 0; index < B2_REVIEW_ITEMS.length; index += 1) {
    const [key, label, target] = B2_REVIEW_ITEMS[index];
    const column = index % 4;
    const row = Math.floor(index / 4);
    const x = 100 + column * (cardWidth + gap);
    const y = startY + row * (cardHeight + gap);
    const landmark = target.startsWith("LANDMARK");
    const accent = landmark ? "#8569D8" : C.gold;
    const card = frame(root, `Candidate/${key}`, x, y, cardWidth, cardHeight, "#222C34");
    card.strokes = paint(accent);
    card.strokeWeight = 3;
    card.cornerRadius = 24;
    await text(card, "EditableName", label, 32, 26, 28);
    await text(card, "TargetGuide", target, 32, 68, 21, accent);
    const preview = frame(card, "TransparentPreview", 32, 125, cardWidth - 64, cardHeight - 170, "#1A2229");
    preview.cornerRadius = 18;
    raster(
      preview,
      `Image/${key}`,
      B2_REVIEW_ASSETS[key],
      28,
      28,
      preview.width - 56,
      preview.height - 56
    );
  }
  return root;
}

async function main() {
  await Promise.all([
    figma.loadFontAsync({ family: "Inter", style: "Regular" }),
    figma.loadFontAsync({ family: "Inter", style: "Bold" })
  ]);
  const targetPage = figma.currentPage;
  const reviewName = "Town / Base Modular Buildings + Town Map / FAST IMPORT";
  const reviewAliases = new Set([
    reviewName,
    "Town / B2 Hand-Painted Front Style Review / FAST IMPORT",
    "Town / B2 Strict Front Elevation Review / FAST IMPORT",
    "Town / B2 Building + Landmark Review / FAST IMPORT"
  ]);
  const existingReview = targetPage.findOne((node) => reviewAliases.has(node.name));
  const preservedReviewPosition = existingReview
    ? { x: existingReview.x, y: existingReview.y }
    : null;
  if (existingReview) {
    existingReview.remove();
  }
  const existingRight = targetPage.children.reduce(
    (maximum, node) => Math.max(maximum, node.x + node.width),
    0
  );
  const baseX = existingRight + 1000;
  const existingWorld = targetPage.findOne(
    (node) => node.name === "Town / Eternal Forge / Editable v2 / World / 5200x720"
  );
  if (existingWorld) {
    const reviewRoot = await buildB2Review(targetPage);
    reviewRoot.x = preservedReviewPosition ? preservedReviewPosition.x : baseX;
    reviewRoot.y = preservedReviewPosition ? preservedReviewPosition.y : 0;
    figma.viewport.scrollAndZoomIntoView([reviewRoot]);
    figma.notify("Town B2：審稿區已快速更新，舊 Town frames 未重建", { timeout: 5000 });
    figma.closePlugin();
    return;
  }
  const coverRoot = await buildCover(targetPage);
  const buildingResult = await buildBuildings(targetPage);
  const uiResult = await buildUi(targetPage);
  const tokensRoot = await buildTokens(targetPage);
  const worldRoot = await buildWorld(targetPage, buildingResult.registry, uiResult.markers);
  const referencesRoot = await buildReferences(targetPage);
  const reviewRoot = await buildB2Review(targetPage);

  coverRoot.x = baseX;
  coverRoot.y = 0;
  worldRoot.x = baseX;
  worldRoot.y = 1200;
  buildingResult.root.x = baseX;
  buildingResult.root.y = 2100;
  uiResult.root.x = baseX + 4400;
  uiResult.root.y = 2100;
  tokensRoot.x = baseX + 4400;
  tokensRoot.y = 3800;
  referencesRoot.x = baseX + 6800;
  referencesRoot.y = 0;
  reviewRoot.x = baseX;
  reviewRoot.y = 6500;

  figma.viewport.scrollAndZoomIntoView([reviewRoot]);
  figma.notify("Town Eternal Forge：已建立完整來源與 B2 審稿區", { timeout: 5000 });
  figma.closePlugin();
}

main().catch((error) => {
  figma.notify(`Town 建立失敗：${error.message}`, { error: true, timeout: 8000 });
  console.error(error);
  figma.closePlugin();
});

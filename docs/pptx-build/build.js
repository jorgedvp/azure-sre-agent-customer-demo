const pptxgen = require("pptxgenjs");

// Palette: Microsoft Executive (Jorge's design DNA)
const WHITE = "FFFFFF";
const BLUE = "0078D4";
const NAVY = "0A2C6E";
const CYAN = "00BBC3";
const SKY = "5CC6F5";
const BLACK = "1A1A1A";
const GRAY_DARK = "404040";
const GRAY_MED = "767676";

const deck = new pptxgen();
deck.layout = "LAYOUT_WIDE"; // 13.33 x 7.5 in
deck.author = "Jorge Zapata";
deck.subject = "Azure SRE Agent + Azure Arc — Customer Demo";
deck.title = "Azure SRE Agent + Azure Arc — Remediación Autónoma Fuera de Azure";
deck.company = "Microsoft";
deck.lang = "es-ES";

const FONT = "Arial";
const W = 13.33;
const H = 7.5;

// Consistent content grid used on every slide
const MARGIN_L = 0.7;
const MARGIN_R = 0.7;
const CONTENT_W = W - MARGIN_L - MARGIN_R; // 11.93
const RIGHT_EDGE = W - MARGIN_R; // 12.63

function sectionLabel(slide, text) {
  slide.addText(text.toUpperCase(), {
    x: MARGIN_L, y: 0.5, w: 8, h: 0.35,
    fontFace: FONT, fontSize: 11, color: BLUE, charSpacing: 1, margin: 0,
  });
}

function pageNumber(slide, n) {
  slide.addText(String(n).padStart(2, "0"), {
    x: RIGHT_EDGE - 0.5, y: H - 0.55, w: 0.5, h: 0.3,
    fontFace: FONT, fontSize: 10, color: GRAY_MED, align: "right", margin: 0,
  });
}

// ============================================================
// SLIDE 1 — Cover (Impact / dark navy)
// ============================================================
{
  const slide = deck.addSlide();
  slide.background = { color: NAVY };

  slide.addText("MICROSOFT  ·  AZURE SRE AGENT  ·  AZURE ARC", {
    x: 0.9, y: 2.0, w: 10, h: 0.4,
    fontFace: FONT, fontSize: 12, color: SKY, charSpacing: 2, margin: 0,
  });

  slide.addText("Remediación autónoma,\nfuera de Azure", {
    x: 0.9, y: 2.55, w: 11, h: 2.3,
    fontFace: FONT, fontSize: 48, bold: true, color: WHITE, lineSpacing: 54, margin: 0,
  });

  slide.addShape(deck.ShapeType.rect, {
    x: 0.9, y: 4.6, w: 1.6, h: 0.045, fill: { color: CYAN }, line: { type: "none" },
  });

  slide.addText(
    "Cómo Azure SRE Agent observa, diagnostica y remedia incidentes en servidores\non-premises — vía Azure Arc — con la misma autonomía que en Azure.",
    {
      x: 0.9, y: 4.9, w: 10.5, h: 0.9,
      fontFace: FONT, fontSize: 16, color: "D7E6FA", lineSpacing: 22, margin: 0,
    }
  );

  slide.addText("Demostración técnica  ·  Entorno de demostración para clientes", {
    x: 0.9, y: H - 0.8, w: 10, h: 0.35,
    fontFace: FONT, fontSize: 12, color: SKY, margin: 0,
  });
}

// ============================================================
// SLIDE 2 — Agenda (Pattern 1: Label + Title + Cards)
// ============================================================
{
  const slide = deck.addSlide();
  slide.background = { color: WHITE };
  sectionLabel(slide, "Agenda de la sesión");
  slide.addText("Lo que vamos a ver hoy", {
    x: MARGIN_L, y: 0.9, w: 10, h: 0.7,
    fontFace: FONT, fontSize: 32, bold: true, color: NAVY, margin: 0,
  });

  const items = [
    ["01", "El problema", "Por qué la observabilidad y remediación autónoma importan fuera de Azure."],
    ["02", "Arquitectura", "Cómo Azure Arc conecta servidores externos con la misma capacidad de gestión de una VM nativa."],
    ["03", "4 casos en vivo", "Sistema operativo, aplicación web, base de datos, y una vulnerabilidad de seguridad."],
    ["04", "Seguridad y control", "Quién autoriza qué, y por qué el agente nunca actúa sin aprobación humana."],
    ["05", "Costos", "Qué cuesta realmente habilitar esta capacidad sobre infraestructura existente."],
  ];

  const n = items.length;
  const gap = 0.2;
  const colW = (CONTENT_W - gap * (n - 1)) / n;
  const startX = MARGIN_L;
  const y = 2.3;
  const cardH = 2.65;

  items.forEach((item, i) => {
    const x = startX + i * (colW + gap);
    slide.addShape(deck.ShapeType.rect, {
      x, y, w: colW, h: cardH,
      fill: { color: "F7F9FC" },
      line: { color: "E3E8F0", width: 1 },
      rectRadius: 0.06,
    });
    slide.addShape(deck.ShapeType.rect, {
      x, y, w: 0.06, h: cardH,
      fill: { color: BLUE },
      line: { type: "none" },
    });
    slide.addText(item[0], {
      x: x + 0.22, y: y + 0.22, w: colW - 0.4, h: 0.5,
      fontFace: FONT, fontSize: 24, bold: true, color: CYAN, margin: 0,
    });
    slide.addText(item[1], {
      x: x + 0.22, y: y + 0.78, w: colW - 0.4, h: 0.5,
      fontFace: FONT, fontSize: 14, bold: true, color: BLACK, margin: 0, lineSpacing: 17, valign: "top",
    });
    slide.addText(item[2], {
      x: x + 0.22, y: y + 1.32, w: colW - 0.42, h: cardH - 1.5,
      fontFace: FONT, fontSize: 10.5, color: GRAY_DARK, margin: 0, lineSpacing: 14, valign: "top",
    });
  });

  // Bottom summary strip to use remaining vertical space
  const stripY = y + cardH + 0.55;
  slide.addShape(deck.ShapeType.line, {
    x: MARGIN_L, y: stripY, w: CONTENT_W, h: 0, line: { color: "E3E8F0", width: 1 },
  });
  slide.addText(
    "Cada caso se muestra en vivo sobre infraestructura real, conectada mediante Azure Arc — nada de lo que verán está simulado en pantalla.",
    { x: MARGIN_L, y: stripY + 0.25, w: CONTENT_W, h: 0.5, fontFace: FONT, fontSize: 13, italic: true, color: GRAY_MED, margin: 0 }
  );

  pageNumber(slide, 2);
}

// ============================================================
// SLIDE 3 — El problema (Two column, balanced)
// ============================================================
{
  const slide = deck.addSlide();
  slide.background = { color: WHITE };
  sectionLabel(slide, "El problema");
  slide.addText("Su infraestructura\nno vive solo en Azure", {
    x: MARGIN_L, y: 0.9, w: 5.5, h: 1.6,
    fontFace: FONT, fontSize: 28, bold: true, color: NAVY, lineSpacing: 32, margin: 0,
  });
  slide.addText(
    "Servidores on-premises, en otra nube o en un datacenter propio no tienen hoy el mismo nivel de observabilidad y remediación automática que una VM nativa de Azure.",
    { x: MARGIN_L, y: 2.55, w: 5.4, h: 1.1, fontFace: FONT, fontSize: 13.5, color: GRAY_DARK, lineSpacing: 18, margin: 0 }
  );

  // Fill the remaining left space with a supporting big-number callout
  slide.addShape(deck.ShapeType.rect, {
    x: MARGIN_L, y: 4.1, w: 0.06, h: 2.4, fill: { color: BLUE }, line: { type: "none" },
  });
  slide.addText("Sin Arc", {
    x: MARGIN_L + 0.28, y: 4.0, w: 3.5, h: 0.9,
    fontFace: FONT, fontSize: 42, bold: true, color: NAVY, margin: 0,
  });
  slide.addText(
    "Esos servidores quedan fuera del alcance de Azure Monitor y del SRE Agent — sin inventario, sin telemetría, sin remediación asistida.",
    { x: MARGIN_L + 0.28, y: 4.85, w: 5.0, h: 1.6, fontFace: FONT, fontSize: 12.5, color: GRAY_DARK, lineSpacing: 17, margin: 0, valign: "top" }
  );

  const stats = [
    ["Fuera de Azure", "Servidores on-premises o en otra nube, sin integración nativa de IA de confiabilidad."],
    ["Guardia manual", "Los ingenieros diagnostican y remedian incidentes a mano, muchas veces fuera de horario."],
    ["Brecha de seguridad", "Vulnerabilidades reales — permisos excesivos, configuración insegura — sin ticket ni dueño."],
  ];

  const rightX = 6.9;
  const rightW = RIGHT_EDGE - rightX; // matches content width consistently
  let y = 0.9;
  const rowH = 1.85;
  stats.forEach((s) => {
    slide.addShape(deck.ShapeType.rect, {
      x: rightX, y, w: rightW, h: 1.6,
      fill: { color: "F7F9FC" }, line: { color: "E3E8F0", width: 1 }, rectRadius: 0.06,
    });
    slide.addShape(deck.ShapeType.rect, {
      x: rightX, y, w: 0.06, h: 1.6, fill: { color: BLUE }, line: { type: "none" },
    });
    slide.addText(s[0], {
      x: rightX + 0.25, y: y + 0.2, w: rightW - 0.5, h: 0.4,
      fontFace: FONT, fontSize: 15, bold: true, color: BLACK, margin: 0,
    });
    slide.addText(s[1], {
      x: rightX + 0.25, y: y + 0.65, w: rightW - 0.5, h: 0.85,
      fontFace: FONT, fontSize: 12, color: GRAY_DARK, lineSpacing: 16, margin: 0,
    });
    y += rowH;
  });

  pageNumber(slide, 3);
}

// ============================================================
// SLIDE 4 — Arquitectura (diagram-like with boxes)
// ============================================================
{
  const slide = deck.addSlide();
  slide.background = { color: WHITE };
  sectionLabel(slide, "Arquitectura");
  slide.addText("El puente: Azure Arc", {
    x: MARGIN_L, y: 0.88, w: 9, h: 0.6,
    fontFace: FONT, fontSize: 30, bold: true, color: NAVY, margin: 0,
  });
  slide.addText(
    "Azure Arc conecta servidores fuera de Azure al plano de control de Azure, habilitando\ninventario, telemetría y ejecución remota de comandos — la misma base que usa el agente.",
    { x: MARGIN_L, y: 1.52, w: 10.8, h: 0.6, fontFace: FONT, fontSize: 13, color: GRAY_DARK, lineSpacing: 18, margin: 0 }
  );

  // Flow boxes — equal height titles, no odd separators
  const boxes = [
    ["Servidor on-premises", "Linux / Windows, fuera de Azure", NAVY],
    ["Azure Arc", "Hybrid Compute: puente de conectividad", BLUE],
    ["Log Analytics y\nAzure Monitor", "Telemetría y alertas", BLUE],
    ["Azure SRE Agent", "Diagnostica y propone remediación", CYAN],
  ];

  const nBoxes = boxes.length;
  const arrowW = 0.45;
  const boxH = 1.55;
  const boxY = 2.35;
  const boxW = (CONTENT_W - arrowW * (nBoxes - 1)) / nBoxes;
  const boxPositions = [];
  let bx = MARGIN_L;
  boxes.forEach((b, i) => {
    const isLast = i === nBoxes - 1;
    const isCyan = b[2] === CYAN;
    boxPositions.push(bx);
    slide.addShape(deck.ShapeType.rect, {
      x: bx, y: boxY, w: boxW, h: boxH,
      fill: { color: b[2] }, line: { type: "none" }, rectRadius: 0.08,
    });
    slide.addText(b[0], {
      x: bx + 0.2, y: boxY + 0.22, w: boxW - 0.4, h: 0.65,
      fontFace: FONT, fontSize: 14, bold: true, color: isCyan ? NAVY : WHITE, margin: 0, lineSpacing: 17, valign: "top",
    });
    slide.addText(b[1], {
      x: bx + 0.2, y: boxY + 0.92, w: boxW - 0.4, h: 0.55,
      fontFace: FONT, fontSize: 10.5, color: isCyan ? "0A2C6E" : "E8EEF8", margin: 0, lineSpacing: 13, valign: "top",
    });
    if (!isLast) {
      slide.addText("\u2192", {
        x: bx + boxW + 0.04, y: boxY + boxH / 2 - 0.22, w: arrowW - 0.08, h: 0.44,
        fontFace: FONT, fontSize: 20, bold: true, color: BLUE, align: "center", valign: "middle", margin: 0,
      });
    }
    bx += boxW + arrowW;
  });

  // Bottom callouts — aligned under box columns (box 1, box 2+3 midpoint area, box 4)
  const callouts = [
    ["Sin privilegios especiales", "Arc ejecuta con el mismo alcance que un administrador local: root en Linux, SYSTEM en Windows."],
    ["Siempre con aprobación humana", "Cada acción en modo Revisión requiere un clic explícito de \u201cApprove action\u201d."],
    ["RBAC acotado al recurso", "El agente solo tiene permisos sobre los grupos de recursos autorizados explícitamente."],
  ];
  const cgap = 0.4;
  const cw = (CONTENT_W - cgap * 2) / 3;
  let cx = MARGIN_L;
  const calloutY = 4.3;
  const calloutH = 1.5;
  callouts.forEach((c) => {
    slide.addShape(deck.ShapeType.line, {
      x: cx, y: calloutY, w: 0, h: calloutH, line: { color: "C9D4E3", width: 2 },
    });
    slide.addText(c[0], {
      x: cx + 0.22, y: calloutY, w: cw - 0.3, h: 0.55,
      fontFace: FONT, fontSize: 13, bold: true, color: NAVY, margin: 0, lineSpacing: 16, valign: "top",
    });
    slide.addText(c[1], {
      x: cx + 0.22, y: calloutY + 0.6, w: cw - 0.3, h: calloutH - 0.6,
      fontFace: FONT, fontSize: 11, color: GRAY_DARK, lineSpacing: 15, margin: 0, valign: "top",
    });
    cx += cw + cgap;
  });

  pageNumber(slide, 4);
}

// ============================================================
// SLIDE 5 — Los 4 casos de uso (cards grid 2x2)
// ============================================================
{
  const slide = deck.addSlide();
  slide.background = { color: WHITE };
  sectionLabel(slide, "Lo que van a ver en vivo");
  slide.addText("4 casos de uso reales", {
    x: MARGIN_L, y: 0.9, w: 9, h: 0.7,
    fontFace: FONT, fontSize: 32, bold: true, color: NAVY, margin: 0,
  });

  const cases = [
    ["1", "Sistema operativo", "Un servicio crítico cae en el servidor Linux on-premises simulado. El agente diagnostica y propone la remediación.", BLUE],
    ["2", "Aplicación web (IIS)", "Un Application Pool se detiene en el servidor Windows. El agente identifica la causa y reinicia el servicio con aprobación.", BLUE],
    ["3", "Base de datos (SQL)", "Una sesión bloqueadora real congela las escrituras. El agente identifica la sesión exacta y propone finalizarla.", BLUE],
    ["4", "Seguridad (Defender)", "Microsoft Defender detecta una vulnerabilidad real. El agente investiga, crea un GitHub Issue y abre un Pull Request, de forma autónoma.", NAVY],
  ];

  const gx = 0.3, gy = 0.3;
  const cw = (CONTENT_W - gx) / 2;
  const ch = 1.55;
  const startX = MARGIN_L, startY = 2.0;
  cases.forEach((c, i) => {
    const col = i % 2, row = Math.floor(i / 2);
    const x = startX + col * (cw + gx);
    const y = startY + row * (ch + gy);
    slide.addShape(deck.ShapeType.rect, {
      x, y, w: cw, h: ch, fill: { color: "F7F9FC" }, line: { color: "E3E8F0", width: 1 }, rectRadius: 0.06,
    });
    slide.addShape(deck.ShapeType.ellipse, {
      x: x + 0.25, y: y + 0.22, w: 0.5, h: 0.5, fill: { color: c[3] }, line: { type: "none" },
    });
    slide.addText(c[0], {
      x: x + 0.25, y: y + 0.22, w: 0.5, h: 0.5,
      fontFace: FONT, fontSize: 18, bold: true, color: WHITE, align: "center", valign: "middle", margin: 0,
    });
    slide.addText(c[1], {
      x: x + 0.9, y: y + 0.2, w: cw - 1.15, h: 0.4,
      fontFace: FONT, fontSize: 16, bold: true, color: BLACK, margin: 0, valign: "top",
    });
    slide.addText(c[2], {
      x: x + 0.9, y: y + 0.65, w: cw - 1.15, h: ch - 0.8,
      fontFace: FONT, fontSize: 11, color: GRAY_DARK, lineSpacing: 14.5, margin: 0, valign: "top",
    });
  });

  // Bottom summary strip
  const stripY5 = startY + 2 * ch + gy + 0.55;
  slide.addShape(deck.ShapeType.line, {
    x: MARGIN_L, y: stripY5, w: CONTENT_W, h: 0, line: { color: "E3E8F0", width: 1 },
  });
  slide.addText(
    "En los casos 1–3, el presentador aprueba la remediación en vivo. En el caso 4, el foco es la detección y generación autónoma del ticket y la propuesta de corrección.",
    { x: MARGIN_L, y: stripY5 + 0.25, w: CONTENT_W, h: 0.5, fontFace: FONT, fontSize: 13, italic: true, color: GRAY_MED, margin: 0 }
  );

  pageNumber(slide, 5);
}

// ============================================================
// SLIDE 6 — Seguridad y control (big stat callout + list)
// ============================================================
{
  const slide = deck.addSlide();
  slide.background = { color: WHITE };
  sectionLabel(slide, "Seguridad y control");
  slide.addText("El agente nunca actúa\nsin autorización", {
    x: MARGIN_L, y: 0.9, w: 5.8, h: 1.55, fontFace: FONT, fontSize: 28, bold: true, color: NAVY, lineSpacing: 32, margin: 0,
  });

  const rows = [
    ["Roles de usuario", "4 roles: Reader, Standard User, Author y Administrator. Solo Administrator puede aprobar acciones."],
    ["Modo de ejecución", "Revisión — requiere aprobación explícita (usado en esta demo) — o Autónomo, acotado a tareas de bajo riesgo preaprobadas."],
    ["RBAC a nivel de recurso", "El agente solo tiene permisos de Azure sobre los grupos de recursos que el cliente le autorice explícitamente."],
  ];

  let y = 2.75;
  rows.forEach((r) => {
    slide.addShape(deck.ShapeType.rect, {
      x: MARGIN_L, y, w: 0.06, h: 1.05, fill: { color: BLUE }, line: { type: "none" },
    });
    slide.addText(r[0], {
      x: MARGIN_L + 0.25, y, w: 5.3, h: 0.35, fontFace: FONT, fontSize: 14, bold: true, color: BLACK, margin: 0, valign: "top",
    });
    slide.addText(r[1], {
      x: MARGIN_L + 0.25, y: y + 0.38, w: 5.3, h: 0.7, fontFace: FONT, fontSize: 11.5, color: GRAY_DARK, lineSpacing: 15, margin: 0, valign: "top",
    });
    y += 1.22;
  });

  // Right: big stat — aligned to same top as label row (0.9) and bottom-consistent with slide 8's card
  const cardX = 7.1, cardW = RIGHT_EDGE - cardX, cardY = 0.9, cardH = 5.6;
  slide.addShape(deck.ShapeType.rect, {
    x: cardX, y: cardY, w: cardW, h: cardH, fill: { color: NAVY }, line: { type: "none" }, rectRadius: 0.08,
  });
  slide.addText("100%", {
    x: cardX + 0.3, y: cardY + 0.55, w: cardW - 0.6, h: 1.1, fontFace: FONT, fontSize: 56, bold: true, color: CYAN, margin: 0,
  });
  slide.addText("de las acciones de remediación requieren aprobación humana en esta demo", {
    x: cardX + 0.3, y: cardY + 1.75, w: cardW - 0.6, h: 1.0, fontFace: FONT, fontSize: 15, color: WHITE, lineSpacing: 20, margin: 0, valign: "top",
  });
  slide.addShape(deck.ShapeType.rect, {
    x: cardX + 0.3, y: cardY + 3.0, w: 1.2, h: 0.035, fill: { color: SKY }, line: { type: "none" },
  });
  slide.addText(
    "Azure Arc otorga a la automatización el mismo alcance que un administrador local (root o SYSTEM) — por diseño, igual que cualquier herramienta de gestión de configuración tradicional. El control real está en quién autoriza, no en limitar el comando.",
    { x: cardX + 0.3, y: cardY + 3.3, w: cardW - 0.6, h: 1.7, fontFace: FONT, fontSize: 11.5, color: "D7E6FA", lineSpacing: 16, margin: 0, valign: "top" }
  );

  pageNumber(slide, 6);
}

// ============================================================
// SLIDE 7 — SQL seguro (Entra ID + Key Vault) — two column
// ============================================================
{
  const slide = deck.addSlide();
  slide.background = { color: WHITE };
  sectionLabel(slide, "Caso especial — Base de datos");
  slide.addText("Conexión segura a SQL,\nsin contraseñas", {
    x: MARGIN_L, y: 0.9, w: 5.8, h: 1.5, fontFace: FONT, fontSize: 26, bold: true, color: NAVY, lineSpacing: 30, margin: 0,
  });
  slide.addText(
    "Para producción, la automatización no debería depender de una contraseña de administrador en un archivo local. El patrón recomendado por Microsoft:",
    { x: MARGIN_L, y: 2.35, w: 5.7, h: 0.7, fontFace: FONT, fontSize: 12.5, color: GRAY_DARK, lineSpacing: 17, margin: 0, valign: "top" }
  );

  const steps = [
    "Microsoft Entra ID — autenticación nativa en SQL Server 2022+, sin usuarios ni contraseñas tradicionales.",
    "Managed Identity — el agente se autentica sin secretos distribuidos manualmente.",
    "Azure Key Vault — resguarda el certificado de confianza; nunca vive en disco local.",
    "Private Endpoint + DNS privada — el Key Vault solo es alcanzable desde la red interna.",
  ];
  let y = 3.25;
  steps.forEach((s, i) => {
    slide.addShape(deck.ShapeType.ellipse, {
      x: MARGIN_L, y, w: 0.32, h: 0.32, fill: { color: CYAN }, line: { type: "none" },
    });
    slide.addText(String(i + 1), {
      x: MARGIN_L, y, w: 0.32, h: 0.32, fontFace: FONT, fontSize: 12.5, bold: true, color: NAVY,
      align: "center", valign: "middle", margin: 0,
    });
    slide.addText(s, {
      x: MARGIN_L + 0.5, y: y - 0.06, w: 5.2, h: 0.65,
      fontFace: FONT, fontSize: 11, color: BLACK, lineSpacing: 14, margin: 0, valign: "middle",
    });
    y += 0.78;
  });

  // Right: architecture mini-diagram — same geometry as the navy cards (slides 6/8)
  const panelX = 7.1, panelW = RIGHT_EDGE - panelX, panelY = 0.9, panelH = 5.6;
  slide.addShape(deck.ShapeType.rect, {
    x: panelX, y: panelY, w: panelW, h: panelH, fill: { color: "F7F9FC" }, line: { color: "E3E8F0", width: 1 }, rectRadius: 0.08,
  });
  slide.addText("Flujo de autenticación segura", {
    x: panelX + 0.3, y: panelY + 0.28, w: panelW - 0.6, h: 0.35, fontFace: FONT, fontSize: 13, bold: true, color: NAVY, margin: 0,
  });

  const flow = ["Azure SRE Agent", "Managed Identity", "Microsoft Entra ID", "Certificado en Key Vault (Private Endpoint)", "SQL Server (Arc-enabled)"];
  const flowStartY = panelY + 0.85;
  const flowBoxH = 0.72;
  const flowArrowH = 0.26;
  const flowStep = flowBoxH + flowArrowH;
  const flowX = panelX + 0.3;
  const flowW = panelW - 0.6;
  flow.forEach((f, i) => {
    const fy = flowStartY + i * flowStep;
    const isLast = i === flow.length - 1;
    slide.addShape(deck.ShapeType.rect, {
      x: flowX, y: fy, w: flowW, h: flowBoxH, fill: { color: isLast ? NAVY : WHITE },
      line: { color: BLUE, width: 1.25 }, rectRadius: 0.05,
    });
    slide.addText(f, {
      x: flowX + 0.15, y: fy, w: flowW - 0.3, h: flowBoxH,
      fontFace: FONT, fontSize: 10.5, bold: true, color: isLast ? WHITE : BLACK,
      valign: "middle", margin: 0, lineSpacing: 12.5,
    });
    if (!isLast) {
      slide.addText("\u2193", {
        x: flowX, y: fy + flowBoxH, w: flowW, h: flowArrowH, fontFace: FONT, fontSize: 13, bold: true, color: BLUE, align: "center", valign: "middle", margin: 0,
      });
    }
  });

  pageNumber(slide, 7);
}

// ============================================================
// SLIDE 8 — Costos (table-like breakdown)
// ============================================================
{
  const slide = deck.addSlide();
  slide.background = { color: WHITE };
  sectionLabel(slide, "Costos");
  slide.addText("¿Cuánto cuesta\nhabilitar esto?", {
    x: MARGIN_L, y: 0.9, w: 5.8, h: 1.5, fontFace: FONT, fontSize: 28, bold: true, color: NAVY, lineSpacing: 32, margin: 0,
  });
  slide.addText(
    "Estimación para 2 servidores on-premises reales. No incluye el cómputo de las VMs, que en la demo solo simulan servidores que el cliente ya posee.",
    { x: MARGIN_L, y: 2.45, w: 5.6, h: 0.85, fontFace: FONT, fontSize: 12.5, color: GRAY_DARK, lineSpacing: 17, margin: 0, valign: "top" }
  );

  const rows = [
    ["Azure Arc (Hybrid Compute)", "Gratis"],
    ["Log Analytics (ingesta y retención)", "~$5–10/mes"],
    ["Microsoft Defender for Servers", "~$30/mes"],
    ["Microsoft Defender for SQL", "~$15/mes"],
    ["Azure Monitor (alertas)", "~$2–5/mes"],
  ];
  let y = 3.55;
  rows.forEach((r) => {
    slide.addText(r[0], {
      x: MARGIN_L, y, w: 4.0, h: 0.38, fontFace: FONT, fontSize: 12, color: BLACK, margin: 0, valign: "middle",
    });
    slide.addText(r[1], {
      x: 4.8, y, w: 1.4, h: 0.38, fontFace: FONT, fontSize: 12, bold: true, color: BLUE, align: "right", margin: 0, valign: "middle",
    });
    slide.addShape(deck.ShapeType.line, {
      x: MARGIN_L, y: y + 0.42, w: 5.6, h: 0, line: { color: "D6DEEA", width: 1 },
    });
    y += 0.56;
  });
  slide.addText("Total: ~$52–60/mes  ·  Azure SRE Agent no incluido (ver nota en la tarjeta)", {
    x: MARGIN_L, y, w: 5.9, h: 0.4, fontFace: FONT, fontSize: 10, italic: true, color: GRAY_MED, margin: 0,
  });

  // Right: big total callout — same geometry as slide 6's card
  const cardX = 7.1, cardW = RIGHT_EDGE - cardX, cardY = 0.9, cardH = 5.6;
  slide.addShape(deck.ShapeType.rect, {
    x: cardX, y: cardY, w: cardW, h: cardH, fill: { color: NAVY }, line: { type: "none" }, rectRadius: 0.08,
  });
  slide.addText("~$52–60", {
    x: cardX + 0.3, y: cardY + 0.65, w: cardW - 0.6, h: 1.0, fontFace: FONT, fontSize: 48, bold: true, color: CYAN, margin: 0,
  });
  slide.addText("USD al mes, por cada 2 servidores on-premises reales", {
    x: cardX + 0.3, y: cardY + 1.75, w: cardW - 0.6, h: 0.85, fontFace: FONT, fontSize: 14.5, color: WHITE, lineSpacing: 19, margin: 0, valign: "top",
  });
  slide.addShape(deck.ShapeType.rect, {
    x: cardX + 0.3, y: cardY + 2.75, w: 1.2, h: 0.035, fill: { color: SKY }, line: { type: "none" },
  });
  slide.addText(
    "El costo incremental de dar a la infraestructura existente esta capacidad de observabilidad y remediación autónoma es bajo, frente al costo de horas de guardia o un incidente no resuelto a tiempo.",
    { x: cardX + 0.3, y: cardY + 3.05, w: cardW - 0.6, h: 1.3, fontFace: FONT, fontSize: 11.5, color: "D7E6FA", lineSpacing: 16, margin: 0, valign: "top" }
  );
  slide.addText("Costo del Azure SRE Agent (always-on + uso activo): variable según consumo real — ver portal del agente.", {
    x: cardX + 0.3, y: cardY + 4.55, w: cardW - 0.6, h: 0.75, fontFace: FONT, fontSize: 10, italic: true, color: "A9C2E8", margin: 0, lineSpacing: 13, valign: "top",
  });

  pageNumber(slide, 8);
}

// ============================================================
// SLIDE 9 — Stage 2 / Foundry (Timeline/Roadmap pattern)
// ============================================================
{
  const slide = deck.addSlide();
  slide.background = { color: WHITE };
  sectionLabel(slide, "Qué sigue");
  slide.addText("Etapa 2: un agente a su medida", {
    x: MARGIN_L, y: 0.9, w: 10, h: 0.65, fontFace: FONT, fontSize: 30, bold: true, color: NAVY, margin: 0,
  });
  slide.addText(
    "Para clientes que necesiten mayor personalización: un agente de Azure AI Foundry con visibilidad\nsobre el mismo inventario de Arc, expuesto a través de un frontend de chat propio.",
    { x: MARGIN_L, y: 1.58, w: 11, h: 0.6, fontFace: FONT, fontSize: 13, color: GRAY_DARK, lineSpacing: 17, margin: 0 }
  );

  const phases = [
    ["Hoy", "Azure SRE Agent", "Producto estándar de Microsoft, ya validado en los 4 casos de uso de esta demo."],
    ["Próximo", "Agente Foundry a medida", "Mismo inventario de Arc; modelo y lógica personalizables por el cliente."],
    ["Próximo", "Frontend de chat propio", "Interfaz web propia (basada en la demo de FinOps existente) conectada al agente."],
    ["Futuro", "Casos de uso ampliados", "El cliente extiende el agente a sus propios flujos de negocio y datos."],
  ];

  const nP = phases.length;
  const pGap = 0.3;
  const boxW = (CONTENT_W - pGap * (nP - 1)) / nP;
  const lineY = 3.05;
  slide.addShape(deck.ShapeType.line, {
    x: MARGIN_L, y: lineY, w: CONTENT_W, h: 0, line: { color: "D6DEEA", width: 2 },
  });
  const cardTop = 3.45, cardH9 = 3.05;
  phases.forEach((p, i) => {
    const x = MARGIN_L + i * (boxW + pGap);
    const dotX = x + boxW / 2 - 0.09;
    slide.addShape(deck.ShapeType.ellipse, {
      x: dotX, y: lineY - 0.09, w: 0.18, h: 0.18,
      fill: { color: i === 0 ? CYAN : BLUE }, line: { color: WHITE, width: 2 },
    });
    slide.addShape(deck.ShapeType.rect, {
      x, y: cardTop, w: boxW, h: cardH9, fill: { color: "F7F9FC" }, line: { color: "E3E8F0", width: 1 }, rectRadius: 0.06,
    });
    slide.addText(p[0].toUpperCase(), {
      x: x + 0.2, y: cardTop + 0.22, w: boxW - 0.4, h: 0.3, fontFace: FONT, fontSize: 10, color: BLUE, charSpacing: 1, margin: 0,
    });
    slide.addText(p[1], {
      x: x + 0.2, y: cardTop + 0.55, w: boxW - 0.4, h: 0.75, fontFace: FONT, fontSize: 14, bold: true, color: BLACK, lineSpacing: 17, margin: 0, valign: "top",
    });
    slide.addText(p[2], {
      x: x + 0.2, y: cardTop + 1.35, w: boxW - 0.4, h: cardH9 - 1.5, fontFace: FONT, fontSize: 10.5, color: GRAY_DARK, lineSpacing: 14, margin: 0, valign: "top",
    });
  });

  pageNumber(slide, 9);
}

// ============================================================
// SLIDE 10 — Closing (Impact / dark)
// ============================================================
{
  const slide = deck.addSlide();
  slide.background = { color: BLACK };

  slide.addText("CIERRE", {
    x: 0.9, y: 1.6, w: 8, h: 0.4, fontFace: FONT, fontSize: 13, color: SKY, charSpacing: 2, margin: 0,
  });
  slide.addText("Observar, diagnosticar,\nremediar — en cualquier lugar", {
    x: 0.9, y: 2.15, w: 11.3, h: 1.9, fontFace: FONT, fontSize: 38, bold: true, color: WHITE, lineSpacing: 45, margin: 0,
  });
  slide.addShape(deck.ShapeType.rect, {
    x: 0.9, y: 4.2, w: 1.6, h: 0.045, fill: { color: CYAN }, line: { type: "none" },
  });
  slide.addText(
    "Azure SRE Agent y Azure Arc llevan la misma inteligencia operativa de Azure a cualquier servidor, en cualquier nube o datacenter, con control humano en cada paso.",
    { x: 0.9, y: 4.5, w: 9.8, h: 0.9, fontFace: FONT, fontSize: 16, color: "D7D7D7", lineSpacing: 22, margin: 0 }
  );

  slide.addText("Preguntas y próximos pasos", {
    x: 0.9, y: H - 1.05, w: 8, h: 0.4, fontFace: FONT, fontSize: 14, bold: true, color: SKY, margin: 0,
  });
}

(async () => {
  await deck.writeFile({ fileName: "/tmp/azure-sre-agent-customer-demo/docs/Presentacion-Intro-Demo.pptx" });
  console.log("done");
})();

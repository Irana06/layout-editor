/**
 * generate-manifest.js
 *
 * Scan folder assets/game/buildings-source/{army,defensive,other,resource,traps}
 * SECARA REKURSIF (support subfolder sedalam apapun, misal
 * buildings-source/army/army-camp/Army Camp1.png) dan assets/game/scenery,
 * terus generate/update assets/game/buildings-source/manifest.json
 *
 * Jalanin dari root project:
 *   node generate-manifest.js
 *
 * Aman dijalanin berkali-kali: kalibrasi (gridSize/scale/offsetX/offsetY,
 * dan grid scenery) yang udah kamu atur sebelumnya DIPERTAHANKAN untuk
 * file yang sama (dicocokkan lewat id). Entry yang file-nya udah nggak
 * ada otomatis kebuang dari manifest.
 */

const fs = require('fs');
const path = require('path');

const GAME_ROOT = path.join(__dirname, 'assets', 'game');
const BUILDINGS_SRC = path.join(GAME_ROOT, 'buildings-source');
const SCENERY_SRC = path.join(GAME_ROOT, 'scenery');
const MANIFEST_PATH = path.join(BUILDINGS_SRC, 'manifest.json');

const IMAGE_EXT = new Set(['.png', '.jpg', '.jpeg', '.webp']);
const CATEGORIES = ['army', 'defensive', 'other', 'resource', 'traps'];

// Tebakan default gridSize per kategori — starting point, tetap harus
// dicek/diubah manual per building di halaman calibrate.html.
const DEFAULT_GRID_SIZE = {
  army: 3,
  defensive: 3,
  other: 1,
  resource: 3,
  traps: 2
};

function slugify(str) {
  return str
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function prettyName(filename) {
  return filename
    .replace(/\.[^/.]+$/, '')
    .replace(/[_-]+/g, ' ')
    .trim();
}

/**
 * Scan folder secara rekursif, balikin list of { relPath, absPath }
 * relPath pakai forward-slash, relatif ke `dir`.
 */
function walkImages(dir, relPrefix = '') {
  if (!fs.existsSync(dir)) return [];
  let results = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name));
  for (const entry of entries) {
    const abs = path.join(dir, entry.name);
    const rel = relPrefix ? `${relPrefix}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      results = results.concat(walkImages(abs, rel));
    } else if (IMAGE_EXT.has(path.extname(entry.name).toLowerCase())) {
      results.push({ relPath: rel, absPath: abs });
    }
  }
  return results;
}

function loadExistingManifest() {
  if (!fs.existsSync(MANIFEST_PATH)) return { buildings: [], scenery: [] };
  try {
    const raw = fs.readFileSync(MANIFEST_PATH, 'utf8');
    if (!raw.trim()) return { buildings: [], scenery: [] };
    const parsed = JSON.parse(raw);
    return {
      buildings: Array.isArray(parsed.buildings) ? parsed.buildings : [],
      scenery: Array.isArray(parsed.scenery) ? parsed.scenery : []
    };
  } catch (e) {
    console.warn('manifest.json lama gagal dibaca (rusak?), bikin baru dari nol.');
    return { buildings: [], scenery: [] };
  }
}

function buildBuildingsList(existing) {
  const existingById = new Map(existing.buildings.map((b) => [b.id, b]));
  const result = [];

  CATEGORIES.forEach((category) => {
    const dir = path.join(BUILDINGS_SRC, category);
    const files = walkImages(dir);
    files.forEach(({ relPath }) => {
      // relPath contoh: "army-camp/Army Camp1.png" atau "Cannon16B.png"
      const relFile = path.posix.join('buildings-source', category, relPath.split(path.sep).join('/'));
      const id = `${category}-${slugify(relPath.replace(/\.[^/.]+$/, ''))}`;
      const baseName = relPath.split('/').pop();
      const prev = existingById.get(id);
      result.push({
        id,
        name: prev?.name ?? prettyName(baseName),
        category,
        subfolder: relPath.includes('/') ? relPath.split('/').slice(0, -1).join('/') : null,
        file: relFile,
        gridSize: prev?.gridSize ?? DEFAULT_GRID_SIZE[category] ?? 3,
        calibration: {
          scale: prev?.calibration?.scale ?? 1,
          offsetX: prev?.calibration?.offsetX ?? 0,
          offsetY: prev?.calibration?.offsetY ?? 0
        }
      });
    });
  });

  return result;
}

function buildSceneryList(existing) {
  const existingById = new Map(existing.scenery.map((s) => [s.id, s]));
  const files = walkImages(SCENERY_SRC);

  return files.map(({ relPath }) => {
    const relFile = path.posix.join('scenery', relPath.split(path.sep).join('/'));
    const id = slugify(relPath.replace(/\.[^/.]+$/, ''));
    const baseName = relPath.split('/').pop();
    const prev = existingById.get(id);
    return {
      id,
      name: prev?.name ?? prettyName(baseName),
      file: relFile,
      // Default grid — kalau scenery ini sebelumnya udah dikalibrasi manual
      // (grid.calibrated === true), nilainya dipertahankan apa adanya.
      grid: prev?.grid ?? {
        tileW: 56,
        tileH: 42,
        originX: 0,
        originY: 0,
        n: 44,
        calibrated: false,
        locked: false
      }
    };
  });
}

function main() {
  if (!fs.existsSync(BUILDINGS_SRC)) {
    console.error('Folder tidak ketemu:', BUILDINGS_SRC);
    process.exit(1);
  }

  const existing = loadExistingManifest();
  const buildings = buildBuildingsList(existing);
  const scenery = buildSceneryList(existing);

  const manifest = {
    generatedAt: new Date().toISOString(),
    buildings,
    scenery
  };

  fs.writeFileSync(MANIFEST_PATH, JSON.stringify(manifest, null, 2), 'utf8');
  console.log(`manifest.json ditulis: ${buildings.length} building, ${scenery.length} scenery`);
  console.log('Lokasi:', MANIFEST_PATH);

  const byCat = {};
  buildings.forEach((b) => { byCat[b.category] = (byCat[b.category] || 0) + 1; });
  Object.entries(byCat).forEach(([cat, n]) => console.log(`  - ${cat}: ${n}`));

  if (scenery.some((s) => !s.grid.calibrated)) {
    console.log(
      '\nCatatan: ada scenery yang grid-nya masih default/belum dikalibrasi.\n' +
      'Kalibrasi manual per scenery via calibrate.html (mode "Kalibrasi grid").'
    );
  }
}

main();
// One-off rig repair: normalise the per-vertex skin weights of the skinned
// Polygon2D pieces in DarklightRig.tscn.
//
// Godot blends bone matrices with those weights, so a vertex whose weights sum
// to 2.0 is displaced twice as far as its bones. At rest every bone matrix is
// identity, which hides the error; as soon as the pelvis travels (a roll, for
// example) the upper-arm and thigh artwork slides off the body.
//
// Usage: node tests/normalize_skin_weights.mjs [--check]
import { readFileSync, writeFileSync } from "node:fs";

const PATH = "game/player/darklight/DarklightRig.tscn";
const CHECK_ONLY = process.argv.includes("--check");

const text = readFileSync(PATH, "utf8");
let lines = 0;
const report = [];

const output = text.replace(/^bones = \[(.*)\]$/gm, (line) => {
  lines += 1;
  const arrays = [...line.matchAll(/PackedFloat32Array\(([^)]*)\)/g)];
  const parsed = arrays.map((match) => {
    const raw = match[1].trim();
    if (raw.length === 0) return [];
    return raw.split(",").map((value) => Number(value.trim()));
  });
  const counts = parsed.map((values) => values.length);
  const vertexCount = Math.max(...counts);
  const totals = new Array(vertexCount).fill(0);
  for (const values of parsed) {
    values.forEach((value, index) => { totals[index] += value; });
  }
  const worst = Math.max(...totals);
  const broken = totals.filter((total) => Math.abs(total - 1) > 1e-4).length;
  report.push(`  vertices=${vertexCount} worst weight sum=${worst} unnormalised=${broken}`);
  if (CHECK_ONLY || broken === 0) return line;
  let index = 0;
  return line.replace(/PackedFloat32Array\(([^)]*)\)/g, () => {
    const values = parsed[index];
    const position = index;
    index += 1;
    if (values.length === 0) return "PackedFloat32Array()";
    const normalised = values.map((value, vertex) => {
      const total = totals[vertex];
      const scaled = total > 0 ? value / total : 0;
      return Number(scaled.toFixed(6));
    });
    // Keep the authored zeroes compact, the way the scene format writes them.
    return `PackedFloat32Array(${normalised.join(", ")})`;
    void position;
  });
});

console.log(`bones arrays: ${lines}`);
console.log(report.join("\n"));
if (CHECK_ONLY) {
  console.log("check only: nothing written");
} else {
  writeFileSync(PATH, output);
  console.log("written " + PATH);
}

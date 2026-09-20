#!/usr/bin/env node
// wiki_lint.mjs - read-only health check for the docs/ LLM Wiki vault.
//
// Run from the docs/ directory:
//   node tools/wiki_lint.mjs
//
// Checks frontmatter, links inside and outside the vault, index coverage in
// both directions, tag vocabulary and orphan pages. It never writes anything:
// wiki pages and raw sources stay authoritative.
//
// Exit code is 1 when errors were found, 0 when only warnings remain.

import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join, resolve, dirname, relative, isAbsolute, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const DOCS_DIR = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const PAGE_TYPES = [
  'schema',
  'index',
  'overview',
  'concept-table',
  'log',
  'architecture',
  'guide',
  'reference',
  'plan',
];
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const AGENTS = 'AGENTS.md';

const errors = [];
const warnings = [];
const err = (page, message) => errors.push({ page, message });
const warn = (page, message) => warnings.push({ page, message });

const pageFiles = readdirSync(DOCS_DIR)
  .filter((name) => name.endsWith('.md') && statSync(join(DOCS_DIR, name)).isFile())
  .sort();

const pages = new Map(
  pageFiles.map((name) => [name, parsePage(readFileSync(join(DOCS_DIR, name), 'utf8'))]),
);
const inbound = new Map(pageFiles.map((name) => [name, new Set()]));

checkFrontmatter();
checkLinks();
checkIndexCoverage();
checkOrphans();
report();

// ---------------------------------------------------------------- checks

function checkFrontmatter() {
  const vocabulary = readTagVocabulary(pages.get(AGENTS)?.body ?? '');
  if (vocabulary.size === 0) {
    err(AGENTS, 'no controlled tag vocabulary found under "## Controlled tag vocabulary"');
  }

  for (const [name, page] of pages) {
    const fm = page.frontmatter;
    if (!fm) {
      err(name, 'missing YAML frontmatter');
      continue;
    }
    for (const key of ['title', 'type', 'created', 'updated', 'tags']) {
      if (!(key in fm)) err(name, `frontmatter is missing "${key}"`);
    }
    if (fm.type && !PAGE_TYPES.includes(fm.type)) {
      err(name, `unknown type "${fm.type}" (allowed: ${PAGE_TYPES.join(', ')})`);
    }
    for (const key of ['created', 'updated']) {
      if (fm[key] && !DATE_RE.test(fm[key])) {
        err(name, `frontmatter "${key}" is not YYYY-MM-DD: "${fm[key]}"`);
      }
    }
    const tags = fm.tags ?? [];
    if (tags.length < 1 || tags.length > 4) {
      err(name, `expected one to four tags, found ${tags.length}`);
    }
    for (const tag of tags) {
      if (!vocabulary.has(tag)) {
        err(name, `tag "${tag}" is not in the controlled vocabulary`);
      }
    }
  }
}

function checkLinks() {
  for (const [name, page] of pages) {
    for (const link of markdownTargets(page.body)) checkMarkdownLink(name, link);
    for (const link of wikilinkTargets(page.body)) checkWikilink(name, link);
  }
}

function checkWikilink(name, link) {
  const target = link.target.trim();
  if (target === '') {
    err(name, `empty wikilink at line ${link.line}`);
    return;
  }
  if (target.includes('/') || target.startsWith('.')) {
    err(name, `wikilink "[[${target}]]" at line ${link.line} is not a vault page name`);
    return;
  }
  const file = target.endsWith('.md') ? target : `${target}.md`;
  if (!pages.has(file)) {
    err(name, `wikilink "[[${target}]]" at line ${link.line} resolves to no page`);
    return;
  }
  recordInbound(file, name);
  if (link.anchor) checkAnchor(name, file, link.anchor, link.line);
}

function checkMarkdownLink(name, link) {
  const raw = link.target.trim();
  if (raw === '') return;

  if (raw.startsWith('#')) {
    if (raw.length > 1) checkAnchor(name, name, decodeURIComponent(raw.slice(1)), link.line);
    return;
  }
  if (/^[a-z][a-z0-9+.-]*:/i.test(raw)) return; // http(s):, mailto:, res:// ...

  const [pathPart, anchor] = splitAnchor(raw);
  const path = decodeURIComponent(pathPart);
  const absolute = resolve(DOCS_DIR, path);

  if (!existsSync(absolute)) {
    const where = isInside(DOCS_DIR, absolute) ? 'vault link' : 'raw-source link';
    err(name, `${where} "${raw}" at line ${link.line} points at a missing file`);
    return;
  }

  if (isInside(DOCS_DIR, absolute)) {
    const rel = relative(DOCS_DIR, absolute).split(sep).join('/');
    const target = rel.endsWith('.md') ? rel : `${rel}.md`;
    if (!pages.has(target)) return; // non-markdown attachment inside the vault
    recordInbound(target, name);
    if (anchor) checkAnchor(name, target, anchor, link.line);
    return;
  }

  if (anchor && absolute.endsWith('.md')) {
    const text = safeRead(absolute);
    if (text && !collectAnchors(text).has(anchor.toLowerCase())) {
      warn(name, `anchor "#${anchor}" at line ${link.line} is not in ${path}`);
    }
  }
}

function checkAnchor(fromPage, targetPage, anchor, line) {
  const page = pages.get(targetPage);
  if (!page) return;
  if (page.anchors.has(anchor.toLowerCase())) return;
  warn(
    fromPage,
    `anchor "#${anchor}" at line ${line} does not match a heading in ${targetPage}`,
  );
}

function checkIndexCoverage() {
  if (!pages.has('index.md')) {
    err('index.md', 'the vault has no index.md');
    return;
  }
  for (const name of pages.keys()) {
    if (name === 'index.md') continue;
    if (!inbound.get(name)?.has('index.md')) err(name, 'is not listed in index.md');
  }
}

function checkOrphans() {
  for (const [name, sources] of inbound) {
    if (name === 'index.md' || name === 'log.md') continue;
    if (sources.size === 0) warn(name, 'has no inbound links from other pages');
  }
}

function recordInbound(target, source) {
  if (target === source) return;
  inbound.get(target)?.add(source);
}

function report() {
  for (const [label, list] of [['errors', errors], ['warnings', warnings]]) {
    if (list.length === 0) continue;
    console.log(`\n${label.toUpperCase()} (${list.length})`);
    for (const { page, message } of list) console.log(`  ${page}: ${message}`);
  }
  console.log(
    `\n${pageFiles.length} pages checked - ${errors.length} errors, ${warnings.length} warnings`,
  );
  process.exit(errors.length > 0 ? 1 : 0);
}

// ---------------------------------------------------------------- parsing

function parsePage(text) {
  const { frontmatter, body } = splitFrontmatter(text);
  return { frontmatter, body, anchors: collectAnchors(text) };
}

function splitFrontmatter(text) {
  const match = /^---\r?\n([\s\S]*?)\r?\n---[ \t]*\r?\n?/.exec(text);
  if (!match) return { frontmatter: null, body: text };
  return { frontmatter: parseYaml(match[1]), body: text.slice(match[0].length) };
}

function parseYaml(block) {
  const result = {};
  for (const line of block.split(/\r?\n/)) {
    const pair = /^([A-Za-z_][\w-]*):\s*(.*)$/.exec(line);
    if (!pair) continue;
    const [, key, rawValue] = pair;
    const value = rawValue.trim();
    result[key] =
      value.startsWith('[') && value.endsWith(']')
        ? value
            .slice(1, -1)
            .split(',')
            .map((item) => item.trim().replace(/^["']|["']$/g, ''))
            .filter((item) => item !== '')
        : value.replace(/^["']|["']$/g, '');
  }
  return result;
}

function markdownTargets(body) {
  const found = [];
  scanText(body).forEach((text, index) => {
    const re = /(!?)\[([^\]]*)\]\(([^()]+)\)/g;
    let match;
    while ((match = re.exec(text)) !== null) {
      if (match[1] === '!') continue; // image, not a page reference
      const target = match[3].replace(/\s+"[^"]*"\s*$/, '').trim();
      found.push({ target, line: index + 1 });
    }
  });
  return found;
}

function wikilinkTargets(body) {
  const found = [];
  scanText(body).forEach((text, index) => {
    const re = /\[\[([^\]]+)\]\]/g;
    let match;
    while ((match = re.exec(text)) !== null) {
      // Inside tables Obsidian requires the alias pipe to be escaped: [[Page\|Alias]].
      const raw = match[1].split('|')[0].replace(/\\+$/, '');
      const [target, anchor] = splitAnchor(raw);
      found.push({ target, anchor, line: index + 1 });
    }
  });
  return found;
}

// Links inside inline code spans are examples, not references. Blanking the
// span keeps line numbers and column positions intact.
function scanText(body) {
  return body.replace(/``[^`]*``|`[^`\n]*`/g, (span) => ' '.repeat(span.length)).split(/\r?\n/);
}

function splitAnchor(raw) {
  const index = raw.indexOf('#');
  if (index === -1) return [raw, ''];
  return [raw.slice(0, index), decodeURIComponent(raw.slice(index + 1))];
}

function collectAnchors(text) {
  const anchors = new Set();
  const body = text.replace(/```[\s\S]*?```/g, '');
  for (const [, title] of body.matchAll(/^#{1,6}\s+(.+?)\s*$/gm)) {
    const clean = title.replace(/\*\*/g, '').replace(/`/g, '');
    anchors.add(clean.toLowerCase());
    anchors.add(slugify(clean));
  }
  for (const [, id] of body.matchAll(/<a\s+id="([^"]+)"/g)) anchors.add(id.toLowerCase());
  return anchors;
}

function slugify(title) {
  return title
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s_-]/gu, '')
    .replace(/\s+/g, '-');
}

function readTagVocabulary(body) {
  const section = /## Controlled tag vocabulary\r?\n([\s\S]*?)(?=\r?\n## )/.exec(body);
  if (!section) return new Set();
  const tags = new Set();
  for (const [, tag] of section[1].matchAll(/`([a-z][a-z-]*)`/g)) tags.add(tag);
  return tags;
}

function isInside(parent, child) {
  const rel = relative(parent, child);
  return rel !== '' && !rel.startsWith('..') && !isAbsolute(rel);
}

function safeRead(path) {
  try {
    return readFileSync(path, 'utf8');
  } catch {
    return '';
  }
}

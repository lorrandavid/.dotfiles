#!/usr/bin/env node
// Counts Cognitive-Driven Development (CDD) intrinsic complexity points per class
// with the audited project's own TypeScript compiler and type checker, so loops
// and coupling are resolved from real types instead of text matching.
//
// Usage: node cdd-complexity.mjs <project-root> [--config <file>] [--json] [<path> ...]
//   <path>    Files or directories (relative to the project root) to report. Default: src
//   --config  CDD config file. Default: cdd.config.json next to this script
//   --json    Print machine-readable JSON instead of tables

import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const ITERATION_METHODS = new Set([
  'forEach', 'map', 'filter', 'reduce', 'reduceRight', 'some', 'every',
  'find', 'findIndex', 'findLast', 'findLastIndex', 'flatMap',
]);
const ITERABLE_TYPE_NAMES = new Set(['Map', 'Set', 'ReadonlyMap', 'ReadonlySet', 'NodeListOf']);
const EXCLUDED_DIRS = ['node_modules', 'dist', '.angular', 'coverage'];

function fail(message) {
  console.error(`cdd-complexity: ${message}`);
  process.exit(2);
}

function parseArgs(argv) {
  const args = { root: undefined, config: undefined, json: false, paths: [] };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--json') args.json = true;
    else if (arg === '--config') {
      args.config = argv[++i];
      if (!args.config) fail('--config needs a file path');
    } else if (arg.startsWith('--')) fail(`unknown option ${arg}`);
    else if (args.root === undefined) args.root = arg;
    else args.paths.push(arg);
  }
  if (args.root === undefined) fail('usage: cdd-complexity.mjs <project-root> [--config <file>] [--json] [<path> ...]');
  return args;
}

function loadConfig(file, detectorIds) {
  const config = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!Number.isInteger(config.limitPointsPerClass)) fail(`${file}: limitPointsPerClass must be an integer`);
  if (!Array.isArray(config.ignore)) fail(`${file}: ignore must be an array of globs`);
  if (!Array.isArray(config.items)) fail(`${file}: items must be an array`);
  for (const item of config.items) {
    if (!detectorIds.has(item.id)) fail(`${file}: unknown item id "${item.id}". Known ids: ${[...detectorIds].join(', ')}`);
    if (!Number.isFinite(item.points)) fail(`${file}: item "${item.id}" needs numeric points`);
  }
  const limits = config.componentLimits;
  if (!limits || !Number.isInteger(limits.classLines) || !Number.isInteger(limits.templateLines)) {
    fail(`${file}: componentLimits.classLines and componentLimits.templateLines must be integers`);
  }
  return config;
}

// Use the project's TypeScript so the analysis matches the version the project compiles with.
function loadTypeScript(root) {
  const require = createRequire(path.join(root, 'package.json'));
  let ts;
  try {
    ts = require('typescript');
  } catch {
    fail(`typescript is not installed in ${root}. Install the project dependencies first (for example "npm ci").`);
  }
  if (typeof ts.createProgram !== 'function') fail(`typescript ${ts.version} in ${root} has no compiler API`);
  return ts;
}

function compilerOptions(ts, root) {
  const tsconfig = path.join(root, 'tsconfig.json');
  if (!fs.existsSync(tsconfig)) fail(`${tsconfig} not found`);
  const read = ts.readConfigFile(tsconfig, ts.sys.readFile);
  if (read.error) fail(ts.flattenDiagnosticMessageText(read.error.messageText, '\n'));
  return ts.parseJsonConfigFileContent(read.config, ts.sys, root).options;
}

function toPosix(p) {
  return p.split(path.sep).join('/');
}

function collectFiles(root, scopes, ignore) {
  const files = new Set();
  for (const scope of scopes) {
    const abs = path.resolve(root, scope);
    if (!fs.existsSync(abs)) fail(`${scope} does not exist in ${root}`);
    const candidates = fs.statSync(abs).isDirectory()
      ? fs.globSync('**/*.ts', { cwd: abs, exclude: (name) => EXCLUDED_DIRS.includes(path.basename(name)) })
          .map((f) => path.join(abs, f))
      : [abs];
    for (const file of candidates) {
      const rel = toPosix(path.relative(root, file));
      if (!ignore.some((glob) => path.matchesGlob(rel, glob))) files.add(file);
    }
  }
  return [...files].sort();
}

function lineOf(sourceFile, node) {
  return sourceFile.getLineAndCharacterOfPosition(node.getStart(sourceFile)).line + 1;
}

function decoratorName(ts, node) {
  for (const decorator of ts.canHaveDecorators(node) ? ts.getDecorators(node) ?? [] : []) {
    const expr = decorator.expression;
    if (ts.isCallExpression(expr) && ts.isIdentifier(expr.expression)) {
      if (['Component', 'Directive', 'Injectable', 'Pipe', 'NgModule'].includes(expr.expression.text)) {
        return { name: expr.expression.text, metadata: expr.arguments[0] };
      }
    }
  }
  return undefined;
}

function countLines(text) {
  return text.replace(/\n$/, '').split('\n').length;
}

function templateInfo(ts, sourceFile, metadata) {
  if (!metadata || !ts.isObjectLiteralExpression(metadata)) return { kind: 'none' };
  for (const prop of metadata.properties) {
    if (!ts.isPropertyAssignment(prop) || !ts.isIdentifier(prop.name)) continue;
    const value = prop.initializer;
    const isString = ts.isStringLiteral(value) || ts.isNoSubstitutionTemplateLiteral(value);
    if (prop.name.text === 'template' && (isString || ts.isTemplateExpression(value))) {
      return { kind: 'inline', lines: countLines(value.getText(sourceFile).slice(1, -1).trim()) };
    }
    if (prop.name.text === 'templateUrl' && isString) {
      const file = path.resolve(path.dirname(sourceFile.fileName), value.text);
      if (!fs.existsSync(file)) return { kind: 'missing', file };
      return { kind: 'file', file, lines: countLines(fs.readFileSync(file, 'utf8')) };
    }
  }
  return { kind: 'none' };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const root = path.resolve(args.root);
  const scriptDir = path.dirname(fileURLToPath(import.meta.url));
  const configFile = path.resolve(args.config ?? path.join(scriptDir, 'cdd.config.json'));

  const ts = loadTypeScript(root);
  const warnings = [];
  let checker;

  const isProjectDeclaration = (decl) => {
    const file = decl.getSourceFile().fileName;
    return !file.includes('/node_modules/') && path.resolve(file).startsWith(root + path.sep);
  };

  const isIterableReceiver = (receiver, sourceFile) => {
    const type = checker.getNonNullableType(checker.getTypeAtLocation(receiver));
    if (type.flags & (ts.TypeFlags.Any | ts.TypeFlags.Unknown)) {
      warnings.push(`${toPosix(path.relative(root, sourceFile.fileName))}:${lineOf(sourceFile, receiver)}: type of "${receiver.getText(sourceFile)}" is unresolved; iteration call not counted`);
      return false;
    }
    const parts = type.isUnion() ? type.types : [type];
    return parts.every((t) => checker.isArrayType(t) || checker.isTupleType(t) || ITERABLE_TYPE_NAMES.has(t.getSymbol()?.name));
  };

  // Each detector returns true when the node earns the item's points once.
  const detectors = {
    if: (node) => ts.isIfStatement(node),
    'switch-case': (node) => ts.isCaseClause(node),
    ternary: (node) => ts.isConditionalExpression(node),
    'logical-operator': (node) => ts.isBinaryExpression(node)
      && (node.operatorToken.kind === ts.SyntaxKind.AmpersandAmpersandToken || node.operatorToken.kind === ts.SyntaxKind.BarBarToken),
    loop: (node, sourceFile) => {
      if (ts.isForStatement(node) || ts.isForInStatement(node) || ts.isForOfStatement(node)
        || ts.isWhileStatement(node) || ts.isDoStatement(node)) return true;
      return ts.isCallExpression(node)
        && ts.isPropertyAccessExpression(node.expression)
        && ITERATION_METHODS.has(node.expression.name.text)
        && isIterableReceiver(node.expression.expression, sourceFile);
    },
    'try-catch': (node) => ts.isTryStatement(node),
    'lambda-with-body': (node) => {
      const isLambda = (ts.isArrowFunction(node) && ts.isBlock(node.body)) || ts.isFunctionExpression(node);
      const parent = node.parent;
      return isLambda && (ts.isCallExpression(parent) || ts.isNewExpression(parent)) && (parent.arguments ?? []).includes(node);
    },
    // Counted per distinct type in the unit, not per node; see projectTypeOf.
    'project-coupling': () => false,
  };

  const config = loadConfig(configFile, new Set(Object.keys(detectors)));
  const items = config.items;
  const couplingItem = items.find((i) => i.id === 'project-coupling');

  const files = collectFiles(root, args.paths.length ? args.paths : ['src'], config.ignore);
  if (files.length === 0) fail('no TypeScript files to analyze after applying ignore globs');
  const program = ts.createProgram(files, compilerOptions(ts, root));
  checker = program.getTypeChecker();

  // Imports and a type's own declaration name are not uses of the type.
  const isUseSite = (identifier) => {
    const parent = identifier.parent;
    if (ts.isImportSpecifier(parent) || ts.isImportClause(parent) || ts.isNamespaceImport(parent) || ts.isExportSpecifier(parent)) return false;
    return !((ts.isClassLike(parent) || ts.isInterfaceDeclaration(parent) || ts.isTypeAliasDeclaration(parent) || ts.isEnumDeclaration(parent))
      && parent.name === identifier);
  };

  const projectTypeOf = (identifier) => {
    if (!isUseSite(identifier)) return undefined;
    let symbol = checker.getSymbolAtLocation(identifier);
    if (!symbol) return undefined;
    if (symbol.flags & ts.SymbolFlags.Alias) symbol = checker.getAliasedSymbol(symbol);
    const decl = symbol.declarations?.find((d) => ts.isClassDeclaration(d) || ts.isInterfaceDeclaration(d)
      || ts.isTypeAliasDeclaration(d) || ts.isEnumDeclaration(d));
    if (!decl || !isProjectDeclaration(decl)) return undefined;
    return { key: `${decl.getSourceFile().fileName}#${symbol.name}`, name: symbol.name, decl };
  };

  const units = [];
  for (const file of files) {
    const sourceFile = program.getSourceFile(file);
    const relFile = toPosix(path.relative(root, file));
    const newUnit = (name, kind, node) => ({
      file: relFile, name, kind, node,
      startLine: node ? lineOf(sourceFile, node) : 1,
      items: Object.fromEntries(items.map((i) => [i.id, { points: 0, lines: [] }])),
      coupling: new Map(),
      subscribeLines: [],
    });
    const fileScope = newUnit('(file scope)', 'file-scope', undefined);
    const fileUnits = [fileScope];

    const visit = (node, unit) => {
      if (ts.isClassDeclaration(node) || ts.isClassExpression(node)) {
        const classUnit = newUnit(node.name?.text ?? '(anonymous class)', 'class', node);
        fileUnits.push(classUnit);
        unit = classUnit;
      }
      for (const item of items) {
        if (detectors[item.id](node, sourceFile)) {
          unit.items[item.id].points += item.points;
          unit.items[item.id].lines.push(lineOf(sourceFile, node));
        }
      }
      if (couplingItem && ts.isIdentifier(node)) {
        const type = projectTypeOf(node);
        if (type && type.decl !== unit.node && !unit.coupling.has(type.key)) {
          unit.coupling.set(type.key, { name: type.name, line: lineOf(sourceFile, node) });
        }
      }
      if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression) && node.expression.name.text === 'subscribe') {
        unit.subscribeLines.push(lineOf(sourceFile, node));
      }
      ts.forEachChild(node, (child) => visit(child, unit));
    };
    ts.forEachChild(sourceFile, (child) => visit(child, fileScope));

    for (const unit of fileUnits) {
      if (couplingItem) {
        unit.items['project-coupling'] = {
          points: unit.coupling.size * couplingItem.points,
          lines: [...unit.coupling.values()].map((c) => c.line),
        };
      }
      const points = Object.values(unit.items).reduce((sum, i) => sum + i.points, 0);
      if (unit.kind === 'file-scope' && points === 0) continue;
      const decorator = unit.node ? decoratorName(ts, unit.node) : undefined;
      const result = {
        file: unit.file,
        name: unit.name,
        kind: unit.kind,
        decorator: decorator?.name ?? null,
        startLine: unit.startLine,
        lines: unit.node ? sourceFile.getLineAndCharacterOfPosition(unit.node.getEnd()).line + 1 - unit.startLine + 1 : null,
        points,
        limit: config.limitPointsPerClass,
        overLimit: points > config.limitPointsPerClass,
        items: unit.items,
        couplingTypes: [...unit.coupling.values()].map((c) => c.name),
        component: null,
      };
      if (decorator?.name === 'Component' || decorator?.name === 'Directive') {
        const template = decorator.name === 'Component' ? templateInfo(ts, sourceFile, decorator.metadata) : { kind: 'none' };
        if (template.kind === 'missing') warnings.push(`${unit.file}: templateUrl ${toPosix(path.relative(root, template.file))} not found`);
        result.component = {
          templateKind: template.kind,
          templateFile: template.file ? toPosix(path.relative(root, template.file)) : null,
          templateLines: template.lines ?? null,
          subscribeLines: unit.subscribeLines,
          overClassLines: result.lines > config.componentLimits.classLines,
          overTemplateLines: (template.lines ?? 0) > config.componentLimits.templateLines,
        };
      }
      units.push(result);
    }
  }
  units.sort((a, b) => b.points - a.points || a.file.localeCompare(b.file));

  const report = {
    root,
    config: configFile,
    typescriptVersion: ts.version,
    limitPointsPerClass: config.limitPointsPerClass,
    componentLimits: config.componentLimits,
    filesAnalyzed: files.length,
    units,
    warnings,
  };

  if (args.json) {
    console.log(JSON.stringify(report, null, 2));
    return;
  }
  printTables(report, items);
}

function printTables(report, items) {
  const breakdown = (unit) => items
    .filter((i) => unit.items[i.id].points > 0)
    .map((i) => `${i.id} ${unit.items[i.id].points} (L${unit.items[i.id].lines.join(',')})`)
    .join('; ');
  console.log(`CDD points per class. Limit: ${report.limitPointsPerClass}. TypeScript ${report.typescriptVersion}. Files: ${report.filesAnalyzed}. Config: ${report.config}`);
  console.log('');
  console.log('| Points | Unit | Breakdown |');
  console.log('|---|---|---|');
  for (const unit of report.units) {
    const mark = unit.overLimit ? ' **over**' : '';
    const coupling = unit.couplingTypes.length ? ` [types: ${unit.couplingTypes.join(', ')}]` : '';
    console.log(`| ${unit.points}/${unit.limit}${mark} | \`${unit.file}:${unit.startLine}\` ${unit.name} | ${breakdown(unit)}${coupling} |`);
  }
  const components = report.units.filter((u) => u.component);
  if (components.length) {
    console.log('');
    console.log(`Components and directives. Limits: class ${report.componentLimits.classLines} lines, template ${report.componentLimits.templateLines} lines.`);
    console.log('');
    console.log('| Unit | Decorator | Class lines | Template lines | subscribe() lines |');
    console.log('|---|---|---|---|---|');
    for (const unit of components) {
      const c = unit.component;
      const classLines = `${unit.lines}${c.overClassLines ? ' **over**' : ''}`;
      const templateLines = c.templateLines === null ? '-' : `${c.templateLines} (${c.templateKind})${c.overTemplateLines ? ' **over**' : ''}`;
      console.log(`| \`${unit.file}:${unit.startLine}\` ${unit.name} | ${unit.decorator} | ${classLines} | ${templateLines} | ${c.subscribeLines.join(', ') || '-'} |`);
    }
  }
  if (report.warnings.length) {
    console.log('');
    console.log('Warnings:');
    for (const w of report.warnings) console.log(`- ${w}`);
  }
}

main();

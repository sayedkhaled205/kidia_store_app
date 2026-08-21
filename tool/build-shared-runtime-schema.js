const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const schemaDir = path.join(root, 'mobishop', 'includes', 'schema');
const output = path.join(root, 'mobishop', 'shared-runtime', 'block-schema.json');

function tokenize(source) {
	const body = source.slice(source.indexOf('return array'));
	const tokens = [];
	const pattern = /\s+|\/\*[\s\S]*?\*\/|\/\/[^\n]*|#[^\n]*|=>|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?|[A-Za-z_][A-Za-z0-9_]*|[(),;]/gy;
	let offset = 0;
	while (offset < body.length) {
		pattern.lastIndex = offset;
		const match = pattern.exec(body);
		if (!match) throw new Error(`Unsupported PHP schema syntax near: ${body.slice(offset, offset + 40)}`);
		offset = pattern.lastIndex;
		const value = match[0];
		if (/^\s+$/.test(value) || value.startsWith('/*') || value.startsWith('//') || value.startsWith('#')) continue;
		tokens.push(value);
		if (value === ';') break;
	}
	return tokens;
}

function decodeString(token) {
	const quote = token[0];
	const body = token.slice(1, -1);
	return body.replace(/\\(['"\\nrt])/g, (_match, escaped) => ({ n: '\n', r: '\r', t: '\t' }[escaped] || escaped));
}

function parsePhpArray(source) {
	const tokens = tokenize(source);
	let index = tokens.indexOf('array');

	function peek() { return tokens[index]; }
	function take(expected) {
		const token = tokens[index++];
		if (expected && token !== expected) throw new Error(`Expected ${expected}, received ${token}`);
		return token;
	}
	function value() {
		const token = peek();
		if (token === 'array') return array();
		if (token === '__') {
			take('__'); take('(');
			const translated = value();
			while (peek() !== ')') { if (peek() === ',') take(','); else value(); }
			take(')');
			return translated;
		}
		if (token === 'true' || token === 'false') { take(); return token === 'true'; }
		if (token === 'null') { take(); return null; }
		if (/^-?\d/.test(token)) { take(); return Number(token); }
		if (/^['"]/.test(token)) { take(); return decodeString(token); }
		throw new Error(`Unexpected PHP schema token ${token}`);
	}
	function array() {
		take('array'); take('(');
		const entries = [];
		let associative = false;
		while (peek() !== ')') {
			const first = value();
			if (peek() === '=>') {
				associative = true;
				take('=>');
				entries.push([String(first), value()]);
			} else {
				entries.push([null, first]);
			}
			if (peek() === ',') take(',');
		}
		take(')');
		if (!associative) return entries.map((entry) => entry[1]);
		const result = {};
		entries.forEach(([key, item], position) => { result[key === null ? String(position) : key] = item; });
		return result;
	}

	return value();
}

const blocks = {};
fs.readdirSync(schemaDir).filter((file) => file.endsWith('.php')).sort().forEach((file) => {
	const type = path.basename(file, '.php').replaceAll('-', '_');
	blocks[type] = { type, ...parsePhpArray(fs.readFileSync(path.join(schemaDir, file), 'utf8')) };
});

fs.writeFileSync(output, JSON.stringify({ version: 1, blocks }, null, 2) + '\n');
console.log(`Wrote ${Object.keys(blocks).length} canonical block schemas to ${path.relative(root, output)}.`);


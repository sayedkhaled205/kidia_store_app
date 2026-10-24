import fs from "node:fs";
import path from "node:path";

const root = process.argv[2];
if (!root) throw new Error("Pass the generated Flutter preview directory.");

// Flutter aggregates package licenses from the local SDK/checkout. Normalize
// only line endings so Windows and Linux retain identical license content.
const notices = path.join(root, "assets", "NOTICES");
const content = fs.readFileSync(notices, "utf8");
fs.writeFileSync(notices, content.replace(/\r\n?/g, "\n"));

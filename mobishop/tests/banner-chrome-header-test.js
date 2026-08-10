const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const css = read("admin/assets/chrome-layout.css");
const preview = read("admin/assets/home-builder.js");
const banner = read("includes/blocks/class-mobishop-banner-grid-block.php");

const chromeTemplate = read("admin/pages/fixed-chrome-card.php");
const pageBuilderCss = read("admin/assets/page-builder.css");
assert.match(chromeTemplate, /mobishop-card-actions[\s\S]*mobishop-builder-switch mobishop-builder-switch--card mobishop-card-action mobishop-card-action--toggle[\s\S]*mobishop-builder-switch__track[\s\S]*mobishop-builder-switch__state/, "Fixed Header and Footer must use the exact normal-element switch structure.");
assert.doesNotMatch(chromeTemplate, /mobishop-fixed-chrome-toggle/, "Fixed Header and Footer must not retain a legacy switch class that can restore a separate appearance.");
assert.match(chromeTemplate, /class="mobishop-card-actions"[\s\S]*mobishop-card-action--primary[\s\S]*mobishop-card-action--secondary[\s\S]*mobishop-card-action--expand[\s\S]*mobishop-card-action--toggle/, "Fixed Header and Footer must use the canonical four-slot closed-card action strip.");
assert.match(pageBuilderCss, /\.mobishop-card-action--toggle\s*\{\s*grid-column:4;\s*grid-row:1;\s*direction:rtl;\s*\}/, "Fixed Header and Footer On/Off must stay in the canonical fourth action slot without changing its original direction or appearance.");
assert.match(banner, /mobishop-hero-block-item__header[\s\S]*Banner[\s\S]*mobishop-repeatable-item-actions[\s\S]*mobishop-remove-repeatable-item[\s\S]*mobishop-add-repeatable-item[\s\S]*mobishop-banner-item-toggle[\s\S]*mobishop-toggle-state/, "Banner must use the same title, Remove, Add and On/Off header structure as Slider.");
assert.match(banner, /'enabled'\s*=>\s*isset\(\s*\$item\['enabled'\]/, "Banner visibility must be sanitized and saved.");
assert.match(banner, /foreach \( \$settings\['items'\] as \$item \)[\s\S]*empty\( \$item\['enabled'\] \)/, "Disabled banners must be excluded from the app API.");
assert.match(preview, /case "banner_grid":[\s\S]*banner\.enabled !== "0"[\s\S]*renderBannerTile/, "Banner On/Off must update the live preview.");

console.log("Banner header and fixed Header/Footer closed-card action order: ok");

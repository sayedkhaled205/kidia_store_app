const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const css = read("admin/assets/chrome-layout.css");
const preview = read("admin/assets/home-builder.js");
const banner = read("includes/blocks/class-kidia-mobile-banner-grid-block.php");

const chromeTemplate = read("admin/pages/fixed-chrome-card.php");
const pageBuilderCss = read("admin/assets/page-builder.css");
assert.match(chromeTemplate, /kidia-fixed-chrome-toggle[\s\S]*kidia-builder-switch__track[\s\S]*kidia-builder-switch__state/, "Fixed Header and Footer must use the exact normal-element switch structure.");
assert.match(chromeTemplate, /class="kidia-card-actions"[\s\S]*kidia-card-action--primary[\s\S]*kidia-card-action--secondary[\s\S]*kidia-card-action--expand[\s\S]*kidia-card-action--toggle/, "Fixed Header and Footer must use the canonical four-slot closed-card action strip.");
assert.match(pageBuilderCss, /\.kidia-card-action--toggle\s*\{\s*grid-column:4;\s*grid-row:1;\s*direction:rtl;\s*\}/, "Fixed Header and Footer On/Off must stay in the canonical fourth action slot without changing its original direction or appearance.");
assert.match(banner, /kidia-hero-block-item__header[\s\S]*Banner[\s\S]*kidia-repeatable-item-actions[\s\S]*kidia-remove-repeatable-item[\s\S]*kidia-add-repeatable-item[\s\S]*kidia-banner-item-toggle[\s\S]*kidia-toggle-state/, "Banner must use the same title, Remove, Add and On/Off header structure as Slider.");
assert.match(banner, /'enabled'\s*=>\s*isset\(\s*\$item\['enabled'\]/, "Banner visibility must be sanitized and saved.");
assert.match(banner, /foreach \( \$settings\['items'\] as \$item \)[\s\S]*empty\( \$item\['enabled'\] \)/, "Disabled banners must be excluded from the app API.");
assert.match(preview, /case "banner_grid":[\s\S]*banner\.enabled !== "0"[\s\S]*renderBannerTile/, "Banner On/Off must update the live preview.");

console.log("Banner header and fixed Header/Footer closed-card action order: ok");

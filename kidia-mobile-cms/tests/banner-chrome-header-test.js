const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const css = read("admin/assets/chrome-layout.css");
const preview = read("admin/assets/home-builder.js");
const banner = read("includes/blocks/class-kidia-mobile-banner-grid-block.php");

assert.match(css, /\.kidia-fixed-chrome-card > \.kidia-page-card__header > \.kidia-page-master-toggle\s*\{[^}]*order:3;[^}]*direction:rtl;/, "Fixed Header and Footer must show the On label before their switch track.");
assert.match(banner, /kidia-hero-block-item__header[\s\S]*Banner[\s\S]*kidia-repeatable-item-actions[\s\S]*kidia-remove-repeatable-item[\s\S]*kidia-add-repeatable-item[\s\S]*kidia-banner-item-toggle[\s\S]*kidia-toggle-state/, "Banner must use the same title, Remove, Add and On/Off header structure as Slider.");
assert.match(banner, /'enabled'\s*=>\s*isset\(\s*\$item\['enabled'\]/, "Banner visibility must be sanitized and saved.");
assert.match(banner, /foreach \( \$settings\['items'\] as \$item \)[\s\S]*empty\( \$item\['enabled'\] \)/, "Disabled banners must be excluded from the app API.");
assert.match(preview, /case "banner_grid":[\s\S]*banner\.enabled !== "0"[\s\S]*renderBannerTile/, "Banner On/Off must update the live preview.");

console.log("Banner header and fixed Header/Footer toggle order: ok");

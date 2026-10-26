"""Add the optional outline field to existing connector sanitizers and exports.

Writes candidates only; the caller checks original hashes before activation.
"""
from pathlib import Path
import re
import sys

FILES = ['includes/class-mobishop-page-layout-store.php',
         'includes/blocks/class-mobishop-product-grid-block.php',
         'includes/blocks/class-mobishop-product-carousel-block.php']
BRAND = "sanitize_hex_color( (string) ( class_exists( 'MobiShop_Setup_Wizard' ) ? ( new MobiShop_Setup_Wizard() )->identity()['primary_color'] ?? '' : '' ) ) ?: '#2F806E'"

def patch(name, source):
    if "'card_outline_color'" in source:
        raise ValueError('Outline already exists; reconcile instead of overwriting: ' + name)
    if name == FILES[0]:
        domain = 'mobi2app-connector' if "__( 'Card radius', 'mobi2app-connector' )" in source else 'mobishop'
        anchor = "\t\t\tself::field( 'card_radius', __( 'Card radius', '" + domain + "' ), 'number', 16, array(), 0, 40 ),"
        assert source.count(anchor) == 1
        source = source.replace(anchor, "\t\t\tself::field( 'card_outline_color', __( 'Outline color', '" + domain + "' ), 'color', " + BRAND + " ),\n" + anchor)
        anchor = "'columns', 'gap', 'card_style', 'card_radius'"
        assert source.count(anchor) == 2
        source = source.replace(anchor, "'columns', 'gap', 'card_style', 'card_outline_color', 'card_radius'")
    else:
        pattern = r"(?m)^(\s*'card_style'\s*=>[^\n]+\n)"
        matches = list(re.finditer(pattern, source))
        assert len(matches) == 3, (name, len(matches))
        replacements = [BRAND,
            "sanitize_hex_color( (string) ( $settings['card_outline_color'] ?? '' ) ) ?: $this->get_default_settings()['card_outline_color']",
            "$settings['card_outline_color']"]
        for match, value in reversed(list(zip(matches, replacements))):
            source = source[:match.end()] + "\t\t\t'card_outline_color' => " + value + ",\n" + source[match.end():]
    return source

if __name__ == '__main__':
    root, target = map(Path, sys.argv[1:3])
    for name in FILES:
        out = target / name
        assert (root / name).resolve() != out.resolve()
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(patch(name, (root / name).read_bytes().decode('utf-8')).encode('utf-8'))

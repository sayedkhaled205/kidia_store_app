"""Extend the existing public design schema without replacing concurrent code.

Usage: source.php candidate.php. Activation remains a separately guarded step.
"""
from pathlib import Path
import json
import re
import sys

def patch(source):
    if '/* product-outline-schema-v1 */' in source:
        return source
    for constant in ('FIELD_TYPES_JSON', 'HOME_FIELD_TYPES_JSON'):
        # Constants occupy one line; retain surrounding PHP source verbatim.
        match = re.search(r"(private const " + constant + r" = ')(.*?)(';)", source)
        assert match, constant
        value = json.loads(match[2])
        groups = [value] if constant == 'HOME_FIELD_TYPES_JSON' else list(value['pages'].values())
        changed = 0
        for group in groups:
            for key in ('product_grid', 'product_carousel', 'wishlist_grid'):
                if key in group and 'card_style' in group[key]:
                    group[key]['card_outline_color'] = 'color'
                    changed += 1
        assert changed >= 2
        source = source[:match.start(2)] + json.dumps(value, separators=(',', ':'), ensure_ascii=False).replace("'", r"\u0027") + source[match.end(2):]
    for anchor in ("            $kind = $types[$key] ?? null;", "            $type = $types[$key] ?? null;"):
        assert source.count(anchor) == 1, anchor
        source = source.replace(anchor, anchor + "\n            if ($key === 'card_outline_color') self::color($value, 'product outline color');", 1)
    return source.replace('<?php', '<?php\n/* product-outline-schema-v1 */', 1)

if __name__ == '__main__':
    source, target = map(Path, sys.argv[1:3])
    assert source.resolve() != target.resolve()
    target.write_text(patch(source.read_text(encoding='utf-8')), encoding='utf-8')

"""Add the public quick-add presentation field without replacing live code."""
import json
import re
from pathlib import Path
import sys

def patch(source):
    match = re.search(r"(private const FIELD_TYPES_JSON = ')(.*?)(';)", source)
    assert match, 'Public field schema missing'
    fields = json.loads(match[2])
    assert fields['footer'].get('button_shape') == 'select'
    assert fields['footer'].get('quick_add_layout') in (None, 'select')
    fields['footer']['quick_add_layout'] = 'select'
    source = source[:match.start(2)] + json.dumps(fields, separators=(',', ':'), ensure_ascii=False).replace("'", r"\u0027") + source[match.end(2):]
    guard = "            if ($key === 'quick_add_layout' && !in_array($value, ['button', 'wishlist_button'], true)) self::fail('Invalid quick add footer layout.');"
    anchor = "            $type = $types[$key] ?? null;"
    assert source.count(anchor) == 1
    if guard not in source:
        source = source.replace(anchor, anchor+'\n'+guard, 1)
    return source

if __name__ == '__main__':
    source, target = map(Path, sys.argv[1:3])
    assert source.resolve() != target.resolve()
    target.write_text(patch(source.read_text()), encoding='utf-8')

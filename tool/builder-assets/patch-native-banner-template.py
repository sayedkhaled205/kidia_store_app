"""Add native banner controls to a copied central Home template; never edit live in place."""
import html
import json
from pathlib import Path
import re
import sys

ACTIONS = {'': 'No Action', 'category': 'Category', 'collection': 'Collection', 'product': 'Product', 'brand': 'Brand', 'brands': 'All Brands', 'search': 'Search', 'external': 'External URL'}

def patch_home(source):
    additions = 0
    def hero(match):
        nonlocal additions
        field = re.search(r'\bname="([^"]+\[items\]\[[^\]]+\])\[button_link\]"', match[0])
        if not field:
            return match[0]
        prefix = field[1]
        following = source[match.end():].lstrip()
        if following.startswith('<p class="mobishop-builder-field mobishop-repeatable-field--action-type" data-kidia-native-banner-actions="1">'):
            return match[0]
        additions += 1
        options = ''.join('<option value="' + value + '">' + label + '</option>' for value, label in ACTIONS.items())
        # Keep the legacy field so older saved website links are not discarded.
        return match[0] + '<p class="mobishop-builder-field mobishop-repeatable-field--action-type" data-kidia-native-banner-actions="1"><label>Action Type</label><select name="' + prefix + '[action_type]">' + options + '</select></p><p class="mobishop-builder-field mobishop-repeatable-field--action-value"><label>Action Value</label><input type="text" name="' + prefix + '[action_value]" value=""></p>'
    output = re.sub(r'<p\b[^>]*class="[^"]*mobishop-repeatable-field--button-link[^"]*"[^>]*>.*?</p>', hero, source, flags=re.S)
    # Scope support to image-banner blocks, including the add-element template.
    support = 0
    markers = list(re.finditer(r'<(?:div|article|section)\b[^>]*\bdata-type="([^"]+)"[^>]*>', output))
    for i in range(len(markers) - 1, -1, -1):
        marker = markers[i]
        if marker[1] != 'image_banner':
            continue
        end = markers[i + 1].start() if i + 1 < len(markers) else len(output)
        section = output[marker.start():end]
        def add_support(match):
            nonlocal support
            if 'value="support"' in match[0]:
                return match[0]
            support += 1
            return match[0].replace('</select>', '<option value="support">Customer Support</option></select>')
        section = re.sub(r'<select\b[^>]*\bname="blocks\[[^\]]+\]\[settings\]\[action_type\]"[^>]*>.*?</select>', add_support, section, flags=re.S)
        output = output[:marker.start()] + section + output[end:]
    if additions == 0 and 'data-kidia-native-banner-actions="1"' not in source:
        raise ValueError('No known hero Button Link fields found; inspect template before patching')
    if support == 0 and not re.search(r'data-type="image_banner".*?value="support"', source, re.S):
        raise ValueError('Image banner action selector not found; inspect template before patching')
    return output, {'hero_controls_added': additions, 'support_options_added': support}

if __name__ == '__main__':
    source, destination = map(Path, sys.argv[1:3])
    assert source.resolve() != destination.resolve(), 'Write to a new staged file only'
    updated, stats = patch_home(source.read_text())
    with destination.open('x') as handle:
        handle.write(updated)
    print(json.dumps(stats))

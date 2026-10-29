"""Copy merchant-approved appearance into Kids without copying store data."""
import argparse
import base64
import copy
import json
import re
from pathlib import Path

STYLE = re.compile(r'(^show_|^hide_|^enable_|^use_|^auth_logo_|_color$|_background$|_size$|_height$|_width$|_percent$|_padding$|^padding_|^margin_|^space_|_gap$|^gap$|_radius$|_style$|_shape$|_fit$|_scale$|_position$|_effect$|_align$|_weight$|_lines$|_opacity$|_blur$|_strength$|_offset_[xy]$|_ratio$|_inset$|_columns$|^columns$|^height$|^layout$|_layout$|^shadow$|^font_|^navigation_mode$|^safe_area$|^direction$|^access_mode$|^countdown_enabled$|^duration$|^image_swipe$|^enabled$)')
DENIED = re.compile(r'(^id$|_id$|_ids$|_url$|_urls$|^items$|^source$|^category$|^categories$|^products$|token|secret|password|email|phone|whatsapp|contact)')


def form(entries):
    root = {}
    for key, value in entries:
        parts = re.findall(r'[^\[\]]+', key)
        if not parts or parts[0] not in {'layout', 'category_general', 'splash'}:
            continue
        node = root
        for part in parts[:-1]:
            node = node.setdefault(part, {})
        node[parts[-1]] = value

    def arrays(value):
        if not isinstance(value, dict):
            return value
        if value and all(k.isdecimal() for k in value):
            return [arrays(value[k]) for k in sorted(value, key=int)]
        return {k: arrays(v) for k, v in value.items()}
    return arrays(root)


def scalar(value, original):
    if isinstance(original, bool):
        return value not in [False, 0, '0', '', None]
    if isinstance(original, (int, float)) or isinstance(value, str) and re.fullmatch(r'-?\d+(?:\.\d+)?', value):
        try:
            number = float(value)
            return int(number) if number.is_integer() else number
        except (ValueError, TypeError):
            pass
    return value


def appearance(target, current):
    for key, value in current.items():
        if key == 'layout_json':
            layout = json.loads(value) if isinstance(value, str) else value
            # Composer layout is position data, never arbitrary content.
            assert isinstance(layout, dict)
            for row in layout.get('rows', []):
                for column in row.get('columns', []):
                    assert set(column) <= {'width', 'align', 'items'}
                    assert all(isinstance(x, str) and re.fullmatch(r'[a-z_]+', x) for x in column.get('items', []))
            target[key] = json.dumps(layout, separators=(',', ':'), ensure_ascii=False)
        elif not DENIED.search(key) and (STYLE.search(key) or key in {'after_summary', 'share_style_across_app'} or key.endswith(('_enabled', '_mode', '_variant', '_spacing'))) and isinstance(value, (str, bool, int, float)):
            target[key] = scalar(value, target.get(key))


def element(target, current):
    if 'enabled' in current:
        target['enabled'] = scalar(current['enabled'], True)
    appearance(target.setdefault('settings', {}), current.get('settings', {}))


def capture(packages, screens):
    result = copy.deepcopy(packages)
    kids = result['kids_baby']
    for page, layout in kids['pages'].items():
        screen = 'size-chart-builder' if page == 'size_chart' else page + '-builder'
        saved = form(screens.get(screen, {}).get('entries', [])).get('layout', {})
        if not saved:
            raise ValueError('Missing saved page: ' + screen)
        appearance(layout.setdefault('settings', {}), saved.get('settings', {}))
        for chrome in ('header', 'footer'):
            if chrome in saved:
                element(layout[chrome], saved[chrome])
        by_id = {v['id']: v for v in saved.get('elements', [])}
        for item in layout.get('elements', []):
            if item['id'] in by_id:
                element(item, by_id[item['id']])
    home_entries = dict(screens['home-builder']['entries'])
    assert home_entries.get('blocks_payload_encoding') == 'base64'
    home = json.loads(base64.b64decode(home_entries['blocks_payload']))
    by_id = {v['id']: v for v in home}
    for block in kids['home']:
        current = by_id.get(block['id'])
        if current:
            appearance(block['settings'], current.get('settings', {}))
            block['enabled'] = current.get('status', 'published') == 'published'
            block['order'] = current.get('order', block.get('order', 0))
    positions = {block['id']: index for index, block in enumerate(home)}
    kids['home'].sort(key=lambda block: positions.get(block['id'], len(home)))
    category = form(screens['category-builder']['entries']).get('category_general', {})
    assert category, 'Missing category appearance'
    appearance(kids['category']['general'], category)
    splash = form(screens['splash']['entries']).get('splash', {})
    appearance(kids['splash'], splash)
    # Setup supplies every connected merchant's name/logo at apply time.
    kids['identity']['app_name'] = 'Kids & Baby'
    kids['identity']['logo_url'] = ''
    kids['splash']['image_url'] = ''
    kids['splash']['image_id'] = 0
    kids['splash']['store_name'] = 'Kids & Baby'
    for layout in kids['pages'].values():
        header = layout.get('header', {}).get('settings', {})
        header.update(logo_url='', logo_id=0, logo_text='Kids & Baby')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('presets')
    parser.add_argument('screens')
    parser.add_argument('output')
    args = parser.parse_args()
    presets = json.loads(Path(args.presets).read_text(encoding='utf-8-sig'))
    screens = json.loads(Path(args.screens).read_text(encoding='utf-8-sig'))
    output = capture(presets, screens)
    Path(args.output).write_text(json.dumps(output, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print('Kids appearance prepared; all other presets preserved.')

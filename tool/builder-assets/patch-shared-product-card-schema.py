import json,re
def patch(source):
    match=re.search(r"(private const FIELD_TYPES_JSON = ')(.*?)(';)",source)
    assert match
    fields=json.loads(match[2]);grid=fields['pages']['catalog']['product_grid']
    assert grid.get('share_style_across_app') in (None,'checkbox')
    grid['share_style_across_app']='checkbox'
    return source[:match.start(2)]+json.dumps(fields,separators=(',',':'),ensure_ascii=False).replace("'",r"\u0027")+source[match.end(2):]

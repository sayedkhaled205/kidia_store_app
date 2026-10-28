# Kids category View all

Kids now includes a root Categories toolbar whose View all action opens the
unfiltered `/products` catalog. At a child level the same button retains the
selected category route. The root has no back arrow. Both levels use a soft
brand tint, readable surface text, a clearer border and 13px semibold-size text
at the existing compact button height.

`category_general.root_view_all_mode` (`hidden`/`visible`) and `view_all_style`
(`outline`/`soft`) are normal saved presentation settings. Existing themes retain
hidden/outline defaults; the shared Kids appearance sets visible/soft. The
Builder exposes both choices in category settings. Connector 1.46.113 preserves
them through save/read and includes them in category presentation responses.

The Flutter renderer is new: existing installed applications need a new build
once. Subsequent changes to these choices use the existing Publish now flow.
No category records, product filters, header/cart positions or other theme
appearance values are changed by the preset update.

Validation: 47 catalog/model widget tests, including root and scoped navigation
at 320px with RTL/LTR and 1.5 text scaling; nine category editor tests; five Kids
capture tests; connector manifest validation. Deployment helper stages current
live files, checks for concurrent edits, and keeps byte-for-byte rollback copies.

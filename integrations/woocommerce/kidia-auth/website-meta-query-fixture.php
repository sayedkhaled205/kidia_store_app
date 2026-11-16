<?php
/** Synthetic WordPress meta-query evaluator shared by website contract fixtures. */
function website_fixture_meta_matches(int $id, array $query): bool {
    if (isset($query['key'])) {
        $exists = array_key_exists($query['key'], $GLOBALS['meta'][$id] ?? []);
        $value = $GLOBALS['meta'][$id][$query['key']] ?? '';
        return match ($query['compare'] ?? '=') {
            'NOT EXISTS' => !$exists,
            'EXISTS' => $exists,
            'IN' => $exists && in_array($value, $query['value'], true),
            '=' => $exists && $value === $query['value'],
            default => throw new RuntimeException('Unsupported fixture meta comparison'),
        };
    }
    $results = [];
    foreach ($query as $clause) if (is_array($clause)) $results[] = website_fixture_meta_matches($id, $clause);
    return ($query['relation'] ?? 'AND') === 'OR' ? in_array(true, $results, true) : !in_array(false, $results, true);
}

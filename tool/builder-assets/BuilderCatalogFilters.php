<?php
namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/** Public WooCommerce facets, scoped to the already-authorized builder store. */
final class BuilderCatalogFilters
{
    public function forStore($store): array
    {
        $empty = ['tags' => [], 'sizes' => [], 'colors' => []];
        if ($store->isShopify() || $store->isOdoo()) {
            return ['filter_options' => $empty];
        }
        try {
            $base = rtrim((string) $store->site_url, '/');
            $key = 'builder:filters:v1:'.hash('sha256', $store->public_id.'|'.$base);
            $options = Cache::remember($key, 300, fn () => self::read(
                function (string $path, array $query, float $seconds) use ($base): array {
                    $response = Http::acceptJson()->withoutRedirecting()
                        ->connectTimeout(min(3, $seconds))->timeout($seconds)
                        ->get($base.$path, $query)->throw();
                    return ['items' => $response->json(), 'pages' => $response->header('X-WP-TotalPages')];
                }
            ));
            return ['filter_options' => $options];
        } catch (\Throwable $error) {
            report($error);
            return ['filter_options' => $empty, 'items_error' => 'Store filters could not be loaded. Please retry.'];
        }
    }

    /** The injected public reader makes pagination and failure paths testable. */
    public static function read(callable $fetch, float $budget = 12): array
    {
        $deadline = microtime(true) + $budget;
        $terms = static function (string $path) use ($fetch, $deadline): array {
            $all = [];
            for ($page = 1; $page <= 50; ++$page) {
                $left = $deadline - microtime(true);
                if ($left <= 0) throw new \RuntimeException('Filter deadline exceeded');
                $response = $fetch($path, ['page' => $page, 'per_page' => 100, 'hide_empty' => 'true', 'orderby' => 'name', 'order' => 'asc'], min(6, $left));
                $items = $response['items'] ?? null;
                if (!is_array($items) || !array_is_list($items)) throw new \RuntimeException('Invalid filter response');
                $before = count($all);
                foreach ($items as $item) {
                    if (is_array($item) && (int) ($item['id'] ?? 0) > 0) $all[(int) $item['id']] = $item;
                }
                $pages = is_numeric($response['pages'] ?? null) ? (int) $response['pages'] : null;
                if ($pages !== null ? $page >= $pages : count($items) < 100) return array_values($all);
                if (count($all) === $before) throw new \RuntimeException('Repeated filter pagination');
            }
            throw new \RuntimeException('Filter pagination limit exceeded');
        };
        $root = '/wp-json/wc/store/v1/products';
        $options = ['tags' => [], 'sizes' => [], 'colors' => []];
        foreach ($terms($root.'/tags') as $tag) {
            if (trim((string) ($tag['name'] ?? '')) !== '') $options['tags'][] = ['id' => (int) $tag['id'], 'label' => html_entity_decode($tag['name'], ENT_QUOTES | ENT_HTML5, 'UTF-8')];
        }
        foreach ($terms($root.'/attributes') as $attribute) {
            $taxonomy = (string) ($attribute['taxonomy'] ?? '');
            $name = $taxonomy.' '.($attribute['name'] ?? '');
            if (!str_starts_with($taxonomy, 'pa_')) continue;
            $target = preg_match('/size|مقاس/iu', $name) ? 'sizes' : (preg_match('/colou?r|لون|الوان|ألوان/iu', $name) ? 'colors' : null);
            if ($target === null) continue;
            foreach ($terms($root.'/attributes/'.(int) $attribute['id'].'/terms') as $term) {
                if (empty($term['slug'])) continue;
                $options[$target][] = ['taxonomy' => $taxonomy, 'term' => (string) $term['slug'], 'label' => html_entity_decode((string) ($term['name'] ?? $term['slug']), ENT_QUOTES | ENT_HTML5, 'UTF-8')];
            }
        }
        return $options;
    }
}

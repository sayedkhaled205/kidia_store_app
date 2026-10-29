<?php
namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/** Public WooCommerce facets, scoped to the already-authorized builder store. */
final class BuilderCatalogFilters
{
    private static function label($value): string
    {
        $label = html_entity_decode((string) $value, ENT_QUOTES | ENT_HTML5, 'UTF-8');
        if (preg_match('/class\s*=|^\/?i\s*\/>/i', $label)) return '';
        return trim(strip_tags($label));
    }
    public function forStore($store): array
    {
        $empty = ['tags' => [], 'sizes' => [], 'colors' => [], 'brands' => []];
        if ($store->isShopify() || $store->isOdoo()) {
            return ['filter_options' => $empty];
        }
        try {
            $base = rtrim((string) $store->site_url, '/');
            $key = 'builder:filters:v3:'.hash('sha256', $store->public_id.'|'.$base);
            $options = Cache::remember($key, 300, fn () => self::read(
                function (string $path, array $query, float $seconds) use ($base): array {
                    $response = Http::acceptJson()->withoutRedirecting()
                        ->connectTimeout(min(3, $seconds))->timeout($seconds)
                        ->get($base.$path, $query);
                    if ($path === '/wp-json/mobishop/v1/brands' && in_array($response->status(), [404, 501], true)) return ['items'=>[], 'pages'=>1];
                    $response->throw();
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
        $options = ['tags' => [], 'sizes' => [], 'colors' => [], 'brands' => []];
        foreach ($terms($root.'/tags') as $tag) {
            $label = self::label($tag['name'] ?? '');
            if ($label !== '') $options['tags'][] = ['id' => (int) $tag['id'], 'label' => $label];
        }
        foreach ($terms($root.'/attributes') as $attribute) {
            $taxonomy = (string) ($attribute['taxonomy'] ?? '');
            $name = $taxonomy.' '.($attribute['name'] ?? '');
            if (!str_starts_with($taxonomy, 'pa_')) continue;
            $target = preg_match('/size|مقاس/iu', $name) ? 'sizes' : (preg_match('/colou?r|لون|الوان|ألوان/iu', $name) ? 'colors' : null);
            if ($target === null) continue;
            foreach ($terms($root.'/attributes/'.(int) $attribute['id'].'/terms') as $term) {
                $label = self::label($term['name'] ?? $term['slug'] ?? '');
                if (empty($term['slug']) || $label === '') continue;
                $options[$target][] = ['taxonomy' => $taxonomy, 'term' => (string) $term['slug'], 'label' => $label];
            }
        }
        foreach ($terms('/wp-json/mobishop/v1/brands') as $brand) {
            $name = self::label($brand['name'] ?? '');
            if ($name === '' || empty($brand['slug'])) continue;
            $options['brands'][] = ['id' => (int) $brand['id'], 'name' => $name, 'slug' => (string) $brand['slug'], 'count' => max(0, (int) ($brand['count'] ?? 0))];
        }
        return $options;
    }
}

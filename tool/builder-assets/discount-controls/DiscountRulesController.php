<?php
namespace App\Http\Controllers\Portal;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

/** Auth/session/CSRF stay in the existing account route group. */
final class DiscountRulesController extends Controller
{
    public function handle(Request $request)
    {
        $request->validate(['store'=>'required|string|max:80']);
        $store = $request->user()->stores()->where('public_id', $request->input('store'))->firstOrFail();
        $headers = ['Cache-Control'=>'no-store, private', 'Vary'=>'Cookie'];
        if ($store->isShopify() || $store->isOdoo()) {
            return response()->json(['ok'=>false,'message'=>'These controls require a connected WooCommerce store.'], 422, $headers);
        }
        if (!$store->wordpress_user || !$store->wordpress_application_password) {
            return response()->json(['ok'=>false,'message'=>'Reconnect this store with an authorized administrator.'], 409, $headers);
        }
        $get = $request->isMethod('get');
        $allowed = $get ? ['store','operation','kind','search'] : ['store','operation','request_id','id','revision','title','channel','enabled','type','target','ids','discount_kind','value','min_qty','free_qty','gift_ids','date_from','date_to'];
        if (array_diff(array_keys($request->all()), $allowed) || strlen($request->getContent()) > 24000) {
            return response()->json(['ok'=>false,'message'=>'Invalid offer fields.'], 422, $headers);
        }
        if ($get) $request->validate(['operation'=>'required|in:targets','kind'=>'required|in:products,categories','search'=>'nullable|string|max:200']);
        else $request->validate(['operation'=>'required|in:create,update,clone','request_id'=>'required|uuid','channel'=>'required|in:all,website,mobile','enabled'=>'required|boolean']);
        $input = $request->except('store');
        try {
            $client = Http::acceptJson()->withBasicAuth($store->wordpress_user, $store->wordpress_application_password)
                ->withOptions(['allow_redirects'=>false])->connectTimeout(10)->timeout(50);
            $url = rtrim($store->site_url, '/') . '/wp-json/mobishop/v1/central/discount-rules';
            $upstream = $get ? $client->get($url, $input) : $client->post($url, $input);
            if (!$upstream->successful() || $upstream->json('ok') !== true) {
                // Only curated connector validation errors are returned. No upstream
                // HTML, stack traces, credentials, or arbitrary plugin messages.
                $known = in_array($upstream->json('code'), ['invalid_discount','discount_conflict','discount_unavailable'], true);
                $status = $known && in_array($upstream->status(), [409,422], true) ? $upstream->status() : 502;
                $message = $known ? $upstream->json('message') : 'The store could not confirm this action. Retry before creating another offer.';
                return response()->json(['ok'=>false,'message'=>$message], $status, $headers);
            }
            return response()->json($upstream->json(), 200, $headers);
        } catch (\Throwable $error) {
            return response()->json(['ok'=>false,'message'=>'The store did not confirm saving. Retry the same offer; do not create a duplicate.'], 502, $headers);
        }
    }
}

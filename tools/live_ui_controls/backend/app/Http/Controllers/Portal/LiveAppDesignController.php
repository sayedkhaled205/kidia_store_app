<?php
namespace App\Http\Controllers\Portal;

use App\Http\Controllers\Controller;
use App\Models\Store;
use App\Services\LiveAppDesign;
use App\Services\LiveAppUiControls;
use Illuminate\Http\Request;

final class LiveAppDesignController extends Controller
{
    private function owned(Request $request): Store
    {
        return $request->user()->accessibleStores()->where('public_id', $request->input('store'))->firstOrFail();
    }
    public function status(Request $request)
    {
        return response()->json(LiveAppDesign::status($this->owned($request)))->header('Cache-Control', 'no-store, private');
    }
    public function controls(Request $request)
    {
        return response()->json(LiveAppUiControls::status($this->owned($request)))->header('Cache-Control', 'no-store, private');
    }
    public function saveControls(Request $request)
    {
        $data = $request->validate(['controls' => 'present|array|max:64', 'controls_digest' => 'required|string|size:64']);
        return response()->json(LiveAppUiControls::save($this->owned($request), (int)$request->user()->id,
            $data['controls'], $data['controls_digest']))->header('Cache-Control', 'no-store, private');
    }
    public function publish(Request $request)
    {
        $data = $request->validate(['revision' => 'required|integer|min:0', 'draft_digest' => 'required|string|size:64']);
        return response()->json(LiveAppDesign::publish($this->owned($request), (int)$request->user()->id,
            (int)$data['revision'], $data['draft_digest']))->header('Cache-Control', 'no-store, private');
    }
    public function rollback(Request $request)
    {
        $data = $request->validate(['revision' => 'required|integer|min:1']);
        return response()->json(LiveAppDesign::publish($this->owned($request), (int)$request->user()->id,
            (int)$data['revision'], null, true))->header('Cache-Control', 'no-store, private');
    }
    public function show(Request $request, string $store)
    {
        $model = Store::where('public_id', $store)->firstOrFail();
        $release = LiveAppDesign::query($model)->orderByDesc('id')->first();
        abort_unless($release, 404);
        $etag = '"'.$release->id.'-'.$release->digest.'"';
        $headers = ['ETag' => $etag, 'Cache-Control' => 'public, max-age=0, must-revalidate', 'X-Content-Type-Options' => 'nosniff'];
        if ($request->header('If-None-Match') === $etag) return response('', 304, $headers);
        return response()->json(LiveAppDesign::envelope($release), 200, $headers);
    }
}

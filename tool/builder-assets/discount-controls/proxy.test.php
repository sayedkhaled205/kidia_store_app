<?php
// Run in the Laravel project, with the candidate controller path as argv[1].
require getcwd().'/vendor/autoload.php';
$app=require getcwd().'/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
require $argv[1];
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use App\Http\Controllers\Portal\DiscountRulesController;
$checks=0;
$assert=static function($ok,$message)use(&$checks){++$checks;if(!$ok)throw new RuntimeException($message);};
class OfferFixtureStore {
    public $wordpress_user='fixture-merchant', $wordpress_application_password='fixture-only', $site_url='https://merchant.invalid';
    public function isShopify(){return false;}
    public function isOdoo(){return false;}
}
class OfferFixtureQuery {
    private $match=false;
    public function where($field,$value){$this->match=$field==='public_id'&&$value==='owned-store';return $this;}
    public function firstOrFail(){if(!$this->match)throw new Illuminate\Database\Eloquent\ModelNotFoundException();return new OfferFixtureStore();}
}
class OfferFixtureUser {public function stores(){return new OfferFixtureQuery();}}
$make=static function($method,$body){$r=Request::create('/account/builder/discount-rules',$method,$body);$r->setUserResolver(fn()=>new OfferFixtureUser());return $r;};
$controller=new DiscountRulesController();
$input=['store'=>'owned-store','operation'=>'create','request_id'=>'1c660e22-a332-4cc8-b46a-fba4d5589b11','enabled'=>false,'channel'=>'mobile'];
$scenarios=[
    [200,['ok'=>true,'id'=>12],200],
    [409,['code'=>'discount_conflict','message'=>'Reload offer.'],409],
    [422,['code'=>'invalid_discount','message'=>'Invalid quantity.'],422],
    [409,['code'=>'unexpected','message'=>'private upstream detail'],502],
    [503,['code'=>'discount_save_unconfirmed','message'=>'private upstream detail'],502],
];
$sequence=Http::sequence();foreach($scenarios as [$status,$body])$sequence->push($body,$status);
Http::fake(['merchant.invalid/*'=>$sequence]);
foreach($scenarios as [$upstream,$body,$expected]) {
    $response=$controller->handle($make('POST',$input));
    $assert($response->getStatusCode()===$expected,'Curated upstream status');
    $assert(!str_contains($response->getContent(),'private upstream detail'),'No upstream error leak');
    $assert(str_contains($response->headers->get('Cache-Control'),'no-store'),'Private no-store response');
    Http::assertSent(fn($r)=>$r->url()==='https://merchant.invalid/wp-json/mobishop/v1/central/discount-rules'&&$r['request_id']===$input['request_id']&&!isset($r['store']));
}
Http::fake();
try{$controller->handle($make('POST',array_replace($input,['store'=>'another-store'])));throw new RuntimeException('Cross-store accepted');}catch(Illuminate\Database\Eloquent\ModelNotFoundException $expected){++$checks;}
Http::assertNothingSent();
$response=$controller->handle($make('POST',$input+['arbitrary'=>'value']));
$assert($response->getStatusCode()===422,'Unknown fields rejected');Http::assertNothingSent();
foreach(['channel'=>'invalid','request_id'=>'invalid','operation'=>'delete'] as $key=>$value){
    try{$controller->handle($make('POST',array_replace($input,[$key=>$value])));throw new RuntimeException('Invalid request accepted');}catch(Illuminate\Validation\ValidationException $expected){++$checks;}
}
Http::assertNothingSent();
echo 'DISCOUNT_PROXY_QA '.json_encode(['passed'=>true,'checks'=>$checks]).PHP_EOL;

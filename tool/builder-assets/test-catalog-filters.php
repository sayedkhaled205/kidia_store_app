<?php
require __DIR__.'/BuilderCatalogFilters.php';
use App\Services\BuilderCatalogFilters;
function check($value, $message) { if (!$value) throw new RuntimeException($message); }
$calls=[];
$options=BuilderCatalogFilters::read(function($path,$query,$seconds) use (&$calls) {
    $calls[]=$path;
    check($seconds>0 && $seconds<=6,'bounded timeout');
    check($query['hide_empty']==='true','hide empty terms');
    if(str_ends_with($path,'/tags')) return ['items'=>[['id'=>$query['page'],'name'=>'Tag &amp; name']], 'pages'=>2];
    if(str_ends_with($path,'/attributes')) return ['items'=>[['id'=>8,'taxonomy'=>'pa_المقاس','name'=>'المقاس'],['id'=>9,'taxonomy'=>'pa_color','name'=>'Color'],['id'=>10,'taxonomy'=>'pa_material','name'=>'Material']]];
    if(str_ends_with($path,'/brands')) return ['items'=>[['id'=>$query['page'],'slug'=>'brand-'.$query['page'],'name'=>'Brand &amp; name','count'=>2]],'pages'=>2];
    return ['items'=>[['id'=>1,'slug'=>'exact-slug','name'=>'Small']]];
});
check(count($calls)===7,'all pages and only supported taxonomies');
check(count($options['brands'])===2 && $options['brands'][1]['id']===2 && $options['brands'][0]['name']==='Brand & name','complete brand identities and clean labels');
check(count($options['tags'])===2 && $options['tags'][0]['label']==='Tag & name','tag ids and label');
check($options['sizes'][0]['taxonomy']==='pa_المقاس' && $options['sizes'][0]['term']==='exact-slug','source taxonomy and slug');
check(count($options['colors'])===1,'color terms');
foreach ([fn()=>['items'=>['bad'=>'data']], fn()=>['items'=>[['id'=>1]],'pages'=>20]] as $reader) {
    $thrown=false; try {BuilderCatalogFilters::read($reader);} catch(RuntimeException $e) {$thrown=true;}
    check($thrown,'malformed and repeated page fail visibly');
}
$thrown=false; try {BuilderCatalogFilters::read(fn()=>[],0);} catch(RuntimeException $e) {$thrown=true;}
check($thrown,'total deadline');
$clean=BuilderCatalogFilters::read(fn($p,$q,$t)=>['items'=>str_ends_with($p,'/tags')?[['id'=>1,'name'=>'i/>'],['id'=>2,'name'=>'i class="broken">'],['id'=>3,'name'=>'<b>Kids &amp; Baby</b>']]:[]]);
check($clean['tags']===[['id'=>3,'label'=>'Kids & Baby']],'imported markup excluded without changing source terms');
echo "Catalog filter backend contracts: passed\n";

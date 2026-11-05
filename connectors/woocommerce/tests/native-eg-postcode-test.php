<?php
/** Native country locale scope. Synthetic state only; no orders/providers outside fixtures. */
require __DIR__ . '/native-checkout-safety50-contract-test.php';
class WC_Countries {
    public array $locale = [];
    public function get_country_locale(): array {
        return $this->locale ?: $this->locale = [
            'default'=>[
                'postcode'=>['required'=>true,'label'=>'Postcode'],
                'city'=>['required'=>true,'label'=>'City'],
            ],
            'EG'=>['postcode'=>['label'=>'Postcode']],
            'US'=>['postcode'=>['required'=>true]],
        ];
    }
}
function missing_locale_fields50(WC_Countries $countries, string $country, array $values): array {
    // Store API merges each country override with default and checks required/hidden.
    $locales = $countries->get_country_locale();
    $missing=[];
    foreach ($locales['default'] as $key=>$defaults) {
        $field=array_replace($defaults,$locales[$country][$key]??[]);
        if (($field['required']??false)===true && ($field['hidden']??false)!==true && trim($values[$key]??'')==='') $missing[]=$key;
    }
    return $missing;
}
function postcode_fixture50(): array {
    [$api,$store]=fixture50();
    $countries=new WC_Countries();
    $countries->get_country_locale(); // Include a locale cached before native dispatch.
    WC()->countries=$countries;
    return [$api,$store,$countries];
}
foreach (['success','throw_before_order','generic_400_before_order'] as $mode) {
    [$api,$store,$original]=postcode_fixture50();
    $before=$original->locale;
    $core=core50($api,null,$mode);
    $observed=[];
    dispatch50($api,request50('postcode-'.$mode),function($request) use($core,$original,&$observed) {
        $native=WC()->countries;
        // Record inside; assert outside because the guard intentionally catches exceptions.
        $observed=[
            'Native gets an isolated countries instance'=>$native!==$original,
            'Blank EG postcode matches hidden native form'=>missing_locale_fields50($native,'EG',['city'=>'Town'])===[],
            'International postcode remains required'=>missing_locale_fields50($native,'US',['city'=>'Town'])===['postcode'],
            'Other required EG fields remain enforced'=>missing_locale_fields50($native,'EG',[])===['city'],
            'Original web country cache remains strict inside dispatch'=>missing_locale_fields50($original,'EG',['city'=>'Town'])===['postcode'],
        ];
        return $core($request);
    });
    check50(count($observed)===5,'Native callback ran');
    foreach($observed as $label=>$ok) check50($ok,$label);
    check50(WC()->countries===$original && $original->locale===$before,'Country object/cache restored after success or failure');
}
foreach (['web','expired','cart'] as $mode) {
    [$api,$store,$original]=postcode_fixture50();
    $request=request50('scope-'.$mode);
    if ($mode==='web') unset($request->body['extensions']);
    if ($mode==='cart') $request->route='/wc/store/v1/cart';
    if ($mode==='expired') unset($GLOBALS['auth50']['SESSION-A-DO-NOT-PERSIST']);
    $called=false;
    dispatch50($api,$request,function() use (&$called){$called=true; return new WP_REST_Response([]);});
    check50(!$called,'Non-native or unauthorized callback does not run');
    check50(WC()->countries===$original && missing_locale_fields50($original,'EG',['city'=>'Town'])===['postcode'],'Web/cart/unauthorized requests cannot change locale');
}
echo "PASS native EG postcode scope, cache restoration and international validation\n";

<?php
/**
 * Dedicated manual bundle workspace.
 *
 * @package Kidia_Mobile_CMS
 */

defined( 'ABSPATH' ) || exit;

$bundle_type_labels = array(
	'fixed'             => __( 'Fixed bundle', 'kidia-mobile-cms' ),
	'multipack'         => __( 'Multipack', 'kidia-mobile-cms' ),
	'mix_match'         => __( 'Mix & Match', 'kidia-mobile-cms' ),
	'build_box'         => __( 'Build your box', 'kidia-mobile-cms' ),
	'buy_x_get_y'       => __( 'Buy X from A + Y from B', 'kidia-mobile-cms' ),
	'bogo'              => __( 'BOGO', 'kidia-mobile-cms' ),
	'frequently_bought' => __( 'Frequently bought together', 'kidia-mobile-cms' ),
	'complete_look'     => __( 'Complete the look', 'kidia-mobile-cms' ),
	'composite'         => __( 'Composite step builder', 'kidia-mobile-cms' ),
	'quantity'          => __( 'Quantity bundle', 'kidia-mobile-cms' ),
	'category'          => __( 'Category bundle', 'kidia-mobile-cms' ),
	'gift'              => __( 'Gift bundle', 'kidia-mobile-cms' ),
	'chained'           => __( 'Chained products', 'kidia-mobile-cms' ),
	'addons'            => __( 'Optional add-ons', 'kidia-mobile-cms' ),
	'mystery'           => __( 'Mystery box', 'kidia-mobile-cms' ),
	'subscription'      => __( 'Subscription bundle', 'kidia-mobile-cms' ),
	'ai'                => __( 'AI-selected bundle', 'kidia-mobile-cms' ),
);
?>
<div class="wrap kidia-ai-page kidia-bundles-page">
	<header class="kidia-ai-page__hero">
		<div>
			<span class="dashicons dashicons-products"></span>
			<div>
				<h1><?php esc_html_e( 'Bundles', 'kidia-mobile-cms' ); ?></h1>
				<p><?php esc_html_e( 'Create manual bundle recipes here. AI Offer Studio remains focused only on generated, evidence-backed decisions.', 'kidia-mobile-cms' ); ?></p>
			</div>
		</div>
		<div class="kidia-ai-page__trust">
			<strong><?php echo esc_html( (string) count( $bundle_recipes ) ); ?></strong>
			<span><?php esc_html_e( 'saved bundles', 'kidia-mobile-cms' ); ?></span>
		</div>
	</header>

	<?php if ( isset( $_GET['bundle_saved'] ) ) : ?>
		<div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Bundle recipe saved successfully and is ready for Home Page or app placement.', 'kidia-mobile-cms' ); ?></p></div>
	<?php endif; ?>

	<section class="kidia-bundle-manager">
		<header>
			<div>
				<h2><?php esc_html_e( 'Create a manual bundle', 'kidia-mobile-cms' ); ?></h2>
				<p><?php esc_html_e( 'Use product IDs, category IDs, or both. Saving as Published makes the recipe available to its selected channel.', 'kidia-mobile-cms' ); ?></p>
			</div>
		</header>
		<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" data-kidia-bundle-form>
			<input type="hidden" name="action" value="kidia_mobile_save_bundle_recipe">
			<?php wp_nonce_field( 'kidia_mobile_save_bundle_recipe', 'kidia_mobile_bundle_nonce' ); ?>
			<div class="kidia-ai-bundle-grid">
				<label><span><?php esc_html_e( 'Bundle name', 'kidia-mobile-cms' ); ?></span><input type="text" name="bundle[name]" required></label>
				<label>
					<span><?php esc_html_e( 'Concept', 'kidia-mobile-cms' ); ?></span>
					<select name="bundle[type]">
						<?php foreach ( $bundle_type_labels as $value => $label ) : ?>
							<option value="<?php echo esc_attr( $value ); ?>"><?php echo esc_html( $label ); ?></option>
						<?php endforeach; ?>
					</select>
				</label>
				<label><span><?php esc_html_e( 'Product IDs', 'kidia-mobile-cms' ); ?></span><input type="text" name="bundle[product_ids]" placeholder="12, 45, 98"></label>
				<label><span><?php esc_html_e( 'Category IDs', 'kidia-mobile-cms' ); ?></span><input type="text" name="bundle[category_ids]" placeholder="3, 7"></label>
				<label><span><?php esc_html_e( 'Minimum items', 'kidia-mobile-cms' ); ?></span><input type="number" min="1" name="bundle[minimum_items]" value="2"></label>
				<label><span><?php esc_html_e( 'Maximum items', 'kidia-mobile-cms' ); ?></span><input type="number" min="1" name="bundle[maximum_items]" value="2"></label>
				<label>
					<span><?php esc_html_e( 'Pricing rule', 'kidia-mobile-cms' ); ?></span>
					<select name="bundle[pricing]">
						<option value="percentage"><?php esc_html_e( 'Percentage off', 'kidia-mobile-cms' ); ?></option>
						<option value="fixed_discount"><?php esc_html_e( 'Fixed discount', 'kidia-mobile-cms' ); ?></option>
						<option value="fixed"><?php esc_html_e( 'Fixed bundle price', 'kidia-mobile-cms' ); ?></option>
						<option value="cheapest_free"><?php esc_html_e( 'Cheapest free', 'kidia-mobile-cms' ); ?></option>
						<option value="tiered"><?php esc_html_e( 'Tiered', 'kidia-mobile-cms' ); ?></option>
						<option value="none"><?php esc_html_e( 'No discount', 'kidia-mobile-cms' ); ?></option>
					</select>
				</label>
				<label><span><?php esc_html_e( 'Value', 'kidia-mobile-cms' ); ?></span><input type="number" min="0" step=".01" name="bundle[discount_value]" value="10"></label>
				<label>
					<span><?php esc_html_e( 'Channel', 'kidia-mobile-cms' ); ?></span>
					<select name="bundle[channel]">
						<option value="all"><?php esc_html_e( 'Website + Mobile App', 'kidia-mobile-cms' ); ?></option>
						<option value="website"><?php esc_html_e( 'Website only', 'kidia-mobile-cms' ); ?></option>
						<option value="mobile"><?php esc_html_e( 'Mobile App only', 'kidia-mobile-cms' ); ?></option>
					</select>
				</label>
				<label>
					<span><?php esc_html_e( 'Stock policy', 'kidia-mobile-cms' ); ?></span>
					<select name="bundle[stock_policy]">
						<option value="all_components"><?php esc_html_e( 'Require all components', 'kidia-mobile-cms' ); ?></option>
						<option value="hide_unavailable"><?php esc_html_e( 'Hide unavailable choices', 'kidia-mobile-cms' ); ?></option>
						<option value="allow_backorder"><?php esc_html_e( 'Allow backorders', 'kidia-mobile-cms' ); ?></option>
					</select>
				</label>
				<label><span><?php esc_html_e( 'Starts at', 'kidia-mobile-cms' ); ?></span><input type="datetime-local" name="bundle[starts_at]"></label>
				<label><span><?php esc_html_e( 'Ends at', 'kidia-mobile-cms' ); ?></span><input type="datetime-local" name="bundle[ends_at]"></label>
				<label class="kidia-ai-check"><input type="checkbox" name="bundle[allow_variants]" value="1" checked><span><?php esc_html_e( 'Customers may choose variants', 'kidia-mobile-cms' ); ?></span></label>
				<label class="kidia-ai-check"><input type="checkbox" name="bundle[allow_repeats]" value="1"><span><?php esc_html_e( 'Allow repeated products', 'kidia-mobile-cms' ); ?></span></label>
				<label class="kidia-ai-check"><input type="checkbox" name="bundle[coupon_stacking]" value="1"><span><?php esc_html_e( 'Allow coupon stacking', 'kidia-mobile-cms' ); ?></span></label>
				<label class="kidia-ai-check"><input type="checkbox" name="bundle[create_product]" value="1"><span><?php esc_html_e( 'Create a WooCommerce product for fixed bundles', 'kidia-mobile-cms' ); ?></span></label>
				<label>
					<span><?php esc_html_e( 'Status', 'kidia-mobile-cms' ); ?></span>
					<select name="bundle[status]">
						<option value="draft"><?php esc_html_e( 'Draft', 'kidia-mobile-cms' ); ?></option>
						<option value="published"><?php esc_html_e( 'Published', 'kidia-mobile-cms' ); ?></option>
					</select>
				</label>
			</div>
			<label class="kidia-ai-bundle-description"><span><?php esc_html_e( 'Customer-facing description', 'kidia-mobile-cms' ); ?></span><textarea name="bundle[description]" rows="3"></textarea></label>
			<footer><button class="button button-primary" type="submit"><?php esc_html_e( 'Save bundle recipe', 'kidia-mobile-cms' ); ?></button></footer>
		</form>
	</section>

	<section class="kidia-saved-bundles">
		<header>
			<div>
				<h2><?php esc_html_e( 'Saved bundles', 'kidia-mobile-cms' ); ?></h2>
				<p><?php esc_html_e( 'The list updates after every successful save.', 'kidia-mobile-cms' ); ?></p>
			</div>
		</header>
		<?php if ( $bundle_recipes ) : ?>
			<div>
				<?php foreach ( array_reverse( $bundle_recipes, true ) as $recipe ) : ?>
					<article>
						<div>
							<strong><?php echo esc_html( (string) ( $recipe['name'] ?? __( 'Bundle', 'kidia-mobile-cms' ) ) ); ?></strong>
							<small><?php echo esc_html( $bundle_type_labels[ (string) ( $recipe['type'] ?? '' ) ] ?? ucfirst( (string) ( $recipe['type'] ?? 'fixed' ) ) ); ?></small>
						</div>
						<span class="is-<?php echo esc_attr( (string) ( $recipe['status'] ?? 'draft' ) ); ?>"><?php echo esc_html( ucfirst( (string) ( $recipe['status'] ?? 'draft' ) ) ); ?></span>
						<dl>
							<div><dt><?php esc_html_e( 'Channel', 'kidia-mobile-cms' ); ?></dt><dd><?php echo esc_html( ucfirst( (string) ( $recipe['channel'] ?? 'all' ) ) ); ?></dd></div>
							<div><dt><?php esc_html_e( 'Products', 'kidia-mobile-cms' ); ?></dt><dd><?php echo esc_html( (string) count( (array) ( $recipe['product_ids'] ?? array() ) ) ); ?></dd></div>
							<div><dt><?php esc_html_e( 'Categories', 'kidia-mobile-cms' ); ?></dt><dd><?php echo esc_html( (string) count( (array) ( $recipe['category_ids'] ?? array() ) ) ); ?></dd></div>
							<div><dt><?php esc_html_e( 'Value', 'kidia-mobile-cms' ); ?></dt><dd><?php echo esc_html( (string) ( $recipe['discount_value'] ?? 0 ) ); ?></dd></div>
						</dl>
					</article>
				<?php endforeach; ?>
			</div>
		<?php else : ?>
			<div class="kidia-ai-empty"><span class="dashicons dashicons-products"></span><div><strong><?php esc_html_e( 'No manual bundles yet', 'kidia-mobile-cms' ); ?></strong><p><?php esc_html_e( 'Create the first recipe with the form above.', 'kidia-mobile-cms' ); ?></p></div></div>
		<?php endif; ?>
	</section>
</div>

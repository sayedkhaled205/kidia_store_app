<?php
/**
 * Dedicated manual bundle workspace.
 *
 * @package MobiShop
 */

defined( 'ABSPATH' ) || exit;

$bundle_type_labels = array(
	'fixed'             => __( 'Fixed bundle', 'mobishop' ),
	'multipack'         => __( 'Multipack', 'mobishop' ),
	'mix_match'         => __( 'Mix & Match', 'mobishop' ),
	'build_box'         => __( 'Build your box', 'mobishop' ),
	'buy_x_get_y'       => __( 'Buy X from A + Y from B', 'mobishop' ),
	'bogo'              => __( 'BOGO', 'mobishop' ),
	'frequently_bought' => __( 'Frequently bought together', 'mobishop' ),
	'complete_look'     => __( 'Complete the look', 'mobishop' ),
	'composite'         => __( 'Composite step builder', 'mobishop' ),
	'quantity'          => __( 'Quantity bundle', 'mobishop' ),
	'category'          => __( 'Category bundle', 'mobishop' ),
	'gift'              => __( 'Gift bundle', 'mobishop' ),
	'chained'           => __( 'Chained products', 'mobishop' ),
	'addons'            => __( 'Optional add-ons', 'mobishop' ),
	'mystery'           => __( 'Mystery box', 'mobishop' ),
	'subscription'      => __( 'Subscription bundle', 'mobishop' ),
	'ai'                => __( 'AI-selected bundle', 'mobishop' ),
);
?>
<div class="wrap mobishop-ai-page mobishop-bundles-page">
	<header class="mobishop-ai-page__hero">
		<div>
			<span class="dashicons dashicons-products"></span>
			<div>
				<h1><?php esc_html_e( 'Bundles', 'mobishop' ); ?></h1>
				<p><?php esc_html_e( 'Create manual bundle recipes here. AI Offer Studio remains focused only on generated, evidence-backed decisions.', 'mobishop' ); ?></p>
			</div>
		</div>
		<div class="mobishop-ai-page__trust">
			<strong><?php echo esc_html( (string) count( $bundle_recipes ) ); ?></strong>
			<span><?php esc_html_e( 'saved bundles', 'mobishop' ); ?></span>
		</div>
	</header>

	<?php if ( isset( $_GET['bundle_saved'] ) ) : ?>
		<div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Bundle recipe saved successfully and is ready for Home Page or app placement.', 'mobishop' ); ?></p></div>
	<?php endif; ?>

	<section class="mobishop-bundle-manager">
		<header>
			<div>
				<h2><?php esc_html_e( 'Create a manual bundle', 'mobishop' ); ?></h2>
				<p><?php esc_html_e( 'Use product IDs, category IDs, or both. Saving as Published makes the recipe available to its selected channel.', 'mobishop' ); ?></p>
			</div>
		</header>
		<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>" data-mobishop-bundle-form>
			<input type="hidden" name="action" value="mobishop_save_bundle_recipe">
			<?php wp_nonce_field( 'mobishop_save_bundle_recipe', 'mobishop_bundle_nonce' ); ?>
			<div class="mobishop-ai-bundle-grid">
				<label><span><?php esc_html_e( 'Bundle name', 'mobishop' ); ?></span><input type="text" name="bundle[name]" required></label>
				<label>
					<span><?php esc_html_e( 'Concept', 'mobishop' ); ?></span>
					<select name="bundle[type]">
						<?php foreach ( $bundle_type_labels as $value => $label ) : ?>
							<option value="<?php echo esc_attr( $value ); ?>"><?php echo esc_html( $label ); ?></option>
						<?php endforeach; ?>
					</select>
				</label>
				<label><span><?php esc_html_e( 'Product IDs', 'mobishop' ); ?></span><input type="text" name="bundle[product_ids]" placeholder="12, 45, 98"></label>
				<label><span><?php esc_html_e( 'Category IDs', 'mobishop' ); ?></span><input type="text" name="bundle[category_ids]" placeholder="3, 7"></label>
				<label><span><?php esc_html_e( 'Minimum items', 'mobishop' ); ?></span><input type="number" min="1" name="bundle[minimum_items]" value="2"></label>
				<label><span><?php esc_html_e( 'Maximum items', 'mobishop' ); ?></span><input type="number" min="1" name="bundle[maximum_items]" value="2"></label>
				<label>
					<span><?php esc_html_e( 'Pricing rule', 'mobishop' ); ?></span>
					<select name="bundle[pricing]">
						<option value="percentage"><?php esc_html_e( 'Percentage off', 'mobishop' ); ?></option>
						<option value="fixed_discount"><?php esc_html_e( 'Fixed discount', 'mobishop' ); ?></option>
						<option value="fixed"><?php esc_html_e( 'Fixed bundle price', 'mobishop' ); ?></option>
						<option value="cheapest_free"><?php esc_html_e( 'Cheapest free', 'mobishop' ); ?></option>
						<option value="tiered"><?php esc_html_e( 'Tiered', 'mobishop' ); ?></option>
						<option value="none"><?php esc_html_e( 'No discount', 'mobishop' ); ?></option>
					</select>
				</label>
				<label><span><?php esc_html_e( 'Value', 'mobishop' ); ?></span><input type="number" min="0" step=".01" name="bundle[discount_value]" value="10"></label>
				<label>
					<span><?php esc_html_e( 'Channel', 'mobishop' ); ?></span>
					<select name="bundle[channel]">
						<option value="all"><?php esc_html_e( 'Website + Mobile App', 'mobishop' ); ?></option>
						<option value="website"><?php esc_html_e( 'Website only', 'mobishop' ); ?></option>
						<option value="mobile"><?php esc_html_e( 'Mobile App only', 'mobishop' ); ?></option>
					</select>
				</label>
				<label>
					<span><?php esc_html_e( 'Stock policy', 'mobishop' ); ?></span>
					<select name="bundle[stock_policy]">
						<option value="all_components"><?php esc_html_e( 'Require all components', 'mobishop' ); ?></option>
						<option value="hide_unavailable"><?php esc_html_e( 'Hide unavailable choices', 'mobishop' ); ?></option>
						<option value="allow_backorder"><?php esc_html_e( 'Allow backorders', 'mobishop' ); ?></option>
					</select>
				</label>
				<label><span><?php esc_html_e( 'Starts at', 'mobishop' ); ?></span><input type="datetime-local" name="bundle[starts_at]"></label>
				<label><span><?php esc_html_e( 'Ends at', 'mobishop' ); ?></span><input type="datetime-local" name="bundle[ends_at]"></label>
				<label class="mobishop-ai-check"><input type="checkbox" name="bundle[allow_variants]" value="1" checked><span><?php esc_html_e( 'Customers may choose variants', 'mobishop' ); ?></span></label>
				<label class="mobishop-ai-check"><input type="checkbox" name="bundle[allow_repeats]" value="1"><span><?php esc_html_e( 'Allow repeated products', 'mobishop' ); ?></span></label>
				<label class="mobishop-ai-check"><input type="checkbox" name="bundle[coupon_stacking]" value="1"><span><?php esc_html_e( 'Allow coupon stacking', 'mobishop' ); ?></span></label>
				<label class="mobishop-ai-check"><input type="checkbox" name="bundle[create_product]" value="1"><span><?php esc_html_e( 'Create a WooCommerce product for fixed bundles', 'mobishop' ); ?></span></label>
				<label>
					<span><?php esc_html_e( 'Status', 'mobishop' ); ?></span>
					<select name="bundle[status]">
						<option value="draft"><?php esc_html_e( 'Draft', 'mobishop' ); ?></option>
						<option value="published"><?php esc_html_e( 'Published', 'mobishop' ); ?></option>
					</select>
				</label>
			</div>
			<label class="mobishop-ai-bundle-description"><span><?php esc_html_e( 'Customer-facing description', 'mobishop' ); ?></span><textarea name="bundle[description]" rows="3"></textarea></label>
			<footer><button class="button button-primary" type="submit"><?php esc_html_e( 'Save bundle recipe', 'mobishop' ); ?></button></footer>
		</form>
	</section>

	<section class="mobishop-saved-bundles">
		<header>
			<div>
				<h2><?php esc_html_e( 'Saved bundles', 'mobishop' ); ?></h2>
				<p><?php esc_html_e( 'The list updates after every successful save.', 'mobishop' ); ?></p>
			</div>
		</header>
		<?php if ( $bundle_recipes ) : ?>
			<div>
				<?php foreach ( array_reverse( $bundle_recipes, true ) as $recipe ) : ?>
					<article>
						<div>
							<strong><?php echo esc_html( (string) ( $recipe['name'] ?? __( 'Bundle', 'mobishop' ) ) ); ?></strong>
							<small><?php echo esc_html( $bundle_type_labels[ (string) ( $recipe['type'] ?? '' ) ] ?? ucfirst( (string) ( $recipe['type'] ?? 'fixed' ) ) ); ?></small>
						</div>
						<span class="is-<?php echo esc_attr( (string) ( $recipe['status'] ?? 'draft' ) ); ?>"><?php echo esc_html( ucfirst( (string) ( $recipe['status'] ?? 'draft' ) ) ); ?></span>
						<dl>
							<div><dt><?php esc_html_e( 'Channel', 'mobishop' ); ?></dt><dd><?php echo esc_html( ucfirst( (string) ( $recipe['channel'] ?? 'all' ) ) ); ?></dd></div>
							<div><dt><?php esc_html_e( 'Products', 'mobishop' ); ?></dt><dd><?php echo esc_html( (string) count( (array) ( $recipe['product_ids'] ?? array() ) ) ); ?></dd></div>
							<div><dt><?php esc_html_e( 'Categories', 'mobishop' ); ?></dt><dd><?php echo esc_html( (string) count( (array) ( $recipe['category_ids'] ?? array() ) ) ); ?></dd></div>
							<div><dt><?php esc_html_e( 'Value', 'mobishop' ); ?></dt><dd><?php echo esc_html( (string) ( $recipe['discount_value'] ?? 0 ) ); ?></dd></div>
						</dl>
					</article>
				<?php endforeach; ?>
			</div>
		<?php else : ?>
			<div class="mobishop-ai-empty"><span class="dashicons dashicons-products"></span><div><strong><?php esc_html_e( 'No manual bundles yet', 'mobishop' ); ?></strong><p><?php esc_html_e( 'Create the first recipe with the form above.', 'mobishop' ); ?></p></div></div>
		<?php endif; ?>
	</section>
</div>

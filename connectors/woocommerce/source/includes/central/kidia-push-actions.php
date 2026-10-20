<?php
/** Builder transport for the existing reviewed MobiShop Push workflow. */
defined('ABSPATH') || exit;
final class MobiShop_Central_Push_Actions {
 public static function process(array $submitted, string $request_id, bool $validate_only = false) {
  if (!preg_match('/^[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}$/iD', $request_id)) return new WP_Error('invalid_request','A valid notification request identifier is required.',array('status'=>400));
  $payload = self::normalize($submitted);
  if ($payload instanceof WP_Error) return $payload;
  $payload['id'] = strtolower($request_id);
  if ($validate_only) return array('ok'=>true,'validated'=>true,'payload'=>$payload);
  if (!class_exists('MobiShop_Push_Service')) return new WP_Error('push_unavailable','The push service is unavailable.',array('status'=>503));
  $status = MobiShop_Push_Service::connection_status();
  if (empty($status['license_active']) || empty($status['connected'])) return new WP_Error('push_not_ready','The application connection must be ready before delivery.',array('status'=>409));
  $history = get_option('mobishop_push_history',array());
  $history = is_array($history) ? $history : array();
  foreach ($history as $previous) {
   if (is_array($previous) && ($previous['id'] ?? '') === $payload['id']) return self::result($previous,true);
  }
  global $wpdb;
  $history_lock = 'kidia_push_' . md5(home_url('/'));
  if ('1' !== (string) $wpdb->get_var($wpdb->prepare('SELECT GET_LOCK(%s, 0)', $history_lock))) return new WP_Error('push_busy','Another notification is processing. Try again shortly.',array('status'=>409));
  // Atomic option insertion prevents concurrent requests with the same identifier.
  $lock = 'kidia_builder_push_request_' . $payload['id'];
  if (!add_option($lock,'processing','',false)) {
   $wpdb->get_var($wpdb->prepare('SELECT RELEASE_LOCK(%s)', $history_lock));
   return new WP_Error('request_pending','This request is already processing or needs delivery review.',array('status'=>409));
  }
  try {
   if ('scheduled' === $payload['delivery']) {
    $payload['status'] = 'scheduled';
    $scheduled = wp_schedule_single_event($payload['scheduled_at'],'mobishop_dispatch_scheduled_push',array($payload),true);
    if (is_wp_error($scheduled) || !$scheduled) { delete_option($lock); return new WP_Error('schedule_failed','The notification could not be scheduled.',array('status'=>503)); }
   } elseif ('automation' === $payload['delivery']) {
    $automations = get_option('mobishop_push_automations',array());
    $automations = is_array($automations) ? $automations : array();
    $payload['status'] = 'automation_saved';
    $automations[$payload['automation']['trigger']] = $payload;
    if (!update_option('mobishop_push_automations',$automations,false)) { delete_option($lock); return new WP_Error('automation_failed','The automation could not be saved.',array('status'=>503)); }
   } else {
    $payload = MobiShop_Push_Service::dispatch($payload);
   }
   // Read again after dispatch so completed concurrent campaigns are retained.
   $history = get_option('mobishop_push_history',array());
   $history = is_array($history) ? $history : array();
   array_unshift($history,$payload);
   if (!update_option('mobishop_push_history',array_slice($history,0,100),false)) {
    // Preserve the request lock: delivery may already have happened, so a retry must not resend.
    return new WP_Error('history_failed','Delivery state needs review before retrying this request.',array('status'=>503));
   }
   // Keep the identifier recorded even after it ages out of the last 100 history items.
   update_option($lock,'completed',false);
   return self::result($payload,false);
  } catch (Throwable $error) {
   // An uncertain delivery retains its lock, rather than risking a duplicate send.
   return new WP_Error('delivery_uncertain','Delivery needs review before retrying this request.',array('status'=>503));
  } finally {
   $wpdb->get_var($wpdb->prepare('SELECT RELEASE_LOCK(%s)', $history_lock));
  }
 }
 private static function result(array $payload, bool $replayed): array {
  $status = (string) ($payload['status'] ?? 'failed');
  return array('ok'=>in_array($status,array('sent','scheduled','automation_saved'),true),'request_id'=>$payload['id'],'status'=>$status,'replayed'=>$replayed,'sent'=>absint($payload['delivery']['sent'] ?? 0),'failed'=>absint($payload['delivery']['failed'] ?? 0));
 }
 public static function normalize(array $submitted) {
  foreach ($submitted as $value) {
   if (is_array($value) || is_object($value)) return new WP_Error('invalid_field','Notification fields must be scalar values.',array('status'=>400));
  }
  foreach (array('push_audience'=>array('all','customers','guests','segment','test'),'push_delivery'=>array('now','scheduled','automation')) as $key=>$allowed) {
   if (isset($submitted[$key]) && !in_array($submitted[$key],$allowed,true)) return new WP_Error('invalid_choice','Choose a valid notification audience and delivery mode.',array('status'=>400));
  }
  if (($submitted['push_delivery'] ?? 'now') === 'automation' && !in_array($submitted['push_trigger'] ?? '',array('abandoned_cart','browse_abandonment','checkout_abandonment','welcome','restock','price_drop','winback','new_product','coupon_expiry'),true)) return new WP_Error('invalid_trigger','Choose a valid automation trigger.',array('status'=>400));
  $input = wp_slash($submitted);
		$title   = sanitize_text_field( (string) wp_unslash( $input['push_title'] ?? '' ) );
		$message = sanitize_textarea_field( (string) wp_unslash( $input['push_message'] ?? '' ) );
		if ( '' === $title || '' === $message ) return new WP_Error('missing_message','Title and message are required.',array('status'=>400));
		$type = sanitize_key( wp_unslash( $input['push_type'] ?? 'broadcast' ) );
		$type = in_array( $type, array( 'broadcast', 'offer', 'ai_offer', 'order', 'restock', 'abandoned_cart', 'welcome', 'custom' ), true ) ? $type : 'broadcast';
		$delivery = sanitize_key( wp_unslash( $input['push_delivery'] ?? 'now' ) );
		$delivery = in_array( $delivery, array( 'now', 'scheduled', 'automation' ), true ) ? $delivery : 'now';
		$audience = sanitize_key( wp_unslash( $input['push_audience'] ?? 'all' ) );
		$audience = in_array( $audience, array( 'all', 'customers', 'guests', 'segment', 'test' ), true ) ? $audience : 'all';
		$payload = array(
			'id'         => wp_generate_uuid4(),
			'type'       => $type,
			'title'      => mb_substr( $title, 0, 100 ),
			'message'    => mb_substr( $message, 0, 500 ),
			'audience'   => $audience,
			'action_url' => esc_url_raw( wp_unslash( $input['push_action_url'] ?? '' ) ),
			'image_url'  => esc_url_raw( wp_unslash( $input['push_image_url'] ?? '' ) ),
			'cta_label'  => sanitize_text_field( wp_unslash( $input['push_cta_label'] ?? '' ) ),
			'coupon'     => sanitize_text_field( wp_unslash( $input['push_coupon'] ?? '' ) ),
			'product_id' => absint( $input['push_product_id'] ?? 0 ),
			'order_status' => sanitize_key( wp_unslash( $input['push_order_status'] ?? '' ) ),
			'priority'   => 'high' === sanitize_key( wp_unslash( $input['push_priority'] ?? '' ) ) ? 'high' : 'normal',
			'sound'      => ! empty( $input['push_sound'] ),
			'badge'      => absint( $input['push_badge'] ?? 0 ),
			'expiry_hours' => max( 1, min( 168, absint( $input['push_expiry_hours'] ?? 24 ) ) ),
			'destination' => in_array( sanitize_key( wp_unslash( $input['push_destination'] ?? 'home' ) ), array( 'home', 'product', 'category', 'subcategory', 'collection', 'cart', 'checkout', 'wishlist', 'order', 'account', 'offers', 'search', 'custom', 'external' ), true )
				? sanitize_key( wp_unslash( $input['push_destination'] ?? 'home' ) )
				: 'home',
			'destination_id' => sanitize_text_field( wp_unslash( $input['push_destination_id'] ?? '' ) ),
			'action_style' => 'button' === sanitize_key( wp_unslash( $input['push_action_style'] ?? 'link' ) ) ? 'button' : 'link',
			'segment'    => array(
				'min_orders' => absint( $input['push_min_orders'] ?? 0 ),
				'min_spent' => (float) ( $input['push_min_spent'] ?? 0 ),
				'inactive_days' => absint( $input['push_inactive_days'] ?? 0 ),
			),
			'delivery'   => $delivery,
			'automation' => array(
				'enabled'       => 'automation' === $delivery,
				'trigger'       => sanitize_key( wp_unslash( $input['push_trigger'] ?? $type ) ),
				'delay_minutes' => min( 43200, absint( $input['push_delay_minutes'] ?? 30 ) ),
				'max_sends'     => min( 20, max( 1, absint( $input['push_max_sends'] ?? 3 ) ) ),
				'cooldown_hours'=> min( 8760, max( 1, absint( $input['push_cooldown_hours'] ?? 24 ) ) ),
				'allowed_from'  => sanitize_text_field( wp_unslash( $input['push_allowed_from'] ?? '09:00' ) ),
				'allowed_to'    => sanitize_text_field( wp_unslash( $input['push_allowed_to'] ?? '21:00' ) ),
				'stop_on_purchase' => ! empty( $input['push_stop_on_purchase'] ),
			),
			'created_at' => time(),
			'status'     => 'saved',
		);

  $payload['segment']['min_spent'] = max(0.0, $payload['segment']['min_spent']);
  foreach (array('allowed_from','allowed_to') as $key) {
   if (!preg_match('/^(?:[01]\d|2[0-3]):[0-5]\d$/D', $payload['automation'][$key])) {
    return new WP_Error('invalid_window','Allowed delivery times must be valid hours and minutes.',array('status'=>400));
   }
  }
  if ('scheduled' === $delivery) {
   $raw = sanitize_text_field(wp_unslash($input['push_schedule_at'] ?? ''));
   $date = DateTimeImmutable::createFromFormat('!Y-m-d\TH:i', $raw, wp_timezone());
   $errors = DateTimeImmutable::getLastErrors();
   if (!$date || ($errors && ($errors['warning_count'] || $errors['error_count'])) || $date->getTimestamp() <= time()) {
    return new WP_Error('invalid_schedule','Choose a valid future send date and time.',array('status'=>400));
   }
   $payload['scheduled_at'] = $date->getTimestamp();
  }
  return $payload;
 }
}

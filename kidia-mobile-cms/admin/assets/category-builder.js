(function ($) {
	'use strict';

	function updateOrders(list) {
		$(list).children('.kidia-category-row').each(function (index) {
			$(this).children('.kidia-category-card').find('.kidia-category-order').val(index);
		});
	}

	$('.kidia-category-list').each(function () {
		$(this).sortable({
			items: '> .kidia-category-row',
			handle: '.kidia-category-handle',
			axis: 'y',
			containment: 'parent',
			update: function () { updateOrders(this); }
		});
	});

	$('.kidia-category-image-button').on('click', function () {
		const card = $(this).closest('.kidia-category-card');
		const frame = wp.media({ title: 'Choose category image', button: { text: 'Use image' }, multiple: false });
		frame.on('select', function () {
			const image = frame.state().get('selection').first().toJSON();
			card.find('.kidia-category-image-id').val(image.id);
			card.find('.kidia-category-image').html($('<img>', { src: image.sizes?.thumbnail?.url || image.url, alt: '' }));
			card.find('.kidia-category-image-clear').prop('hidden', false);
		});
		frame.open();
	});

	$('.kidia-category-image-clear').on('click', function () {
		$(this).closest('.kidia-category-card').find('.kidia-category-image-id').val('0');
		$(this).prop('hidden', true);
	});
})(jQuery);

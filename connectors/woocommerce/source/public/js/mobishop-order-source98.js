(function () {
	var source = document.getElementById('mobishop-order-source98');
	var channels = document.getElementById('filter-by-created-via');
	if (!source || !channels) return;
	var option = document.createElement('option');
	option.value = 'mobishop-mobile';
	option.textContent = source.options[1].textContent;
	channels.appendChild(option);
	if (source.value === 'mobile') channels.value = option.value;
	source.remove();
}());

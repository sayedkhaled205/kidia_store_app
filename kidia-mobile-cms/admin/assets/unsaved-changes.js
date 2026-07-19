(function () {
	"use strict";

	var form = document.querySelector("#kidia-home-builder-form, .kidia-category-editor form, form.kidia-page-editor");
	if (!form) {
		return;
	}

	var config = window.kidiaUnsavedChanges || {};
	var labels = config.labels || {};
	var dirty = false;
	var submitting = false;
	var pending = null;
	var modal = document.createElement("div");

	modal.className = "kidia-unsaved-modal";
	modal.hidden = true;
	modal.setAttribute("aria-hidden", "true");
	modal.innerHTML =
		'<div class="kidia-unsaved-modal__backdrop" data-kidia-unsaved-cancel></div>' +
		'<section class="kidia-unsaved-modal__dialog" role="dialog" aria-modal="true" aria-labelledby="kidia-unsaved-title" aria-describedby="kidia-unsaved-copy">' +
			'<span class="dashicons dashicons-warning kidia-unsaved-modal__icon" aria-hidden="true"></span>' +
			'<h2 id="kidia-unsaved-title"></h2>' +
			'<p id="kidia-unsaved-copy"></p>' +
			'<div class="kidia-unsaved-modal__actions">' +
				'<button type="button" class="button button-primary" data-kidia-unsaved-save></button>' +
				'<button type="button" class="button kidia-unsaved-modal__discard" data-kidia-unsaved-discard></button>' +
				'<button type="button" class="button" data-kidia-unsaved-cancel></button>' +
			'</div>' +
		'</section>';
	document.body.appendChild(modal);

	modal.querySelector("#kidia-unsaved-title").textContent = labels.title || "Unsaved changes";
	modal.querySelector("#kidia-unsaved-copy").textContent = labels.message || "You have changes that have not been saved. What would you like to do?";
	modal.querySelector("[data-kidia-unsaved-save]").textContent = labels.save || "Save Changes";
	modal.querySelector("[data-kidia-unsaved-discard]").textContent = labels.discard || "Discard Changes";
	modal.querySelector(".kidia-unsaved-modal__actions [data-kidia-unsaved-cancel]").textContent = labels.cancel || "Cancel";

	function setDirty() {
		if (!submitting) {
			dirty = true;
			form.dataset.kidiaDirty = "true";
		}
	}

	function closeModal() {
		modal.hidden = true;
		modal.setAttribute("aria-hidden", "true");
		document.body.classList.remove("kidia-unsaved-modal-open");
		pending = null;
	}

	function openModal(destination) {
		pending = destination;
		modal.hidden = false;
		modal.setAttribute("aria-hidden", "false");
		document.body.classList.add("kidia-unsaved-modal-open");
		window.setTimeout(function () {
			modal.querySelector("[data-kidia-unsaved-save]").focus();
		}, 20);
	}

	function destinationUrl() {
		return pending && pending.url ? String(pending.url) : window.location.href;
	}

	function navigate(destination) {
		if (destination && destination.reload) {
			window.location.reload();
			return;
		}
		window.location.assign(destination && destination.url ? String(destination.url) : window.location.href);
	}

	function saveAndContinue() {
		var target = pending;
		var redirect = form.querySelector('input[name="kidia_redirect_to"]');
		var submitButton = form.querySelector('button[type="submit"], input[type="submit"]');
		if (typeof form.reportValidity === "function" && !form.reportValidity()) {
			closeModal();
			return;
		}
		if (!redirect) {
			redirect = document.createElement("input");
			redirect.type = "hidden";
			redirect.name = "kidia_redirect_to";
			form.appendChild(redirect);
		}
		redirect.value = target && target.reload ? window.location.href : destinationUrl();
		closeModal();
		if (typeof form.requestSubmit === "function") {
			form.requestSubmit(submitButton || undefined);
		} else if (submitButton) {
			submitButton.click();
		} else {
			form.submit();
		}
	}

	form.addEventListener("input", setDirty);
	form.addEventListener("change", setDirty);
	form.addEventListener("kidia:dirty", setDirty);
	form.addEventListener("submit", function () {
		submitting = true;
		dirty = false;
		form.dataset.kidiaDirty = "false";
	});
	form.addEventListener("reset", function () {
		dirty = false;
		form.dataset.kidiaDirty = "false";
	});

	document.addEventListener("click", function (event) {
		var anchor = event.target.closest && event.target.closest("a[href]");
		var url;
		if (!dirty || submitting || !anchor || anchor.target === "_blank" || anchor.hasAttribute("download")) {
			return;
		}
		url = anchor.getAttribute("href") || "";
		if (!url || url.charAt(0) === "#" || /^javascript:/i.test(url)) {
			return;
		}
		event.preventDefault();
		openModal({ url: anchor.href, reload: anchor.href === window.location.href });
	}, true);

	document.addEventListener("keydown", function (event) {
		var refresh = event.key === "F5" || ((event.ctrlKey || event.metaKey) && String(event.key).toLowerCase() === "r");
		if (refresh && dirty && !submitting) {
			event.preventDefault();
			openModal({ url: window.location.href, reload: true });
			return;
		}
		if (event.key === "Escape" && !modal.hidden) {
			event.preventDefault();
			closeModal();
		}
	}, true);

	modal.addEventListener("click", function (event) {
		if (event.target.closest("[data-kidia-unsaved-save]")) {
			saveAndContinue();
			return;
		}
		if (event.target.closest("[data-kidia-unsaved-discard]")) {
			var target = pending;
			dirty = false;
			submitting = true;
			navigate(target);
			return;
		}
		if (event.target.closest("[data-kidia-unsaved-cancel]")) {
			closeModal();
		}
	});

	window.addEventListener("beforeunload", function (event) {
		if (!dirty || submitting) {
			return;
		}
		event.preventDefault();
		event.returnValue = "";
	});
}());

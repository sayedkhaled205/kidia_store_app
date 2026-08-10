(function () {
	"use strict";

	var form = document.querySelector("#mobishop-home-builder-form, .mobishop-category-editor form, form.mobishop-page-editor");
	if (!form) {
		return;
	}

	var config = window.mobishopUnsavedChanges || {};
	var labels = config.labels || {};
	var dirty = false;
	var submitting = false;
	var pending = null;
	var draftKey = "mobishop-unsaved-draft:" + window.location.pathname + window.location.search;
	var modal = document.createElement("div");

	modal.className = "mobishop-unsaved-modal";
	modal.hidden = true;
	modal.setAttribute("aria-hidden", "true");
	modal.innerHTML =
		'<div class="mobishop-unsaved-modal__backdrop" data-mobishop-unsaved-cancel></div>' +
		'<section class="mobishop-unsaved-modal__dialog" role="dialog" aria-modal="true" aria-labelledby="mobishop-unsaved-title" aria-describedby="mobishop-unsaved-copy">' +
			'<span class="dashicons dashicons-warning mobishop-unsaved-modal__icon" aria-hidden="true"></span>' +
			'<h2 id="mobishop-unsaved-title"></h2>' +
			'<p id="mobishop-unsaved-copy"></p>' +
			'<div class="mobishop-unsaved-modal__actions">' +
				'<button type="button" class="button button-primary" data-mobishop-unsaved-save></button>' +
				'<button type="button" class="button mobishop-unsaved-modal__discard" data-mobishop-unsaved-discard></button>' +
				'<button type="button" class="button" data-mobishop-unsaved-cancel></button>' +
			'</div>' +
		'</section>';
	document.body.appendChild(modal);

	modal.querySelector("#mobishop-unsaved-title").textContent = labels.title || "Unsaved changes";
	modal.querySelector("#mobishop-unsaved-copy").textContent = labels.message || "You have changes that have not been saved. What would you like to do?";
	modal.querySelector("[data-mobishop-unsaved-save]").textContent = labels.save || "Save Changes";
	modal.querySelector("[data-mobishop-unsaved-discard]").textContent = labels.discard || "Discard Changes";
	modal.querySelector(".mobishop-unsaved-modal__actions [data-mobishop-unsaved-cancel]").textContent = labels.cancel || "Cancel";

	function setDirty() {
		if (!submitting) {
			dirty = true;
			form.dataset.mobishopDirty = "true";
			storeDraft();
		}
	}

	function storeDraft() {
		var fields = [];
		Array.prototype.forEach.call(form.elements, function (field) {
			if (!field.name || field.type === "file" || field.type === "submit") return;
			fields.push({
				name: field.name,
				value: field.value,
				checked: !!field.checked,
				type: field.type || "text"
			});
		});
		try { window.sessionStorage.setItem(draftKey, JSON.stringify(fields)); } catch (error) {}
	}

	function clearDraft() {
		try { window.sessionStorage.removeItem(draftKey); } catch (error) {}
	}

	function restoreDraft(fields) {
		(fields || []).forEach(function (saved) {
			var matches = Array.prototype.filter.call(form.elements, function (field) {
				return field.name === saved.name;
			});
			Array.prototype.forEach.call(matches, function (field) {
				if (field.type === "checkbox" || field.type === "radio") {
					field.checked = saved.checked && field.value === saved.value;
				} else {
					field.value = saved.value;
				}
			});
		});
	}

	function closeModal() {
		modal.hidden = true;
		modal.setAttribute("aria-hidden", "true");
		document.body.classList.remove("mobishop-unsaved-modal-open");
		pending = null;
	}

	function openModal(destination) {
		pending = destination;
		modal.hidden = false;
		modal.setAttribute("aria-hidden", "false");
		document.body.classList.add("mobishop-unsaved-modal-open");
		window.setTimeout(function () {
			modal.querySelector("[data-mobishop-unsaved-save]").focus();
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
		var redirect = form.querySelector('input[name="mobishop_redirect_to"]');
		var submitButton = form.querySelector('button[type="submit"], input[type="submit"]');
		if (target && target.fields) restoreDraft(target.fields);
		if (typeof form.reportValidity === "function" && !form.reportValidity()) {
			closeModal();
			return;
		}
		if (!redirect) {
			redirect = document.createElement("input");
			redirect.type = "hidden";
			redirect.name = "mobishop_redirect_to";
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
	form.addEventListener("mobishop:dirty", setDirty);
	form.addEventListener("submit", function () {
		submitting = true;
		dirty = false;
		clearDraft();
		form.dataset.mobishopDirty = "false";
	});
	form.addEventListener("reset", function () {
		dirty = false;
		clearDraft();
		form.dataset.mobishopDirty = "false";
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
		if (event.target.closest("[data-mobishop-unsaved-save]")) {
			saveAndContinue();
			return;
		}
		if (event.target.closest("[data-mobishop-unsaved-discard]")) {
			var target = pending;
			dirty = false;
			submitting = true;
			clearDraft();
			if (target && target.fields) {
				closeModal();
				return;
			}
			navigate(target);
			return;
		}
		if (event.target.closest("[data-mobishop-unsaved-cancel]")) {
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

	window.setTimeout(function () {
		var raw;
		var fields;
		try { raw = window.sessionStorage.getItem(draftKey); } catch (error) { raw = null; }
		if (!raw) return;
		try { fields = JSON.parse(raw); } catch (error) { clearDraft(); return; }
		if (!Array.isArray(fields) || !fields.length) { clearDraft(); return; }
		dirty = true;
		form.dataset.mobishopDirty = "true";
		openModal({ url: window.location.href, reload: false, fields: fields });
	}, 0);
}());

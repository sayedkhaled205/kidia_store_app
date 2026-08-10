(function () {
	"use strict";
	document.addEventListener("DOMContentLoaded", function () {
		const form = document.querySelector(".mobishop-checkout-fields-form");
		const list = document.querySelector("[data-checkout-fields-list]");
		const template = document.querySelector("[data-checkout-field-template]");
		const add = document.querySelector("[data-checkout-add-field]");
		if (!form || !list || !template || !add) return;

		let sequence = list.querySelectorAll("[data-checkout-field]").length;
		let dragging = null;

		function reindex() {
			list.querySelectorAll("[data-checkout-field]").forEach(function (card, index) {
				card.querySelectorAll("[name]").forEach(function (field) {
					field.name = field.name.replace(/checkout\[fields]\[[^\]]+]/, "checkout[fields][" + index + "]");
				});
			});
		}

		function syncCard(card) {
			const label = card.querySelector("[data-checkout-label]");
			const title = card.querySelector("[data-checkout-field-title]");
			if (label && title) title.textContent = label.value.trim() || "Checkout field";
			const type = card.querySelector("[data-checkout-type]");
			const options = card.querySelector(".mobishop-checkout-options-field");
			if (type && options) options.hidden = type.value !== "select";
		}

		function bind(card) {
			syncCard(card);
			card.addEventListener("input", function () { syncCard(card); });
			card.addEventListener("change", function () { syncCard(card); });
			card.querySelector(".mobishop-page-expand")?.addEventListener("click", function (event) {
				event.preventDefault();
				const body = card.querySelector(".mobishop-page-card__body");
				const opening = body ? body.hidden : false;
				if (body) body.hidden = !opening;
				card.classList.toggle("is-open", opening);
				event.currentTarget.setAttribute("aria-expanded", opening ? "true" : "false");
			});
			card.querySelector(".mobishop-checkout-field-remove")?.addEventListener("click", function (event) {
				event.preventDefault();
				card.remove();
				reindex();
				form.dispatchEvent(new Event("change", { bubbles: true }));
			});
			card.addEventListener("dragstart", function (event) {
				if (event.target.closest("input,select,textarea,button,label")) {
					event.preventDefault();
					return;
				}
				dragging = card;
				card.classList.add("is-dragging");
				if (event.dataTransfer) event.dataTransfer.effectAllowed = "move";
			});
			card.addEventListener("dragend", function () {
				card.classList.remove("is-dragging");
				dragging = null;
				reindex();
				form.dispatchEvent(new Event("change", { bubbles: true }));
			});
		}

		list.addEventListener("dragover", function (event) {
			if (!dragging) return;
			event.preventDefault();
			const candidates = Array.from(list.querySelectorAll("[data-checkout-field]:not(.is-dragging)"));
			const next = candidates.find(function (card) {
				return event.clientY < card.getBoundingClientRect().top + card.offsetHeight / 2;
			});
			list.insertBefore(dragging, next || null);
		});

		add.addEventListener("click", function () {
			const html = template.innerHTML.replaceAll("__INDEX__", "new_" + sequence++);
			const holder = document.createElement("div");
			holder.innerHTML = html.trim();
			const card = holder.firstElementChild;
			if (!card) return;
			list.appendChild(card);
			bind(card);
			reindex();
			card.querySelector(".mobishop-page-expand")?.click();
			card.querySelector("[data-checkout-label]")?.focus();
		});

		list.querySelectorAll("[data-checkout-field]").forEach(bind);
		reindex();
	});
}());

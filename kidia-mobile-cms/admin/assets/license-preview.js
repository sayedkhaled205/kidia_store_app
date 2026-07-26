(function () {
	"use strict";

	function bootLicensePreview() {
		if (!document.body.classList.contains("kidia-cms-license-preview")) {
			return;
		}

		var config = window.kidiaLicensePreview || {};
		var shell = document.querySelector("[data-kidia-cms-shell]");
		var notice = document.createElement("div");
		notice.className = "kidia-license-preview-notice";
		notice.setAttribute("role", "status");
		notice.innerHTML =
			"<div><strong></strong><span></span></div><a class=\"button button-primary\"></a>";
		notice.querySelector("strong").textContent = config.title || "Preview mode";
		notice.querySelector("span").textContent =
			config.message || "Activate your website license to edit settings.";
		notice.querySelector("a").textContent = config.actionLabel || "Activate license";
		notice.querySelector("a").href = config.actionUrl || "#";

		if (shell && shell.parentNode) {
			shell.insertAdjacentElement("afterend", notice);
		}

		function lockPreview(root) {
			var scope = root && root.querySelectorAll ? root : document;

			scope.querySelectorAll(".wrap input, .wrap select, .wrap textarea, .wrap button").forEach(function (control) {
				control.disabled = true;
				control.setAttribute("aria-disabled", "true");
			});

			scope.querySelectorAll(".wrap .button").forEach(function (button) {
				button.setAttribute("aria-disabled", "true");
				button.setAttribute("tabindex", "-1");
			});

			scope.querySelectorAll(".wrap [draggable=\"true\"], .wrap .ui-sortable-handle").forEach(function (item) {
				item.setAttribute("draggable", "false");
				item.setAttribute("aria-disabled", "true");
			});
		}

		function blockMutation(event) {
			if (!event.target.closest(".wrap")) {
				return;
			}

			event.preventDefault();
			event.stopImmediatePropagation();
		}

		lockPreview(document);
		document.addEventListener("submit", blockMutation, true);
		document.addEventListener("click", function (event) {
			if (event.target.closest(".wrap .button, .wrap [draggable=\"true\"], .wrap .ui-sortable-handle")) {
				blockMutation(event);
			}
		}, true);

		new MutationObserver(function (mutations) {
			mutations.forEach(function (mutation) {
				mutation.addedNodes.forEach(function (node) {
					if (node.nodeType === 1) {
						lockPreview(node.parentElement || node);
					}
				});
			});
		}).observe(document.body, { childList: true, subtree: true });
	}

	if (document.readyState === "loading") {
		document.addEventListener("DOMContentLoaded", bootLicensePreview);
	} else {
		bootLicensePreview();
	}
}());

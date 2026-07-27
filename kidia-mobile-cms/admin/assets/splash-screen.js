(function () {
	"use strict";

	document.addEventListener("DOMContentLoaded", function () {
		var form = document.querySelector(".kidia-splash-builder form");
		var preview = document.getElementById("kidia-splash-preview");
		var overlay = preview ? preview.querySelector("[data-splash-overlay]") : null;
		var replay = document.querySelector("[data-splash-replay]");
		var finishTimer;

		if (!form || !preview || !overlay) {
			return;
		}

		function field(name) {
			return form.querySelector('[name="splash[' + name + ']"]:not([type="hidden"])');
		}

		function draw() {
			var enabled = field("enabled").checked;
			var img = overlay.querySelector("img");
			var title = overlay.querySelector("strong");
			var loader = overlay.querySelector(".spinner");
			var progress = overlay.querySelector(".kidia-splash-progress");
			var duration = Math.max(500, Math.min(10000, parseInt(field("duration_ms").value, 10) || 1800));

			preview.classList.toggle("is-splash-disabled", !enabled);
			preview.style.setProperty("--kidia-splash-duration", duration + "ms");
			overlay.style.background = "linear-gradient(" + field("background_color").value + "," + field("background_color_end").value + ")";
			img.src = field("image_url").value;
			img.hidden = !img.src;
			img.style.width = field("image_width").value + "px";
			img.style.height = field("image_height").value + "px";
			img.style.objectFit = field("image_fit").value;
			img.style.borderRadius = field("image_shape").value === "circle" ? "50%" : field("image_shape").value === "rounded" ? "18px" : "0";
			title.textContent = field("store_name").value;
			title.hidden = !field("show_store_name").checked;
			title.style.color = field("text_color").value;
			loader.hidden = !field("show_loader").checked;
			loader.style.color = field("loader_color").value;
			if (progress) {
				progress.style.color = field("loader_color").value;
			}
		}

		function play() {
			var duration = Math.max(500, Math.min(10000, parseInt(field("duration_ms").value, 10) || 1800));
			window.clearTimeout(finishTimer);
			draw();
			preview.classList.remove("is-playing", "is-finished");
			void preview.offsetWidth;
			if (!field("enabled").checked) {
				preview.classList.add("is-finished");
				return;
			}
			preview.classList.add("is-playing");
			finishTimer = window.setTimeout(function () {
				preview.classList.add("is-finished");
				preview.classList.remove("is-playing");
			}, duration);
		}

		form.addEventListener("input", draw);
		form.addEventListener("change", play);

		var mediaButton = form.querySelector(".kidia-page-media-choose");
		if (mediaButton) {
			mediaButton.addEventListener("click", function () {
				var frame = wp.media({ title: "Choose splash image", multiple: false, library: { type: "image" } });
				frame.on("select", function () {
					field("image_url").value = frame.state().get("selection").first().toJSON().url;
					play();
				});
				frame.open();
			});
		}

		var expandButton = form.querySelector(".kidia-page-expand");
		if (expandButton) {
			expandButton.addEventListener("click", function () {
				var body = form.querySelector(".kidia-page-card__body");
				var open = !body.hidden;
				body.hidden = open;
				this.setAttribute("aria-expanded", String(!open));
				form.querySelector(".kidia-page-card").classList.toggle("is-open", !open);
			});
		}

		if (replay) {
			replay.addEventListener("click", play);
		}

		play();
	});
}());

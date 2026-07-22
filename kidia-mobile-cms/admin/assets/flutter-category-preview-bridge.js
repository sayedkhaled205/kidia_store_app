(function () {
	"use strict";
	var root = document.querySelector(".kidia-category-builder");
	var frame = document.getElementById("kidia-flutter-preview");
	var form = root && root.querySelector("form");
	if (!root || !frame || !form) { return; }
	var fallback = frame.parentElement && frame.parentElement.querySelector(".kidia-legacy-preview-fallback");
	var timer = 0;
	var frameOrigin = window.location.origin;
	try { frameOrigin = new URL(frame.src, window.location.href).origin; } catch (_) {}
	function parts(name) { return String(name || "").replace(/\]/g, "").split("[").filter(Boolean); }
	function assign(target, path, value) { var cursor=target;path.forEach(function(key,index){if(index===path.length-1){cursor[key]=value;return;}if(!cursor[key]||typeof cursor[key]!=="object"){cursor[key]={};}cursor=cursor[key];}); }
	function scalar(input) { if(input.type==="checkbox"){return input.checked;}if(input.type==="number"||input.type==="range"){var number=Number(input.value);return Number.isFinite(number)?number:0;}return input.value; }
	function state() {
		var data={layout:{}};
		Array.prototype.forEach.call(form.querySelectorAll("[name]"),function(input){
			if(String(input.name||"").indexOf("layout[")!==0&&String(input.name||"").indexOf("category_general[")!==0){return;}
			if(input.type==="hidden"&&input.nextElementSibling&&input.nextElementSibling.name===input.name&&input.nextElementSibling.type==="checkbox"){return;}
			if((input.type==="checkbox"||input.type==="radio")&&!input.checked){return;}
			assign(data,parts(input.name),scalar(input));
		});
		return data;
	}
	function send(){if(!frame.contentWindow){return;}var data=state(),layout=data.layout||{};layout.page="category";layout.elements=[];frame.contentWindow.postMessage(JSON.stringify({type:"kidia-preview-layout",page:"category",layout:layout,category:data.category_general||{}}),frameOrigin);}
	function waitForFlutter(){frame.hidden=true;frame.setAttribute("aria-busy","true");if(fallback){fallback.hidden=false;}}
	function showFlutter(){send();window.requestAnimationFrame(function(){window.requestAnimationFrame(function(){frame.hidden=false;frame.removeAttribute("aria-busy");if(fallback){fallback.hidden=true;}});});}
	function schedule(){window.clearTimeout(timer);timer=window.setTimeout(send,60);}
	frame.addEventListener("load",send);form.addEventListener("input",schedule);form.addEventListener("change",schedule);
	window.addEventListener("message",function(event){if(event.source!==frame.contentWindow||event.origin!==frameOrigin){return;}var message=event.data;if(typeof message==="string"){try{message=JSON.parse(message);}catch(_){return;}}if(message&&message.type==="kidia-flutter-preview-ready"){showFlutter();}});
	// Cached Flutter can become ready before this footer bridge is evaluated.
	waitForFlutter();
	send();
	[250,750,1500,3000,6000].forEach(function(delay){window.setTimeout(send,delay);});
}());

(function () {
	"use strict";
	var root = document.querySelector(".kidia-category-builder");
	var frame = document.getElementById("kidia-flutter-preview");
	var form = root && root.querySelector("form");
	if (!root || !frame || !form) { return; }
	var timer = 0;
	function parts(name) { return String(name || "").replace(/\]/g, "").split("[").filter(Boolean); }
	function assign(target, path, value) { var cursor=target;path.forEach(function(key,index){if(index===path.length-1){cursor[key]=value;return;}if(!cursor[key]||typeof cursor[key]!=="object"){cursor[key]={};}cursor=cursor[key];}); }
	function scalar(input) { if(input.type==="checkbox"){return input.checked;}if(input.type==="number"||input.type==="range"){var number=Number(input.value);return Number.isFinite(number)?number:0;}return input.value; }
	function state() {
		var data={layout:{}};
		Array.prototype.forEach.call(form.querySelectorAll('[name^="layout["],[name^="category_general["]'),function(input){
			if(input.type==="hidden"&&input.nextElementSibling&&input.nextElementSibling.name===input.name&&input.nextElementSibling.type==="checkbox"){return;}
			if((input.type==="checkbox"||input.type==="radio")&&!input.checked){return;}
			assign(data,parts(input.name),scalar(input));
		});
		return data;
	}
	function send(){if(!frame.contentWindow){return;}var data=state(),layout=data.layout||{};layout.page="category";layout.elements=[];frame.contentWindow.postMessage(JSON.stringify({type:"kidia-preview-layout",page:"category",layout:layout,category:data.category_general||{}}),window.location.origin);}
	function schedule(){window.clearTimeout(timer);timer=window.setTimeout(send,60);}
	frame.addEventListener("load",send);form.addEventListener("input",schedule);form.addEventListener("change",schedule);
	window.addEventListener("message",function(event){if(event.origin!==window.location.origin){return;}var message=event.data;if(typeof message==="string"){try{message=JSON.parse(message);}catch(_){return;}}if(message&&message.type==="kidia-flutter-preview-ready"){send();}});
}());

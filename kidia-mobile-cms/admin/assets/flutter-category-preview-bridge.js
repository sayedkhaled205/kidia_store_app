(function () {
	"use strict";
	var root = document.querySelector(".kidia-category-builder");
	var frame = document.getElementById("kidia-flutter-preview");
	var form = root && root.querySelector("form");
	if (!root || !frame || !form) { return; }
	var config=window.kidiaFlutterPreview||{},ready=false,controller=null,requestNumber=0;
	var fallback = frame.parentElement && frame.parentElement.querySelector(".kidia-legacy-preview-fallback");
	var frameOrigin = window.location.origin;
	try { frameOrigin = new URL(frame.src, window.location.href).origin; } catch (_) {}
	function waitForFlutter(){frame.hidden=true;frame.setAttribute("aria-busy","true");if(fallback){fallback.hidden=false;}}
	function showFlutter(){window.requestAnimationFrame(function(){window.requestAnimationFrame(function(){frame.hidden=false;frame.removeAttribute("aria-busy");if(fallback){fallback.hidden=true;}});});}
	function setPath(target,name,value){var keys=String(name).replace(/\]/g,"").split("[");var cursor=target;keys.forEach(function(key,index){var last=index===keys.length-1;var next=!last&&/^\d+$/.test(keys[index+1]);if(last){cursor[key]=value;return;}if(!cursor[key]||typeof cursor[key]!=="object"){cursor[key]=next?[]:{};}cursor=cursor[key];});}
	function serialize(){var result={};Array.prototype.forEach.call(form.elements,function(field){if(!field.name||field.disabled){return;}if((field.type==="checkbox"||field.type==="radio")&&!field.checked){return;}if(field.name.indexOf("layout[")!==0&&field.name.indexOf("category_general[")!==0){return;}setPath(result,field.name,field.value);});return result;}
	function post(url,body,signal){return window.fetch(String(url),{method:"POST",credentials:"same-origin",cache:"no-store",signal:signal,headers:{"Content-Type":"application/json","X-WP-Nonce":String(config.restNonce)},body:JSON.stringify(body)}).then(function(response){if(!response.ok){throw new Error("Preview request failed with HTTP "+response.status+".");}return response.json();});}
	function refresh(){var values,number,signal;if(!ready||!config.layoutPreviewEndpoint||!config.categoryPreviewEndpoint||!config.restNonce||typeof window.fetch!=="function"){return;}values=serialize();if(controller){controller.abort();}controller=typeof window.AbortController==="function"?new window.AbortController():null;signal=controller?controller.signal:undefined;number=++requestNumber;Promise.all([post(config.layoutPreviewEndpoint,{layout:values.layout||{}},signal),post(config.categoryPreviewEndpoint,{general:values.category_general||{}},signal)]).then(function(payloads){if(number===requestNumber&&frame.contentWindow){frame.contentWindow.postMessage(JSON.stringify({type:"kidia-preview-layout",page:"category",layout:payloads[0],category:payloads[1]}),frameOrigin);}}).catch(function(error){if(error&&error.name==="AbortError"){return;}if(window.console&&window.console.warn){window.console.warn(error);}});}
	window.addEventListener("message",function(event){if(event.source!==frame.contentWindow||event.origin!==frameOrigin){return;}var message=event.data;if(typeof message==="string"){try{message=JSON.parse(message);}catch(_){return;}}if(message&&message.type==="kidia-flutter-preview-ready"){ready=true;showFlutter();refresh();}});
	form.addEventListener("input",refresh);form.addEventListener("change",refresh);document.addEventListener("kidia:category-layout-changed",refresh);
	// Cached Flutter can become ready before this footer bridge is evaluated.
	waitForFlutter();
}());

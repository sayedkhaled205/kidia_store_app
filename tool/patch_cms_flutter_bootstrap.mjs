import fs from "node:fs";

const bootstrapPath = process.argv[2];
if (!bootstrapPath) {
  throw new Error("Pass the generated flutter_bootstrap.js path.");
}

let source = fs.readFileSync(bootstrapPath, "utf8");
const cacheSuffix =
  '(window.__kidiaPreviewVersion?"?v="+encodeURIComponent(window.__kidiaPreviewVersion):"")';

for (const asset of ["canvaskit.js", "canvaskit.wasm"]) {
  const original = `c(s,"${asset}")`;
  const replacement = `c(s,"${asset}"+${cacheSuffix})`;
  if (!source.includes(original)) {
    throw new Error(`Could not find ${asset} in generated Flutter bootstrap.`);
  }
  source = source.replaceAll(original, replacement);
}

const loaderCall =
  '_flutter.loader.load({config:{canvasKitBaseUrl:"canvaskit/"}});';
if (!source.includes(loaderCall)) {
  throw new Error("Could not find the generated Flutter loader call.");
}

source = source.replace(
  loaderCall,
  `window.__kidiaStartFlutterPreview=function(){
return _flutter.loader.load({
config:{canvasKitBaseUrl:"canvaskit/"},
onEntrypointLoaded:async function(engineInitializer){
try{
var appRunner=await engineInitializer.initializeEngine({canvasKitBaseUrl:"canvaskit/"});
await appRunner.runApp();
}catch(error){
window.dispatchEvent(new CustomEvent("kidia-flutter-preview-error",{detail:String(error)}));
}
}
}).catch(function(error){
window.dispatchEvent(new CustomEvent("kidia-flutter-preview-error",{detail:String(error)}));
});
};
window.__kidiaStartFlutterPreview();`,
);

fs.writeFileSync(bootstrapPath, source);

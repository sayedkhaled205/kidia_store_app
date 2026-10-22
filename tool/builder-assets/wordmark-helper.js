  function wordmarkMarkup(card, url) {
    var match = String(url).match(/#wm=([0-9.,]+)/), crop = match ? match[1].split(',').map(Number) : [];
    var width = number(card, "logo_width", 118, 32, 220), height = number(card, "logo_height", 38, 20, 80);
    if (crop.length === 5 && crop.every(Number.isFinite) && crop[2] > 0 && crop[3] > 0 && crop[4] > 0) {
      var w = Math.min(width, height * crop[4]), h = w / crop[4];
      return '<span class="mobishop-wordmark-frame" style="display:inline-block;position:relative;overflow:hidden;width:'+w+'px;height:'+h+'px"><img class="mobishop-app-header-logo" src="'+esc(url)+'" alt="" style="position:absolute;max-width:none;max-height:none;object-fit:fill;width:'+(w/crop[2])+'px;height:'+(h/crop[3])+'px;left:'+(-crop[0]*w/crop[2])+'px;top:'+(-crop[1]*h/crop[3])+'px"></span>';
    }
    return '<img class="mobishop-app-header-logo" src="'+esc(url)+'" alt="" style="width:'+width+'px;height:'+height+'px">';
  }

function hex(x) {
  return ("0" + parseInt(x).toString(16)).slice(-2);
}

function rgb2hex(rgb) {

    if (rgb == null || rgb === "transparent") return "#FFFFFF";

    if (/^#[0-9A-F]{6}$/i.test(rgb)) return rgb;

    rgb = rgb.match(/^rgb\((\d+),\s*(\d+),\s*(\d+)\)$/);
    return "#" + hex(rgb[1]) + hex(rgb[2]) + hex(rgb[3]);
    
}

function switch_style ( css_title ) {

    var i, link_tag, correct_style, default_style, new_style ;
    correct_style = 0;

    for (i = 0, link_tag = document.getElementsByTagName("link") ; i < link_tag.length ; i++ ) {
      if ( (link_tag[i].rel.indexOf( "stylesheet" ) != -1) && link_tag[i].title) {
        
        if ((link_tag[i].rel.indexOf( "alternate stylesheet" ) != -1))
           link_tag[i].disabled = true ;
        else
           default_style = link_tag[i];

        if (link_tag[i].title == css_title) {
          new_style = link_tag[i];
          correct_style = 1;
        }
      }

    }

   if (correct_style == 1) //if the style that was switched to exists
   {
      default_style.disabled = true ; //we disable the default style 
      new_style.disabled = false ; //we enable the new style
      localStorage.customCSS = css_title; //we set a localStorage value containing the value for the new style
   }

   //write theme-color meta tag
    var color = "#FFFFFF";
    if ($(".ido").length )
      color = rgb2hex($(".ido").css("background-color"));
    else if ($(".sni").length )
      color = rgb2hex($(".sni").css("background-color"));

    $('meta[name=theme-color]').remove();
    $('head').append('<meta name="theme-color" content="'+color+'">');

}

function set_style_from_storage() {

    var css_title = localStorage.customCSS;

    if (css_title) 
      switch_style( css_title );
}
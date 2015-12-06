
function switch_style ( css_title )
{
// You may use this script on your site free of charge provided
// you do not remove this notice or the URL below. Script from
// http://www.thesitewizard.com/javascripts/change-style-sheets.shtml
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
  localStorage.customCSS = css_title;
  //set_cookie( style_cookie_name, css_title, style_cookie_duration ); //we set a cookie containing the value for the new style
 }

}

function set_style_from_storage()
{
  var css_title = localStorage.customCSS;

  //if (css_title.length) {
    if (css_title) { 
    switch_style( css_title );
  }
}
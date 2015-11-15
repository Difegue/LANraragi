//I STOLE THIS AND HAVE NO SHAME WHATSOEVER

var style_cookie_name = "ruto" ;
var style_cookie_duration = 30 ;

// You do not need to customise anything below this line

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
  set_cookie( style_cookie_name, css_title, style_cookie_duration ); //we set a cookie containing the value for the new style
 }

}

function set_style_from_cookie()
{
  var css_title = get_cookie( style_cookie_name );

  //if (css_title.length) {
    if (css_title!=undefined) { 
    switch_style( css_title );
  }
}
function set_cookie ( cookie_name, cookie_value,
    lifespan_in_days, valid_domain )
{
    // http://www.thesitewizard.com/javascripts/cookies.shtml
    var domain_string = valid_domain ?
                       ("; domain=" + valid_domain) : '' ;
    document.cookie = cookie_name +
                       "=" + encodeURIComponent( cookie_value ) +
                       "; max-age=" + 60 * 60 *
                       24 * lifespan_in_days +
                       "; path=/" + domain_string ;
}
function get_cookie ( cookie_name )
{
	//rewritten.
	var cookie_string = document.cookie ;
    if (cookie_string.length != 0) {
        //var cookie_value = cookie_string.match ('(^|;)[\s]*' + cookie_name + '=([^;]*)' );
        //return decodeURIComponent ( cookie_value[2] ) ;
		return cookie_string.substr(document.cookie.indexOf(cookie_name)).split("=")[1]
	}
    return '' ;
}

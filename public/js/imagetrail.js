/*
Simple Image Trail script- By JavaScriptKit.com
Visit http://www.javascriptkit.com for this script and more
This notice must stay intact
*/ 
//although it really shouldn't considering how much I modified this
var w=1
var h=1
var thumbnail

if (document.getElementById || document.all)
document.write('<div id="trailimageid" style="position:absolute;visibility:hidden;left:0px;top:-1000px;width:1px;height:1px;border:1px solid #888888;background:#DDDDDD;z-index: 99999;">'
				+'<img id="ttimg" src="img/empty.png" /><i id="ttspinner" class="fa fa-4x fa-cog fa-spin ttspinner" style="display:none"></i></div>')

function gettrailobj()
{
	if (document.getElementById) return document.getElementById("trailimageid").style
	else if (document.all) return document.all.trailimagid.style
}

function truebody()
{
	return (!window.opera && document.compatMode && document.compatMode!="BackCompat")? document.documentElement : document.body
}

function hidetrail()
{
	document.onmousemove=""
	document.getElementById('ttimg').src='img/empty.png'
	hideSpinner();
	gettrailobj().visibility="hidden"
	gettrailobj().left=-1000
	gettrailobj().top=0
}

function findHHandWW() {
    h = this.height;
	w = this.width;
	gettrailobj().width=w+"px";
	gettrailobj().height=h+"px";
	document.onmouseover=followmouse
	gettrailobj().visibility="visible"
	return true;
  }
  
function showImage(imgPath) {
    var myImage = new Image();
    myImage.name = imgPath;
    myImage.onload = findHHandWW;
    myImage.onerror = function(){showImage('img/noThumb.png')};
    myImage.src = imgPath;
    document.getElementById('ttimg').src=imgPath;
  }

function showSpinner()
{
	showtrail('img/wait_warmly.jpg');
	document.getElementById('ttspinner').style='display:block';
}

function hideSpinner()
{
	document.getElementById('ttspinner').style='display:none';
}

function showtrail(file)
{
	hideSpinner();

	if(navigator.userAgent.toLowerCase().indexOf('opera') == -1)
	{

		if(file.indexOf(".jpg") !=-1) //Have we been given a proper thumbnail?
			showImage(file);
		else
			showImage('img/noThumb.png');
	}
}

function followmouse(e)
{

	if(navigator.userAgent.toLowerCase().indexOf('opera') == -1)
	{

		var xcoord=20
		var ycoord=20

		if (typeof e != "undefined")
		{
			xcoord+=e.pageX
			ycoord+=e.pageY
		}
		else if (typeof window.event !="undefined")
		{
			xcoord+=truebody().scrollLeft+event.clientX
			ycoord+=truebody().scrollTop+event.clientY
		}

		var docwidth=document.all? truebody().scrollLeft+truebody().clientWidth : pageXOffset+window.innerWidth-15
		var docheight=document.all? Math.max(truebody().scrollHeight, truebody().clientHeight) : Math.max(document.body.offsetHeight, window.innerHeight)

		if (xcoord+w+3>docwidth)
		xcoord=xcoord-w-(20*2)

		if (ycoord-truebody().scrollTop+h>truebody().clientHeight)
		ycoord=ycoord-h-20;

		gettrailobj().left=xcoord+"px"
		gettrailobj().top=ycoord+"px"

	}

}

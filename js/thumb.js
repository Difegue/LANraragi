/*
Simple Image Trail script- By JavaScriptKit.com
Visit http://www.javascriptkit.com for this script and more
This notice must stay intact
*/ 

var w=1
var h=1

if (document.getElementById || document.all)
document.write('<div id="trailimageid" style="position:absolute;visibility:hidden;left:0px;top:-1000px;width:1px;height:1px;border:1px solid #888888;background:#DDDDDD;"><img id="ttimg" src="img/s.gif" /></div>')

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
	document.getElementById('ttimg').src='/img/s.gif'
	gettrailobj().visibility="hidden"
	gettrailobj().left=-1000
	gettrailobj().top=0
}


function showtrail(width,height,file)
{
	if(navigator.userAgent.toLowerCase().indexOf('opera') == -1)
	{
		w=width
		h=height
		
		// followmouse()
	
		document.getElementById('ttimg').src=file
		document.onmousemove=followmouse
		gettrailobj().visibility="visible"
		gettrailobj().width=w+"px"
		gettrailobj().height=h+"px"


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
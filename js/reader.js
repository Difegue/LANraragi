//functions to navigate and display images into reader.pl
var images = [];

function goto_first(array)
{
document.getElementById("img").src = array[0];
document.getElementById("current1").innerHTML = (1).toString();
document.getElementById("current2").innerHTML = (1).toString();
}

function goto_prev(array)
{
pagenum = parseInt(document.getElementById("current1").innerHTML);

if (pagenum >1)
	{
	document.getElementById("img").src = (array[pagenum-1]);
	document.getElementById("current1").innerHTML = (pagenum-1).toString();
	document.getElementById("current2").innerHTML = (pagenum-1).toString();
	}

}

function goto_next(array)
{
pagenum = parseInt(document.getElementById("current1").innerHTML);

if (pagenum < array.length-1)
	{
	document.getElementById("img").src = (array[pagenum+1])
	document.getElementById("current1").innerHTML = (pagenum+1).toString();
	document.getElementById("current2").innerHTML = (pagenum+1).toString();
	}

}

function goto_last(array)
{

document.getElementById("display").innerHTML = array[array.length-1].src;
//document.getElementById("img").src = array[array.length-1];
//document.getElementById("current1").innerHTML = (array.length).toString();
//document.getElementById("current2").innerHTML = (array.length).toString();
}

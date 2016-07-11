/*
A WHOLE LOT OF DATATABLES INITIALISATION OH MY GOD
*/

//Switch view on index and saves the value in the user's localStorage. The DataTables callbacks adapt automatically.
//0 = List view
//1 = Thumbnail view
function switch_index_view() {

  if (localStorage.indewViewMode === 1)
    localStorage.indexViewMode = 0;
  else
    localStorage.indewViewMode = 1;

  //Redraw the table yo
  arcTable.draw();

}

//For datatable init below, columns with just one data source display that source as a link for instant search.
function genericColumnDisplay(data,type,full,meta) {
	if(type == "display")
		return '<a style="cursor:pointer" onclick="$(\'#srch\').val($(this).html()); arcTable.search($(this).html()).draw();">'+data+'</a>';

	return data;
}

//Functions executed on DataTables draw callbacks to build the thumbnail view if it's enabled:
//Inits the div that contains the thumbnails
function thumbViewInit(settings) {
	//we only do all this thingamajang if thumbnail view is enabled
	if (localStorage.indexViewMode === 1)
	{
		// create a thumbs container if it doesn't exist. put it in the dataTables_scrollbody div
		if ($('#thumbs_container').length < 1) $('.dataTables_scrollbody').append("");

		// clear out the thumbs container
		$('#thumbs_container').html('');
	}

}
//Builds a id1 class div to jam in the thumb container for an archive whose JSON data we read
function buildThumbDiv( row, data, index ) {

	if (localStorage.indexViewMode === 1)
	{

		//Build a thumb-like div with the data and jam it in thumbs_container
		thumb_div = '<div style="height:335px" class="id1">

						<div class="id2">
							<a href="./reader.pl?id='+data.arcid+'">'+data.title+'</a>
						</div>

						<div style="height:280px" class="id3">
							<a href="./reader.pl?id='+data.arcid+'">';

		if (data.thumbnail=="null")	//Might improve things and jam an ajax request for the thumbnail in here later		
			thumb_div += 		'<img style="position:relative; top:-10px" title="'+data.title+'" src="./img/noThumb.png"/>';
		else
			thumb_div += 		'<img style="position:relative; top:-10px" title="'+data.title+'" src="'+data.thumbnail+'"/>';

		thumb_div +=		'</a>
						</div>

						<div class="id4">
							<div class="id41">'+data.artist+'</div>
							<div class="id42">'+data.series+'</div>
							<div class="id43">'+data.language+'</div>
							<div class="id44">
								<div style="float:right">
									<img src="img/n.gif" style="float: right; margin-top: -15px; z-index: -1; display: '+data.isnew+'">
								</div>
							</div>
						</div>

					</div>';

		$('#thumbs_container').append(thumb_div);
	}
}


//Executed onload of the archive index to initialize a bunch of shit. 
//This is painful to read.
function initIndex(pagesize,dataSet)
{
	thumbTimeout = null;
									
	$.fn.dataTableExt.oStdClasses.sStripeOdd = 'gtr0';
	$.fn.dataTableExt.oStdClasses.sStripeEven = 'gtr1';

	//datatables configuration
	arcTable= $('.itg').DataTable( {
		'data': dataSet, 
		'lengthChange': false,
		'pageLength': pagesize,
		'order': [[ 1, 'asc' ]],
		'dom': '<"top"ip>rt<"bottom"p><"clear">',
		'language': {
				'info':           'Showing _START_ to _END_ of _TOTAL_ ancient chinese lithographies.',
				'infoEmpty':      '<h1>No archives to show you ! Try <a href="upload.pl">uploading some</a> ?</h1>',
			},
		'preDrawCallback': thumbViewInit, //callbacks for thumbnail view
		'rowCallback': buildThumbDiv,
		'columns' : [
			{ className: 'itdc', 
			  'width': '20',
			  'data': null,
			  'render': function ( data, type, full, meta ) { 
			  			if(type == "display"){
					      return '<div style="font-size:14px"><a href="'+data.url+'" title="Download this archive.">'
					      		+'<i class="fa fa-save" style="margin-right:2px"></i><a/><a href="./edit.pl?id='+data.arcid+'" title="Edit this archive\'s tags and data."><i class="fa fa-pencil"></i><a/></div>';
							}

					return data;
					 } 
			},
			{ className: 'title itd',
			  'data': null,
			  'render': function ( data, type, full, meta ) {
			  			if(type == "display"){
			  				line = '<span style="display: none;">'+data.title+'</span><a href="./reader.pl?id='+data.arcid+'" onmouseout="hidetrail(); clearTimeout(thumbTimeout);" ';

			  				if (data.thumbnail=="null")
			  					line+='onmouseover="thumbTimeout = setTimeout(ajaxThumbnail, 200, \''+data.arcid+'\')" >';
			  				else
			  					line+='onmouseover="thumbTimeout = setTimeout(showtrail, 200, \''+data.thumbnail+'\')" >';

						    line+= data.title+'</a><img src="img/n.gif" style="float: right; margin-top: -15px; z-index: -1; display: '+data.isnew+'">';

						    return line;
							}

					return data.title;
					} 
			},
			{ className: 'artist itd',
			  'data': 'artist',
			  'render': genericColumnDisplay
			},
			{ className: 'series itd',
			  'data': 'series',
			  'render': genericColumnDisplay
			},
			{ className: 'language itd',
			  'data': 'language',
			  'render': genericColumnDisplay
			},
			{ className: 'tags itd',
			  'data': 'tags',
			  'render': function (data, type, full, meta ) {
			  			if(type == "display"){
			  				line = '<span class="tags" style="text-overflow:ellipsis;">'+data+'</span>';

			  				if (data!="")
			  					{
			  						line+='<div class="caption" style="position:absolute;">';

					  				data.split(/,\s?/).forEach(function (item) {
									    line+='<div class="gt" onclick="$(\'#srch\').val($(this).html()); arcTable.search($(this).html()).draw();">'+item+'</div>';
									});

									line+='</div>';
								}
							return line;
			  			}

			  		return data;
			  		}


			}
		],
	});

	//Initialize CSS dropdown with dropit
	$('.menu').dropit({
		action: 'click', // The open action for the trigger
		submenuEl: 'div', // The submenu element
		triggerEl: 'a', // The trigger element
		triggerParentEl: 'span', // The trigger parent element
		afterLoad: function(){}, // Triggers when plugin has loaded
		beforeShow: function(){}, // Triggers before submenu is shown
		afterShow: function(){}, // Triggers after submenu is shown
		beforeHide: function(){}, // Triggers before submenu is hidden
		afterHide: function(){} // Triggers before submenu is hidden
	});

	//Set the correct CSS from the user's localStorage again, in case the version in <script> tags didn't load.
	//(That happens on mobiles for some reason.)
	set_style_from_storage();

	//add datatable search event to the local searchbox and clear search to the clear filter button
	$('#srch').keyup(function(){
	    arcTable.search($(this).val()).draw() ;
	});

	$('#clrsrch').click(function(){
		arcTable.search('').draw(); 
		$('#srch').val('');
		});

	//clear searchbar cache
	$('#srch').val('');

	//nuke style of table - datatables seems to assign its table a fixed width for some reason.
	$('.itg').attr("style","")

	//end init thumbnails
	hidetrail();
	document.onmouseover=followmouse;
			
}


// $BACKGROUND$

// Script for operations applied to all images in a folder, tested on GMS 2.31
// Peterlechner 2019, with the help ofscripts by Mitchell, Schaffer, Koch and Gammer




Class MainDialog : UIframe
{
	// RGB images for buttons
	image green(object self) 	return RGBImage("",4,20,20) 	=	RGB(0,200,0)
	image red(object self) 	return RGBImage("",4,20,20) 	=	RGB(200,0,0)
	
	// variables
	string pathname, directory, filename, extension
	string outpathname, outdirectory, outfilename, outextension
	TagGroup tgFiles													// number of files
	number numberoffiles 												// get number of files in directory

	
	

	
	//---------voids-----------------------------------------------------------------------------------

	image  elliptic_undistort(object self, image img, number e, number theta)
	{
		number radiuschange=(e+1)/2
		number phi=-theta/180*pi() 
		image unwarped=img
		image temp1=img.rotate(phi)
		image temp2=temp1
		temp2=warp(temp1, e*icol/radiuschange, irow/radiuschange)
		image temp3=temp2.rotate(-phi)
		//crop to correct size
		number xsize,ysize,xsize2,ysize2
		getsize(unwarped,xsize,ysize)
		getsize(temp3,xsize2,ysize2)
		number xdif=(xsize2-xsize)/2
		number ydif=(ysize2-ysize)/2
		unwarped=warp(temp3, icol+xdif, irow+ydif)
  
		// Calibrate and name the new image
		ImageCopyCalibrationFrom(unwarped,img)
		string imagename
		getname(img,imagename)
		setname(img,imagename+"_old")
		setname(unwarped,imagename)
		TagGroup sourcetags=imagegettaggroup(img)
		TagGroup targettags=imagegettaggroup(unwarped) 
		taggroupcopytagsfrom(targettags,sourcetags)
	
		return(unwarped)
	}
   


//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------
 
 void Button_makestack(object self)
	{
	Result("\nMake stack from all files in ")
	result(directory)
	
	//----variables and definitions------------------------------------------------------
	image img3D, tempimg
	number fileid
	number fFiles = 1
	TagGroup FileList
	number nTags
	number height, width 


	
	//------------------------------ make stack routine ---------------------------------
	tempimg = OpenImage(pathname)
	tempimg.GetSize(width, height)
	closeimage(tempimg)
    
	FileList = GetFilesInDirectory( directory, fFiles  )

	outdirectory = outdirectory + "stack/"
	if (!DoesDirectoryExist(outdirectory)) CreateDirectory(outdirectory)
	Result("\nOutput path is "+outdirectory)
	
	nTags = FileList.TagGroupCountTags()
	Result("\nImport images from "+directory+" to create a stack")
	Result("\nNumber of files found: "+nTags)

	img3D := RealImage( "stack", 4, width, height, nTags )

	//-----actual reading of files------------------------------------------------------
	for ( number z = 0; z < nTags; z++ )
	{
	TagGroup TG
    FileList.TagGroupGetIndexedTagAsTagGroup( z, TG )
    if ( TG.TagGroupIsValid() )
		{
        string filestr
        if ( TG.TagGroupGetTagAsString( "Name", filestr ) )
        {
            
            pathname=directory + filestr           
            extension=pathextractextension(pathname, 2)           
            filename=pathextractbasename(pathname, 2)

			result( "\n File:" + pathname )
			
			tempimg = OpenImage(pathname)
			//showimage(tempimg)
			img3D[0,0,z,width,height,z+1] = tempimg[]			//-image to 3d selection [left,top,front,right,bottom,back]
			closeimage(tempimg)
			
		}
		}
	}
	SaveAsGatan(img3D, outdirectory+filename+"-stack")
	showimage(img3D)
	}



//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------

  void Button_convertrawdm(object self)
	{
	Result("\nConvert raw to DM files (4 byte signed integer,as from TIA) in ")
	Result(directory)
	Result("\nPlease be patient, depending on hardware and number of images")
	
	TagGroup FileList
	number nTags, height, width 
	number fFiles = 1
	number file_ID
	image tempimg

	FileList = GetFilesInDirectory( directory, fFiles  )
	nTags = FileList.TagGroupCountTags()

	outdirectory = outdirectory + "dm_convert/"
	if (!DoesDirectoryExist(outdirectory)) CreateDirectory(outdirectory)
	Result("\nOutput path is "+outdirectory)
	
	if(!getnumber("Enter image height = ",512,height)) exit(0)
	if(!getnumber("Enter image width = ",512,width)) exit(0)

	//-----actual reading of files------------------------------------------------------
	for ( number z = 0; z < nTags; z++ )
	{
	TagGroup TG
    FileList.TagGroupGetIndexedTagAsTagGroup( z, TG )
    if ( TG.TagGroupIsValid() )
		{
		string filestr
        if ( TG.TagGroupGetTagAsString( "Name", filestr ) )
			{
            
            pathname=directory + filestr           
            extension=pathextractextension(pathname, 2)           
            filename=pathextractbasename(pathname, 2)
			object file_stream
			file_ID = OpenFileForReading(pathname) 
			file_stream  = NewStreamFromFileReference(file_ID, 1)

			tempimg := IntegerImage("Temporary-integer-image",4,1,width, height)  //might be necessary to change

			ImageReadImageDataFromStream(tempimg, file_stream, 0)

			CloseFile(file_ID)
			SaveAsGatan(tempimg, outdirectory+filename)
			}
		}
	}
	Deleteimage(tempimg)
	Result("\nConversion done!")
	}

//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------

  void Button_rebin(object self)
	{
	Result("\nRebin by 2 all files in ")
	result(directory)

	
	//----variables and definitions------------------------------------------------------
	image tempimg, BinImg, BinImg2
	number file_ID, isbytelength
	number fFiles = 1
	TagGroup FileList
	number nTags
	number height, width 
	
	tempimg = OpenImage(pathname)
	tempimg.GetSize(width, height)
	closeimage(tempimg)

	BinImg := IntegerImage("Temporary-bin-image",4,1,width/2, height/2)

	FileList = GetFilesInDirectory( directory, fFiles  )

	outdirectory = outdirectory + "binned2/"
	if (!DoesDirectoryExist(outdirectory)) CreateDirectory(outdirectory)
	
	nTags = FileList.TagGroupCountTags()

	
	//-----actual binning of files------------------------------------------------------
	for ( number z = 0; z < nTags; z++ )
{
	TagGroup TG
    FileList.TagGroupGetIndexedTagAsTagGroup( z, TG )
    if ( TG.TagGroupIsValid() )
    {
        string filestr
        if ( TG.TagGroupGetTagAsString( "Name", filestr ) )
        {
            
            pathname=directory + filestr           
            extension=pathextractextension(pathname, 2)           
            filename=pathextractbasename(pathname, 2)	
			tempimg = OpenImage(pathname)
			
			BinImg = ( tempimg[ 2*icol-1, 2*irow - 1 ] + 	\
			tempimg[ 2*icol-1, 2*irow ]     + 	\
			tempimg[ 2*icol-1, 2*irow + 1 ] + 	\
			tempimg[ 2*icol,   2*irow - 1 ] + 	\
			tempimg[ 2*icol,   2*irow ]     + 	\
			tempimg[ 2*icol,   2*irow+1 ]   + 	\
			tempimg[ 2*icol+1, 2*irow-1 ]   + 	\
			tempimg[ 2*icol+1, 2*irow ]     + 	\
			tempimg[ 2*icol+1, 2*irow + 1 ] ) / 9
			
			SaveAsGatan(BinImg, outdirectory+filestr)			
		}
	}
	}
	Deleteimage(BinImg)
	Result("\nBinning done!")

	
	}




//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------

  void Button_selection(object self)
	{
	Result("\nStoreing selection of files in ")
	result(directory)

	
	//----variables and definitions------------------------------------------------------
	image tempimg, selec
	number file_ID
	number fFiles = 1
	TagGroup FileList
	number nTags
	number height, width
	number t,l,b,r
	number key = 0
	
	tempimg = OpenImage(pathname)
	tempimg.GetSize(width, height)
	showimage(tempimg)
	OkDialog("Set ROI then press Enter and set number of scaned lines")
	imageDisplay disp = tempimg.ImageGetImageDisplay(0)
	ROI sourceROI = disp.ImageDisplayGetRoi(0)
	
	if ( !sourceROI.ROIIsValid()==0 ) {
		tempimg.GetSelection(t,l,b,r)
		Result("\nSelection found at (t,l,b,r): "+t+","+l+","+b+","+r)
		}
	Else{
		t=Ceil(height/4);l=Ceil(width/4);b=Ceil(height/2);r=Ceil(width/2)
		tempimg.SetSelection(t,l,b,r)
		}


	Result("\nPress Enter to stop ROI selection. Use courser to move ROI.")
	while(key != 13) {
		key = GetKey()	

		If(key==28) {	If(l>=1) {l=l-1;r=r-1;} 	
					};
		If(key==29) { 	If(r<=width){l=l+1;r=r+1;}
					};
		If(key==30) {	If(t>=0) {t=t-1;b=b-1;}
					};
		If(key==31) {	If(b<=height){t=t+1;b=b+1;}
					};
		If(key==43) {	If(b<=height){b=b+1;}
						If(r<=width){r=r+1;}
					};
		If(key==45) {	If(b>t){b=b-1;}
						If(r>l){r=r-1;}
					};
		tempimg.SetSelection(t,l,b,r)
	}

	Result("\nSelection is set to "+t+","+l+","+b+","+r)

	//closeimage(tempimg)


	FileList = GetFilesInDirectory( directory, fFiles  )

	outdirectory = outdirectory + "selection/"
	if (!DoesDirectoryExist(outdirectory)) CreateDirectory(outdirectory)
	
	nTags = FileList.TagGroupCountTags()

	//-----actual autocor of files------------------------------------------------------
	for ( number z = 0; z < nTags; z++ )
	{
	TagGroup TG
    FileList.TagGroupGetIndexedTagAsTagGroup( z, TG )
    if ( TG.TagGroupIsValid() )
		{
        string filestr
        if ( TG.TagGroupGetTagAsString( "Name", filestr ) )
        {
            pathname=directory + filestr           
            extension=pathextractextension(pathname, 2)           
            filename=pathextractbasename(pathname, 2)

			tempimg := OpenImage(pathname)


			selec = tempimg[t,l,b,r]

			saveasgatan(selec, outdirectory+filestr)
			deleteimage(tempimg)
		}
		}
	}
	Result("\nSelection of files stored!")

	
	}

//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------



  void select_folder(object self)
		{
		string FolderStr
		Result("\nSelect input folder:")
		//if(!OpenDialog(pathname)) exit(0);
		if(!OpenDialog(pathname)) exit(0)

		
		filename=pathextractbasename(pathname,0)
		directory=pathextractdirectory(pathname,2)
		outdirectory=directory
		extension=pathextractextension(pathname,2)
		tgFiles = GetFilesInDirectory(directory, 1 );				// number of files
		numberoffiles = tgFiles.TagGroupCountTags( );
		result("\n"+directory)
		self.LookupElement("StatusLight").DLGGetElement(0).DLGBitmapData(self.green())
		FolderStr = directory
		self.LookupElement("folder_label").DLGTitle(FolderStr)
		
		FolderStr = outdirectory + "'operation-name'"
		self.LookupElement("folderout_label").DLGTitle(FolderStr)

		result("\nFound "+numberoffiles+" files.")
		}

//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------

		

  void select_outfolder(object self)
		{
		string FolderStr
		Result("\nSelect output folder:")
		//if(!OpenDialog(pathname)) exit(0);
		if(!SaveAsDialog("","Do Not Change Me",outpathname)) return
		
		outdirectory=pathextractdirectory(outpathname,2)
		
		result("\n"+outdirectory)
		FolderStr = outdirectory + "'operation-name'"
		self.LookupElement("folderout_label").DLGTitle(outdirectory)
		}


//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------



  MainDialog(object self)
	{
	result("\n\nFolder operations started (Peterlechner 2019)")
	}

  ~MainDialog(object self)
	{
	result("\nFolder operations closed.")
	}
}


//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------
//-----------------------------------------------------------------------------------------------------------------------------------------


Class StartDialog: object
{
 	TagGroup 	Dialog, DialogItems, Dialogposition
	Object		DialogWindow

	TagGroup MainButtons(object self)
		{
		taggroup box,boxitems
		box = DLGCreateGroup(boxitems)
		
		boxitems.DLGAddElement(DLGCreatePushButton("   Convert   raw-to-DM  ","Button_convertrawdm").DLGIdentifier("conv_button"))
		boxitems.DLGAddElement(DLGCreatePushButton("        Rebin by 2        ","Button_rebin").DLGIdentifier("rebin_button"))
		boxitems.DLGAddElement(DLGCreatePushButton("       Store selection       ","Button_selection").DLGIdentifier("selection_button"))


		boxitems.DLGAddElement(DLGCreatePushButton("       Make stack         ","Button_makestack").DLGIdentifier("stack_button"))

		box.DLGtablelayout(2,3,0)
		return box
		}

	taggroup StatusBitmap(object self)				//create "status-lights" used below.
		{
		image RGBbit 	= RGBImage("",4,20,20)
		RGBbit			= RGB(200,0,0)
		taggroup cBIT	= DLGCreateGraphic(20,20)
		cBIT.DLGAddBitmap(RGBbit)
		return cBit
		}

	taggroup MainStatusLine(object self)
		{
		taggroup box,boxitems
		box = DLGCreateGroup(boxitems)
		boxitems.DLGAddElement(DLGCreatePushButton("Select input folder   ","select_folder").DLGIdentifier("folder_button"))
		boxitems.DLGAddElement(self.StatusBitmap().DLGIdentifier("StatusLight"))
		boxitems.DLGAddElement(DLGCreateLabel("  no folder selected       ").DLGIdentifier("folder_label"))
		box.DLGtablelayout(3,1,0)
		return box
		}
		

	taggroup MainStatusLine2(object self)
		{
		taggroup box,boxitems
		box = DLGCreateGroup(boxitems)
		boxitems.DLGAddElement(DLGCreatePushButton("Select output folder","select_outfolder").DLGIdentifier("folderout_button"))
		boxitems.DLGAddElement(DLGCreateLabel("         no folder selected       ").DLGIdentifier("folderout_label"))
		box.DLGtablelayout(2,1,0)
		return box
		}

  	taggroup CreateDialog(object self)	// Putting all into "dialog taggroup"
		{
		TagGroup DLGitems
		TagGroup CompleteDLG	= 	DLGCreateGroup(DLGitems)

		DLGItems.DLGAddElement(DLGCreateLabel("_______________________________________________"))
		DLGItems.DLGAddElement(self.MainStatusLine().DLGAnchor("Left"))
		DLGItems.DLGAddElement(self.MainStatusLine2().DLGAnchor("Left"))
		DLGItems.DLGAddElement(self.MainButtons().DLGAnchor("Center"))
		DLGItems.DLGAddElement(DLGCreateLabel("_______________________________________________"))
		return CompleteDLG
		}

	 Object Init(object self)
		{
		// Create and start the floating dialog
		Dialog 		 = DLGCreateDialog("Folder operations",DialogItems)	
		DialogWindow = Alloc(MainDialog).init(Dialog)
					
		// Add the Dialog 
		DialogItems.DLGAddElement(self.CreateDialog())

		// Create Position for Dialog
		Dialogposition	= DLGBuildPositionFromApplication()
		Dialogposition.TagGroupSetTagAsTagGroup( "Width", DLGBuildAutoSize() )
		Dialogposition.TagGroupSetTagAsTagGroup( "Height", DLGBuildAutoSize() )
		Dialogposition.TagGroupSetTagAsTagGroup( "X", DLGBuildRelativePosition( "Inside", -1 ) )	
		Dialogposition.TagGroupSetTagAsTagGroup( "Y", DLGBuildRelativePosition( "Inside", -1 ) )
		Dialog.DLGposition(DialogPosition)
	
		DialogWindow.Display("Folder operations (Peterlechner 2019)")
	}

}


void CALLmain()
	{
	result("\n\n DIALOG for folder operations\n")
	Alloc(StartDialog).Init()
	}

CALLmain()
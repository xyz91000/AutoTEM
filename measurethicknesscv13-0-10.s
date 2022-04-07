//-----------------------------------------------------------------------------------------------
// MeasureThickness - GTO May 2015 (g.t.oostergetel [at] rug.nl)
//-----------------------------------------------------------------------------------------------
// Version 12 for Arctica with energy filter
// Measure thickness in a low mag overview image
// with an option to color code the thickness in the image
// Keeping <Ctrl> pressed at startup will ask you for the optimal thickness values (min -> max);
//   and you can also specify binning and exposure time
// In the filter mode the script will take take two images: one unfiltered (slit out), one filtered (slit in). Only the filtered image is shown.
// In the ALS mode the script will take take only one (unfiltered) image. This unfiltered image is shown
// Then using the pointer to select a position and hitting the <t> or <T> will print 
//   the estimated thickness;
// Hitting <c> will create a color map; in this image you still can do local thickness measurements
// The following parameters can be changed as global tags:
//		MaxCounts			- max counts per pixel to avoid too high coincidence loss (default 10 for K2; 10*1500/400*32 = 1200 for K3)
//		MeasureRadius		- radius of the selection box for measurements in unbinned pixels (scaled by the magnification relative to M910)
//		DisplayRed			- boolean that determines whether too thin areas are marked in red
//		ColorFraction		- strength of the color(s) in the RGB map
//		ThicknessCorr		- correction in nm to ensure zero thickness in a hole
//		MeanFreePathInIce	- MFP for 200 or 300 kV
//		ALSfactor			- for the ALS method
//		RefLocalIntensity	- reference intensity in a hole for ALS method
//		CameraRotation		- Camera rotation to match the image orientation in DM relative to EPU
// 
// v12 - test version for Arctica and Krios
// v12.2	- including ALS method
// v13 - including K3
//-----------------------------------------------------------------------------------------------

//---- parameter					(default) value
//--------------------------------------------------------
string VersionNumber				= "v13.0.10"		// 18 February 2021

number Platform								// 0 = Talos, 1 = Titan; required because a Titan has an image rotation in LM relative to SA
number LocalIntensity
number RefLocalIntensity
number ALSfactor
number ForceALS								// for testing purposes
number MeanFreePathInIce
number MeanFreePathInIce200SA		= 305
number MeanFreePathInIce200LM		= 485
number MeanFreePathInIce300SA		= 435
number MeanFreePathInIce300LM		= 805
number DummyMeanFreePathInIce
number kV
number LocalThickness
number MeasureRadius				= 20
number CameraX
number CameraY
number NewPosition, KeyNumber
number Zoom
number MinThicknessForColorDisplay	= 20
number MaxThicknessForColorDisplay	= 40
number XSize,YSize
number Delta, Maximum, Minimum, OldMaximum, OldMinimum
number MedianFilterType				= 3
number MedianFilterSize				= 3
number ColorImgShown
number ColorFraction				= 0.75
number XPosition, YPosition
number theMag, MagIndex
number ThicknessCorr				= 0
number DummyThicknessCorr
number ThicknessCorrLM				= 35	// [nm] default for EFTEM mode in LM; default for TEM mode is 0
number ThicknessCorrMSA				= 4		// [nm] default for EFTEM mode in M or SA; default for TEM mode is 0
number camID
number exposureTime					= 2
number OldExposureTime
number Binning						= 4
number BinningIndex					= 3
number OldBinningIndex
number MeanCounts
number MaxCounts					= 10	// default for K2; adjusted to 1200 for the K3
number ControlWasDown
number DisplayRed					= 1
number CameraRotation				= 0
// ZLP correction LM
number TechID = 4
number CurrentEnergyOffset
number EnergyOffset					= 0		// default value for ZLP correction in LM
number ForceALSModeLM				= 0
number EnergyOffsetDelay			= 5		// [s]


// -- define GRACE dialogs ----------------------------------
number fieldWidth					= 6
number MiscLabelWidth				= 4
number MiscLabel3Width				= 32

string OperationMode
number EFTEMmode

image MedFilImg
image MedFilFilteredImg
image Img
image FilteredImg
image RatioImg
image MedFilRatioImg
image CorrImg
image DisplayedImage
rgbimage rgbimg

// camera
object cam_mgr, camera, acq_params
object user_interact
number wait_for_prepare = 1
number top, left, bottom, right
number validation
string CameraIdentifier
string CameraModel					// K2 or K3

number _GetMouseCoords(Image img, Number &X, Number &Y, number &KeyNumber)
{
	number xWin,yWin
	ImageDocument imgDoc = img.ImageGetOrCreateImageDocument()
	DocumentWindow DocWin = imgDoc.ImageDocumentGetWindow()
		DocWin.WindowGetContentSize(xWin,yWin)
	KeyNumber = 0
	while (1) {
		if (KeyNumber) break
		KeyNumber = GetKey()
		DocWin.WindowGetMousePosition(x,y)
		x = tert(((x < 1) || (x > xWin)),0,x)
		y = tert(((y < 1) || (y > yWin)),0,y)
		if (!x) y = 0
		if (!y) x = 0
	}
	return ((x) || (y))
}

if ( ControlDown() ) ControlWasDown = 1

// check platform when the script is executed for the first time
if (!GetPersistentNumberNote("User:Thickness:Platform",Platform)) {
	Platform = TwoButtonDialog("Which Microscope Platform?", "Titan", "Talos")
	SetPersistentNumberNote("User:Thickness:Platform",Platform)
}

// Check microscope and mode
if ( !EMIsReady( ) ) {
	Result( "--waiting for microscope to be ready-- \n" )
	EMWaitUntilReady( )
	Result( "--microscope is ready-- \n" )
}
OperationMode = EMGetOperationMode( )
if (OperationMode == "GIF IMAGING") EFTEMmode = 1
else EFTEMmode = 0

if (!GetPersistentNumberNote("User:Thickness:EFTEM:exposure Time",exposureTime))
	SetPersistentNumberNote("User:Thickness:EFTEM:exposure Time",exposureTime)
if (!GetPersistentNumberNote("User:Thickness:EFTEM:Binning",Binning))
	SetPersistentNumberNote("User:Thickness:EFTEM:Binning",Binning)
if (!GetPersistentNumberNote("User:Thickness:EFTEM:BinningIndex",BinningIndex))
	SetPersistentNumberNote("User:Thickness:EFTEM:BinningIndex",BinningIndex)
if (!GetPersistentNumberNote("User:Thickness:EFTEM:MinThicknessForColorDisplay",MinThicknessForColorDisplay))
	SetPersistentNumberNote("User:Thickness:EFTEM:MinThicknessForColorDisplay",MinThicknessForColorDisplay)
if (!GetPersistentNumberNote("User:Thickness:EFTEM:MaxThicknessForColorDisplay",MaxThicknessForColorDisplay))
	SetPersistentNumberNote("User:Thickness:EFTEM:MaxThicknessForColorDisplay",MaxThicknessForColorDisplay)
if (!GetPersistentNumberNote("User:Thickness:EFTEM:MeasureRadius",MeasureRadius))
	SetPersistentNumberNote("User:Thickness:EFTEM:MeasureRadius",MeasureRadius)
if (!GetPersistentNumberNote("User:Thickness:EFTEM:DisplayRed",DisplayRed))
	SetPersistentNumberNote("User:Thickness:EFTEM:DisplayRed",DisplayRed)
if (!GetPersistentNumberNote("User:Thickness:EFTEM:ColorFraction",ColorFraction))
	SetPersistentNumberNote("User:Thickness:EFTEM:ColorFraction",ColorFraction)
// If old type of global tag exists, delete it before creating new ones
if (GetPersistentNumberNote("User:Thickness:EFTEM:ThicknessCorr",DummyThicknessCorr))
	DeletePersistentNote("User:Thickness:EFTEM:ThicknessCorr")
if (!GetPersistentNumberNote("User:Thickness:EFTEM:ThicknessCorr:LM",ThicknessCorrLM))
	SetPersistentNumberNote("User:Thickness:EFTEM:ThicknessCorr:LM",ThicknessCorrLM)
if (!GetPersistentNumberNote("User:Thickness:EFTEM:ThicknessCorr:M-SA",ThicknessCorrMSA))
	SetPersistentNumberNote("User:Thickness:EFTEM:ThicknessCorr:M-SA",ThicknessCorrMSA)
if (!GetPersistentNumberNote("User:Thickness:CameraRotation",CameraRotation))
	SetPersistentNumberNote("User:Thickness:CameraRotation",CameraRotation)

if (!GetPersistentNumberNote("User:Thickness:EFTEM:ForceALS",ForceALS))			// for testing purposes
	SetPersistentNumberNote("User:Thickness:EFTEM:ForceALS",ForceALS)
if (!GetPersistentNumberNote("User:Thickness:EFTEM:ForceALSModeLM",ForceALSModeLM))			// if filter cannot be used in LM
	SetPersistentNumberNote("User:Thickness:EFTEM:ForceALSModeLM",ForceALSModeLM)
if (!GetPersistentNumberNote("User:Thickness:EFTEM:EnergyOffset:1",EnergyOffset)) {			// if ZLP cannot be centered in LM
//	result("Generating global tags ...\n")
	for (MagIndex = 1; MagIndex <= 16; MagIndex++) {
		SetPersistentNumberNote("User:Thickness:EFTEM:EnergyOffset:" + MagIndex,EnergyOffset)
	}
}
MagIndex = EMGetMagIndex()
If ((MagIndex < 17) && (EFTEMmode == 1) && (ForceALSModeLM)) EFTEMmode = 0		// switching to  TEM mode

// get HT and read the MFP and ALS-factor
kV = EMGetHighTension( )/1000
if (kV == 200) {				// sets the defaults for 200 kV
	if (MagIndex >= 17) {
		MeanFreePathInIce = MeanFreePathInIce200SA
		ALSfactor = 800
	}
	else {
		MeanFreePathInIce = MeanFreePathInIce200LM
		ALSfactor = 600
	}
}
if (kV == 300) {				// sets the default for 300 kV
	if (MagIndex >= 17) {
		MeanFreePathInIce = MeanFreePathInIce300SA
		ALSfactor = 2000
	}
	else {
		MeanFreePathInIce = MeanFreePathInIce300LM
		ALSfactor = 1750
	}
}

// If old type of global tag exists, delete it before creating new ones
if (GetPersistentNumberNote("User:Thickness:EFTEM:" + kV + ":MeanFreePathInIce",DummyMeanFreePathInIce))
	DeletePersistentNote("User:Thickness:EFTEM:" + kV + ":MeanFreePathInIce")
if (MagIndex >= 17) {
	if (!GetPersistentNumberNote("User:Thickness:EFTEM:" + kV + ":MeanFreePathInIce:SA",MeanFreePathInIce))	// read MFP from tag
		SetPersistentNumberNote("User:Thickness:EFTEM:" + kV + ":MeanFreePathInIce:SA",MeanFreePathInIce)		// set the tag to default if it doesn't exist
}
else {
	if (!GetPersistentNumberNote("User:Thickness:EFTEM:" + kV + ":MeanFreePathInIce:LM",MeanFreePathInIce))	// read MFP from tag
		SetPersistentNumberNote("User:Thickness:EFTEM:" + kV + ":MeanFreePathInIce:LM",MeanFreePathInIce)		// set the tag to default if it doesn't exist
}

If ((MagIndex < 17) && (ForceALSModeLM)) {
	if (!GetPersistentNumberNote("User:Thickness:TEM:" + kV + ":ALSfactor:LM",ALSfactor))	// read ALSfactor from tag for LM
		SetPersistentNumberNote("User:Thickness:TEM:" + kV + ":ALSfactor:LM",ALSfactor)		// set the tag to default if it doesn't exist
	if (!GetPersistentNumberNote("User:Thickness:TEM:" + kV + ":RefLocalIntensity:LM",RefLocalIntensity))	// read RefLocalIntensity from tag for LM
		SetPersistentNumberNote("User:Thickness:TEM:" + kV + ":RefLocalIntensity:LM",RefLocalIntensity)		// set the tag to zero if it doesn't exist
	if (!GetPersistentNumberNote("User:Thickness:TEM:ThicknessCorr",ThicknessCorr))
		SetPersistentNumberNote("User:Thickness:TEM:ThicknessCorr",0)	// default for ALS method is 0
}
If ((MagIndex >= 17) && ((EFTEMmode == 0) || (ForceALS))) {
	if (!GetPersistentNumberNote("User:Thickness:TEM:" + kV + ":ALSfactor:SA",ALSfactor))	// read ALSfactor from tag for SA
		SetPersistentNumberNote("User:Thickness:TEM:" + kV + ":ALSfactor:SA",ALSfactor)		// set the tag to default if it doesn't exist
	if (!GetPersistentNumberNote("User:Thickness:TEM:" + kV + ":RefLocalIntensity:SA",RefLocalIntensity))	// read RefLocalIntensity from tag for LM
		SetPersistentNumberNote("User:Thickness:TEM:" + kV + ":RefLocalIntensity:SA",RefLocalIntensity)		// set the tag to zero if it doesn't exist
	if (!GetPersistentNumberNote("User:Thickness:TEM:ThicknessCorr",ThicknessCorr))
		SetPersistentNumberNote("User:Thickness:TEM:ThicknessCorr",0)	// default for ALS method is 0
}

// -- Thickness/color dialog -------------------------------------------------------------
TagGroup color_dialog_items
TagGroup color_dialog = DLGCreateDialog( "Thickness / color Parameters", color_dialog_items )

	TagGroup color_dialog_color_group_items
	TagGroup color_dialog_color_group = DLGCreateElementWithItems("Box",color_dialog_color_group_items)
		color_dialog_color_group.TagGroupSetTagAsString( "Side", "Top")
		color_dialog_color_group.TagGroupSetTagAsString( "Title", "Color")
		color_dialog_color_group.TagGroupSetTagAsLongPoint( "ExternalPadding", 4, 2 )
	color_dialog_items.DLGAddElement(color_dialog_color_group)

		TagGroup color_dialog_color_group_min_items
		TagGroup color_dialog_color_group_min = DLGCreateElementWithItems("Group",color_dialog_color_group_min_items)
			color_dialog_color_group_min.TagGroupSetTagAsString( "Side", "Top")
		color_dialog_color_group_items.DLGAddElement(color_dialog_color_group_min)

			TagGroup color_dialog_color_group_min_label1 = DLGCreateElement("Label")
				color_dialog_color_group_min_label1.TagGroupSetTagAsString( "Title","Min thickness for color display")
				color_dialog_color_group_min_label1.TagGroupSetTagAsString( "Side", "Left")
				color_dialog_color_group_min_label1.TagGroupSetTagAsNumber( "Width", MiscLabel3Width)
			color_dialog_color_group_min_items.DLGAddElement(color_dialog_color_group_min_label1)

			TagGroup color_dialog_color_group_min_field1 = DLGCreateElement("Field")
				color_dialog_color_group_min_field1.TagGroupSetTagAsNumber( "Value",MinThicknessForColorDisplay)
				color_dialog_color_group_min_field1.TagGroupSetTagAsString( "Side", "Left")
				color_dialog_color_group_min_field1.TagGroupSetTagAsNumber( "Width", fieldWidth)
			color_dialog_color_group_min_items.DLGAddElement(color_dialog_color_group_min_field1)

			TagGroup color_dialog_color_group_min_label2 = DLGCreateElement("Label")
				color_dialog_color_group_min_label2.TagGroupSetTagAsString( "Title","nm")
				color_dialog_color_group_min_label2.TagGroupSetTagAsString( "Side", "Left")
				color_dialog_color_group_min_label2.TagGroupSetTagAsNumber( "Width", MiscLabelWidth)
			color_dialog_color_group_min_items.DLGAddElement(color_dialog_color_group_min_label2)

		TagGroup color_dialog_color_group_max_items
		TagGroup color_dialog_color_group_max = DLGCreateElementWithItems("Group",color_dialog_color_group_max_items)
			color_dialog_color_group_max.TagGroupSetTagAsString( "Side", "Top")
		color_dialog_color_group_items.DLGAddElement(color_dialog_color_group_max)

			TagGroup color_dialog_color_group_max_label1 = DLGCreateElement("Label")
				color_dialog_color_group_max_label1.TagGroupSetTagAsString( "Title","Max thickness for color display")
				color_dialog_color_group_max_label1.TagGroupSetTagAsString( "Side", "Left")
				color_dialog_color_group_max_label1.TagGroupSetTagAsNumber( "Width", MiscLabel3Width)
			color_dialog_color_group_max_items.DLGAddElement(color_dialog_color_group_max_label1)

			TagGroup color_dialog_color_group_max_field1 = DLGCreateElement("Field")
				color_dialog_color_group_max_field1.TagGroupSetTagAsNumber( "Value",MaxThicknessForColorDisplay)
				color_dialog_color_group_max_field1.TagGroupSetTagAsString( "Side", "Left")
				color_dialog_color_group_max_field1.TagGroupSetTagAsNumber( "Width", fieldWidth)
			color_dialog_color_group_max_items.DLGAddElement(color_dialog_color_group_max_field1)

			TagGroup color_dialog_color_group_max_label2 = DLGCreateElement("Label")
				color_dialog_color_group_max_label2.TagGroupSetTagAsString( "Title","nm")
				color_dialog_color_group_max_label2.TagGroupSetTagAsString( "Side", "Left")
				color_dialog_color_group_max_label2.TagGroupSetTagAsNumber( "Width", MiscLabelWidth)
			color_dialog_color_group_max_items.DLGAddElement(color_dialog_color_group_max_label2)

	TagGroup color_dialog_camera_group_items
	TagGroup color_dialog_camera_group = DLGCreateElementWithItems("Box",color_dialog_camera_group_items)
		color_dialog_camera_group.TagGroupSetTagAsString( "Side", "Top")
		color_dialog_camera_group.TagGroupSetTagAsString( "Title", "Camera")
		color_dialog_camera_group.TagGroupSetTagAsLongPoint( "ExternalPadding", 4, 2 )
	color_dialog_items.DLGAddElement(color_dialog_camera_group)

		TagGroup color_dialog_camera_group_exptime_items
		TagGroup color_dialog_camera_group_exptime = DLGCreateElementWithItems("Group",color_dialog_camera_group_exptime_items)
			color_dialog_camera_group_exptime.TagGroupSetTagAsString( "Side", "Top")
		color_dialog_camera_group_items.DLGAddElement(color_dialog_camera_group_exptime)

			TagGroup color_dialog_camera_group_exptime_label1 = DLGCreateElement("Label")
				color_dialog_camera_group_exptime_label1.TagGroupSetTagAsString( "Title","Exposure time")
				color_dialog_camera_group_exptime_label1.TagGroupSetTagAsString( "Side", "Left")
				color_dialog_camera_group_exptime_label1.TagGroupSetTagAsNumber( "Width", MiscLabel3Width)
			color_dialog_camera_group_exptime_items.DLGAddElement(color_dialog_camera_group_exptime_label1)

			TagGroup color_dialog_camera_group_exptime_field1 = DLGCreateElement("Field")
				color_dialog_camera_group_exptime_field1.TagGroupSetTagAsNumber( "Value",exposureTime)
				color_dialog_camera_group_exptime_field1.TagGroupSetTagAsString( "Side", "Left")
				color_dialog_camera_group_exptime_field1.TagGroupSetTagAsNumber( "Width", fieldWidth)
			color_dialog_camera_group_exptime_items.DLGAddElement(color_dialog_camera_group_exptime_field1)

			TagGroup color_dialog_camera_group_exptime_label2 = DLGCreateElement("Label")
				color_dialog_camera_group_exptime_label2.TagGroupSetTagAsString( "Title","s")
				color_dialog_camera_group_exptime_label2.TagGroupSetTagAsString( "Side", "Left")
				color_dialog_camera_group_exptime_label2.TagGroupSetTagAsNumber( "Width", MiscLabelWidth)
			color_dialog_camera_group_exptime_items.DLGAddElement(color_dialog_camera_group_exptime_label2)

		TagGroup color_dialog_camera_group_binning_items
		TagGroup color_dialog_camera_group_binning = DLGCreateElementWithItems("Group",color_dialog_camera_group_binning_items)
			color_dialog_camera_group_exptime.TagGroupSetTagAsString( "Side", "Top")
		color_dialog_camera_group_items.DLGAddElement(color_dialog_camera_group_binning)

			TagGroup color_dialog_camera_group_binning_label1 = DLGCreateElement("Label")
				color_dialog_camera_group_binning_label1.TagGroupSetTagAsString( "Title","Binning")
				color_dialog_camera_group_binning_label1.TagGroupSetTagAsString( "Side", "Left")
				color_dialog_camera_group_binning_label1.TagGroupSetTagAsNumber( "Width", MiscLabel3Width-1)
			color_dialog_camera_group_binning_items.DLGAddElement(color_dialog_camera_group_binning_label1)

			Taggroup first_camera_groupB_pu2_items
			TagGroup first_camera_groupB_pu2 = DLGCreateElementWithItems( "Popup",\
													first_camera_groupB_pu2_items )
				first_camera_groupB_pu2.TagGroupSetTagAsString( "Title", "Binning" )
				first_camera_groupB_pu2.TagGroupSetTagAsString( "Side", "Left")
					first_camera_groupB_pu2_items.DLGAddPopupItemEntry( "1" )
					first_camera_groupB_pu2_items.DLGAddPopupItemEntry( "2" )
					first_camera_groupB_pu2_items.DLGAddPopupItemEntry( "4" )
				first_camera_groupB_pu2.TagGroupSetTagAsNumber( "Value", BinningIndex )
			color_dialog_camera_group_binning_items.DLGAddElement( first_camera_groupB_pu2 )

			TagGroup color_dialog_camera_group_binning_label2 = DLGCreateElement("Label")
				color_dialog_camera_group_binning_label2.TagGroupSetTagAsString( "Side", "Left")
				color_dialog_camera_group_binning_label2.TagGroupSetTagAsNumber( "Width", MiscLabelWidth)
			color_dialog_camera_group_binning_items.DLGAddElement(color_dialog_camera_group_binning_label2)


Object color_dlg() {
	return alloc(uiframe).init(color_dialog)
}

// -- GRACE_color_setup() ---------------------------------------------------------
number GRACE_color_setup(void) {

	if ( !color_dlg().Pose() ) return 0
	else {
		// update tags
		color_dialog_color_group_min_field1.TagGroupGetTagAsNumber( "Value",MinThicknessForColorDisplay)
		SetPersistentNumberNote("User:Thickness:EFTEM:MinThicknessForColorDisplay",MinThicknessForColorDisplay)
		color_dialog_color_group_max_field1.TagGroupGetTagAsNumber( "Value",MaxThicknessForColorDisplay)
		SetPersistentNumberNote("User:Thickness:EFTEM:MaxThicknessForColorDisplay",MaxThicknessForColorDisplay)
		color_dialog_camera_group_exptime_field1.TagGroupGetTagAsNumber( "Value",exposureTime)
		SetPersistentNumberNote("User:Thickness:EFTEM:exposure Time",exposureTime)
		first_camera_groupB_pu2.TagGroupGetTagAsNumber( "Value", BinningIndex )
		SetPersistentNumberNote("User:Thickness:EFTEM:BinningIndex",BinningIndex)
		Binning = 2**(BinningIndex-1)
		SetPersistentNumberNote("User:Thickness:EFTEM:Binning",Binning)
		return 1
	}
}

if (ControlWasDown) {
	if (!GRACE_color_setup()) exit(1)
}

cam_mgr = CM_GetCameraManager()
camera = cm_GetCurrentCamera()				// get selected camera
// which camera? K2 or K3
CameraModel = CM_GetCameraIdentifier(camera)
CameraModel = left(CameraModel,2)
if (CameraModel == "K2") MaxCounts = 10		// sets default MaxCounts for K2
else MaxCounts = 1200						// sets default MaxCounts for K3: 1500/400*10*32
if (!GetPersistentNumberNote("User:Thickness:EFTEM:MaxCounts",MaxCounts))
	SetPersistentNumberNote("User:Thickness:EFTEM:MaxCounts",MaxCounts)

// get the parameter set defined in "Camera Acquire:Record"
acq_params = camera.cm_GetCameraAcquisitionParameterSet("Imaging", "Acquire", "Record", 0)
// modify some parameters as needed
if (CameraModel == "K2") {
	acq_params.cm_SetExposure(exposureTime)		
	acq_params.cm_SetProcessing(3)				// 1=Unprocessed, 2=DarkSubtracted, 3=GainNormalized
	acq_params.cm_SetReadMode(2)  				// 0=linear mode, 2=counting mode, 3=SuRes mode
	acq_params.cm_SetBinning(Binning, Binning)
}
if (CameraModel == "K3") {
	acq_params.cm_SetExposure(exposureTime)		
	acq_params.cm_SetProcessing(3)				// 1=Unprocessed, 2=DarkSubtracted, 3=GainNormalized
	acq_params.cm_SetReadMode(1)  				//  0=linear non-CDS, 1=counting non-CDS, 2=linear CDS, 3=counting CDS
	Binning *= 2
	acq_params.cm_SetBinning(Binning, Binning)
}

validation = CM_Validate_AcquisitionParameters( camera, acq_params )
if (!validation) {
	OKDialog("Camera parameters invalid")
	Exit(0)
}

// prepare camera
camID = CameraGetActiveCameraID( )
CameraPrepareForAcquire( camID )

// make sure the slit is out
if (IFGetslitIn()) IFSetSlitIn(0)

if ((EFTEMmode) && (!ForceALS) && (MagIndex < 17)) {	// if LM mode apply energy shift if it is > 0
//		result("MagIndex : " + MagIndex + "\n")
	GetPersistentNumberNote("User:Thickness:EFTEM:EnergyOffset:" + MagIndex,EnergyOffset)
	if (EnergyOffset) {
		OpenAndSetProgressWindow("  Setting","  Energy Offset...","")
		IFSetEnergyOffset(TechID,EnergyOffset)
		delay(EnergyOffsetDelay*60)
	}
	GetPersistentNumberNote("User:Thickness:EFTEM:ThicknessCorr:LM",ThicknessCorr)
//	result("ThicknessCorr : " + ThicknessCorr + "\n")
}
if ((EFTEMmode) && (!ForceALS) && (MagIndex > 16)) {	//M or SA
	GetPersistentNumberNote("User:Thickness:EFTEM:ThicknessCorr:M-SA",ThicknessCorr)
//	result("TicknessCorr : " + ThicknessCorr + "\n")
}
// record an unfiltered image
OpenAndSetProgressWindow("  Recording an","  Unfiltered image...","")
img := cm_AcquireImage(camera, acq_params)
if (Binning == 8) Reduce(img)		// for K3; averages pixel values (not adding them up)
//ShowImage(img)

// check number of counts per pixel.s; should be less than MaxCounts (def 10 for K2)
GetSize(Img,XSize,YSize)
MeanCounts = mean(Img[round(YSize*3/8),round(XSize*3/8),round(YSize*5/8),round(XSize*5/8)])/exposureTime/Binning/Binning
if (CameraModel == "K3") {
	if (Binning < 8) MeanCounts *= 4		// correct for binning relative to counting
	else MeanCounts *= 16
}

if (MeanCounts > MaxCounts) {
	OKDialog("Intensity too high.\nReduce to <" + MaxCounts + "counts/pix.s")
	If (EnergyOffset) {		// set EnergyOffset back to zero
		OpenAndSetProgressWindow("  Resetting","  Energy Offset...","")
		IFSetEnergyOffset(TechID,0)
		delay(EnergyOffsetDelay*60)
	}
	deleteImage(img)
	exit(0)
}

// median-filter unfiltered image
MedFilImg := MedianFilter(img, MedianFilterType, MedianFilterSize)

if ((EFTEMmode) && (!ForceALS)) {
	// slit in
	if (!IFGetslitIn()) IFSetSlitIn(1)
	// record filtered image
	OpenAndSetProgressWindow("  Recording a","  Filtered image...","")
	FilteredImg := cm_AcquireImage(camera, acq_params)
	If ((MagIndex < 17) && (EnergyOffset)) {		// set EnergyOffset back to zero
		OpenAndSetProgressWindow("  Resetting","  Energy Offset...","")
		IFSetEnergyOffset(TechID,0)
		delay(EnergyOffsetDelay*60)
	}
	if (Binning == 8) Reduce(FilteredImg)		// for K3; averages pixel values (not adding them up)
	// median-filter filtered image
	MedFilFilteredImg := MedianFilter(FilteredImg, MedianFilterType, MedianFilterSize)
	SetName(FilteredImg,"Orig FilteredImg")
	ShowImage( FilteredImg )
	GetSize(FilteredImg,XSize,YSize)
	CorrImg = ExprSize(XSize,YSize,0)
	CorrImg = tert(MedFilFilteredImg <=0,0.1,0)
	MedFilFilteredImg += CorrImg
	DisplayedImage := FilteredImg
	SetName(DisplayedImage,"FilteredImg")
	// calculate ratio image
	RatioImg := MedFilImg/MedFilFilteredImg
	SetName(RatioImg,"RatioImage")
//	ShowImage(RatioImg)
}
else {
	DisplayedImage := Img
	SetName(DisplayedImage,"UnFilteredImg")
}

//rotate images as specified
if (CameraRotation == 270) {
	RotateRight(DisplayedImage)
	if ((EFTEMmode) && (!ForceALS)) RotateRight(RatioImg)
	else RotateRight(MedFilImg)
}
if (CameraRotation == 90) {
	RotateLeft(DisplayedImage)
	if ((EFTEMmode) && (!ForceALS)) RotateLeft(RatioImg)
	else RotateLeft(MedFilImg)
}
if (CameraRotation == 180) {
//	result("OK1\n")
	RotateRight(DisplayedImage)
//	result("OK2\n")
	RotateRight(DisplayedImage)
	if ((EFTEMmode) && (!ForceALS)) {
//		result("OK3\n")
		RotateRight(RatioImg)
		RotateRight(RatioImg)
	}
	else {
		RotateRight(MedFilImg)
		RotateRight(MedFilImg)
	}
}

// if platform is Titan and mag is in SA range, correct for another 180 degr between LM and SA
if ((Platform) && (MagIndex >= 17)) {
	RotateRight(DisplayedImage)
	RotateRight(DisplayedImage)
	if ((EFTEMmode) && (!ForceALS)) {
		RotateRight(RatioImg)
		RotateRight(RatioImg)
	}
	else {
		RotateRight(MedFilImg)
		RotateRight(MedFilImg)
	}
}

ShowImage( DisplayedImage )
UpdateImage(DisplayedImage)
Zoom = GetZoom(DisplayedImage)

GetNumberNote(img, "Microscope Info:Indicated Magnification", theMag)
if ((EFTEMmode) && (!ForceALS)) result("MeasureThickness " + VersionNumber + "   Camera : " + CameraModel + "   Mag : " + theMag + "x   MagID : " + MagIndex + "    kV : " + kV + "   MFP : " + MeanFreePathInIce + " nm\n")
else result("MeasureThickness " + VersionNumber + "   Camera : " + CameraModel + "   Mag : " + theMag + "x   kV : " + kV + "   ALSfactor : " + ALSfactor + " nm" +\
				"    RefLocalIntensity : " + RefLocalIntensity + "\n")

MeasureRadius = Round(MeasureRadius/Binning*theMag/910)			// corrected for mag relative to 910 (default for Arctica)
// Maximise the measuring area to 1/4 of the image size
if (MeasureRadius > XSize/8) MeasureRadius = XSize/8
GetWindowPosition(DisplayedImage,XPosition, YPosition)
GetLimits(DisplayedImage,Minimum,Maximum)
Delta = Maximum - Minimum

NewPosition = 1	
// -- for different positions in the image ------------------------------------
while (NewPosition)
{
	KeyNumber = 0
	If (!ColorImgShown) OpenAndSetProgressWindow(" Click"," <T> for thickness"," <C> for color map")
	else OpenAndSetProgressWindow(" Click"," <T> for thickness",MinThicknessForColorDisplay+" - "+MaxThicknessForColorDisplay+" nm")
	NewPosition = _GetMouseCoords(DisplayedImage,CameraX,CameraY,KeyNumber)
	if ((KeyNumber >= 28) && (KeyNumber <= 31))	// adjust contrast and brightness
	{
		if (KeyNumber == 30)					// arrow up
		{
			Minimum = Minimum + 0.05*Delta
			Maximum = Maximum - 0.05*Delta
		}
		if (KeyNumber == 31)					// arrow down
		{
			Minimum = Minimum - 1/18*Delta
			Maximum = Maximum + 1/18*Delta
		}
		if (KeyNumber == 28)					// arrow left
		{
			Minimum = Minimum + 0.03*Delta
			Maximum = Maximum + 0.03*Delta
		}
		if (KeyNumber == 29)					// arrow right
		{
			Minimum = Minimum - 0.03*Delta
			Maximum = Maximum - 0.03*Delta
		}
		Delta = Maximum - Minimum
		if (ColorImgShown) {
			// update rgb image
			rgbimg = (DisplayedImage-Minimum )*256/(Maximum-Minimum )
			if ((EFTEMmode) && (!ForceALS)) {
				red(rgbimg) = tert((MeanFreePathInIce*log(RatioImg)-ThicknessCorr > MinThicknessForColorDisplay) &&\
								(MeanFreePathInIce*log(RatioImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
								red(rgbimg)*ColorFraction, red(rgbimg))
				if (!DisplayRed) {
					blue(rgbimg) = tert((MeanFreePathInIce*log(RatioImg)-ThicknessCorr > MinThicknessForColorDisplay) &&\
									(MeanFreePathInIce*log(RatioImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
									blue(rgbimg)*ColorFraction, blue(rgbimg))
				}
				else {
					blue(rgbimg) = tert((MeanFreePathInIce*log(RatioImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
									blue(rgbimg)*ColorFraction, blue(rgbimg))
					green(rgbimg) = tert((MeanFreePathInIce*log(RatioImg)-ThicknessCorr < MinThicknessForColorDisplay),\
									green(rgbimg)*ColorFraction, green(rgbimg))
				}
			}
			else {
				red(rgbimg) = tert((ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr > MinThicknessForColorDisplay) &&\
								(ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
								red(rgbimg)*ColorFraction, red(rgbimg))
				if (!DisplayRed) {
					blue(rgbimg) = tert((ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr > MinThicknessForColorDisplay) &&\
									(ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
									blue(rgbimg)*ColorFraction, blue(rgbimg))
				}
				else {
					blue(rgbimg) = tert((ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
									blue(rgbimg)*ColorFraction, blue(rgbimg))
					green(rgbimg) = tert((ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr < MinThicknessForColorDisplay),\
									green(rgbimg)*ColorFraction, green(rgbimg))
				}
			}
			updateimage(rgbimg)
			OpenAndSetProgressWindow(" Click"," <T> for thickness",MinThicknessForColorDisplay+" - "+MaxThicknessForColorDisplay+" nm")
		}
		SetSurvey(DisplayedImage,0)
		Setlimits(DisplayedImage,Minimum,Maximum)
		UpdateImage(DisplayedImage)
		KeyNumber = 0
		NewPosition = 1	
	}
	if ((KeyNumber == 48) && (NewPosition) && ((!EFTEMmode) || (ForceALS)))	// 0 (zero) = set local intensity in a hole
	{
		CameraX = CameraX/Zoom
		CameraY = CameraY/Zoom
		if ((CameraY-MeasureRadius <0) || (CameraX-MeasureRadius < 0) || (CameraY+MeasureRadius > YSize) || (CameraX+MeasureRadius > XSize)) {
			OKdialog("Choose a position further away from the image border")
			KeyNumber = 0
		}
		else {
			RefLocalIntensity = round(mean(Img[CameraY-MeasureRadius,CameraX-MeasureRadius,\
								CameraY+MeasureRadius,CameraX+MeasureRadius])*10)/10
			setselection(Img,CameraY-MeasureRadius,CameraX-MeasureRadius,CameraY+MeasureRadius,CameraX+MeasureRadius)
			OpenAndSetProgressWindow("","Ref Intensity : "+RefLocalIntensity+" counts","")
			result("RefLocalIntensity: "+RefLocalIntensity+ "\n")
			If (MagIndex < 17) {
				SetPersistentNumberNote("User:Thickness:TEM:" + kV + ":RefLocalIntensity:LM",RefLocalIntensity)		// set the tag to zero if it doesn't exist
			}
			else {
				SetPersistentNumberNote("User:Thickness:TEM:" + kV + ":RefLocalIntensity:SA",RefLocalIntensity)		// set the tag to zero if it doesn't exist
			}
		}
	}
	if (((KeyNumber == 84) || (KeyNumber == 116)) && (NewPosition))	// T = show local thickness
	{
		CameraX = CameraX/Zoom
		CameraY = CameraY/Zoom
		if ((CameraY-MeasureRadius <0) || (CameraX-MeasureRadius < 0) || (CameraY+MeasureRadius > YSize) || (CameraX+MeasureRadius > XSize)) {
			OKdialog("Choose a position further away from the image border")
			KeyNumber = 0
		}
		else {
			if ((EFTEMmode) && (!ForceALS)) { 
				LocalIntensity = mean(RatioImg[CameraY-MeasureRadius,CameraX-MeasureRadius,\
												CameraY+MeasureRadius,CameraX+MeasureRadius])
				LocalThickness = MeanFreePathInIce*log(LocalIntensity)-ThicknessCorr
			}
			else {
				if (RefLocalIntensity) {
					LocalIntensity = mean(Img[CameraY-MeasureRadius,CameraX-MeasureRadius,\
													CameraY+MeasureRadius,CameraX+MeasureRadius])
					LocalThickness = ALSfactor*log(RefLocalIntensity/LocalIntensity)-ThicknessCorr
				}
			}
			if (!ColorImgShown) SetSelection(DisplayedImage,CameraY-MeasureRadius,CameraX-MeasureRadius,CameraY+MeasureRadius,CameraX+MeasureRadius)
			else SetSelection(rgbimg,CameraY-MeasureRadius,CameraX-MeasureRadius,CameraY+MeasureRadius,CameraX+MeasureRadius)
			if (((!EFTEMmode) || (ForceALS)) && (!RefLocalIntensity)) {
				OKDialog("Reference intensity in a hole is not set!")
				result("Reference intensity in a hole is not set!\n")
			}
			else result("Thickness : "+format(LocalThickness,"%5.1f nm\n"))
		}
	}
	if ((KeyNumber == 80) || (KeyNumber == 112))	// P = get thickness limit parameters
	{
		NewPosition = 1
		OldBinningIndex = BinningIndex
		OldExposureTime = ExposureTime
		if (GRACE_color_setup()) {
			if (!((BinningIndex == OldBinningIndex) && (ExposureTime == OldExposureTime))) {
				OKDialog("You can only change camera setting at script startup(<Ctrl>)")
				BinningIndex = OldBinningIndex
				SetPersistentNumberNote("User:Thickness:EFTEM:BinningIndex",BinningIndex)
				first_camera_groupB_pu2.TagGroupSetTagAsNumber( "Value", BinningIndex )
				Binning = 2**(BinningIndex-1)
				SetPersistentNumberNote("User:Thickness:EFTEM:Binning",Binning)
				ExposureTime = OldExposureTime
				SetPersistentNumberNote("User:Thickness:EFTEM:exposure Time",exposureTime)
				color_dialog_camera_group_exptime_field1.TagGroupSetTagAsNumber( "Value",exposureTime)
			}
			if (ColorImgShown) {
				// update rgb image
				rgbimg = (DisplayedImage-Minimum )*256/(Maximum-Minimum )
				if ((EFTEMmode) && (!ForceALS)) {
					red(rgbimg) = tert((MeanFreePathInIce*log(RatioImg)-ThicknessCorr > MinThicknessForColorDisplay) &&\
									(MeanFreePathInIce*log(RatioImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
									red(rgbimg)*ColorFraction, red(rgbimg))
					if (!DisplayRed) {
						blue(rgbimg) = tert((MeanFreePathInIce*log(RatioImg)-ThicknessCorr > MinThicknessForColorDisplay) &&\
										(MeanFreePathInIce*log(RatioImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
										blue(rgbimg)*ColorFraction, blue(rgbimg))
					}
					else {
						blue(rgbimg) = tert((MeanFreePathInIce*log(RatioImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
										blue(rgbimg)*ColorFraction, blue(rgbimg))
						green(rgbimg) = tert((MeanFreePathInIce*log(RatioImg)-ThicknessCorr < MinThicknessForColorDisplay),\
										green(rgbimg)*ColorFraction, green(rgbimg))
					}
				}
				else {
					red(rgbimg) = tert((ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr > MinThicknessForColorDisplay) &&\
									(ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
									red(rgbimg)*ColorFraction, red(rgbimg))
					if (!DisplayRed) {
						blue(rgbimg) = tert((ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr > MinThicknessForColorDisplay) &&\
										(ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
										blue(rgbimg)*ColorFraction, blue(rgbimg))
					}
					else {
						blue(rgbimg) = tert((ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
										blue(rgbimg)*ColorFraction, blue(rgbimg))
						green(rgbimg) = tert((ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr < MinThicknessForColorDisplay),\
										green(rgbimg)*ColorFraction, green(rgbimg))
					}
				}
				updateimage(rgbimg)
				OpenAndSetProgressWindow(" Click"," <T> for thickness",MinThicknessForColorDisplay+" - "+MaxThicknessForColorDisplay+" nm")
			}
		}
	}
	if (((KeyNumber == 99) || (KeyNumber == 67)) && (!ColorImgShown))	// c or C = show color map
	{
		NewPosition = 1
		rgbimg = (DisplayedImage-Minimum )*256/(Maximum-Minimum )
		if ((EFTEMmode) && (!ForceALS)) {
			red(rgbimg) = tert((MeanFreePathInIce*log(RatioImg)-ThicknessCorr > MinThicknessForColorDisplay) &&\
							(MeanFreePathInIce*log(RatioImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
							red(rgbimg)*ColorFraction, red(rgbimg))
			if (!DisplayRed) {
				blue(rgbimg) = tert((MeanFreePathInIce*log(RatioImg)-ThicknessCorr > MinThicknessForColorDisplay) &&\
								(MeanFreePathInIce*log(RatioImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
								blue(rgbimg)*ColorFraction, blue(rgbimg))
			}
			else {
				blue(rgbimg) = tert((MeanFreePathInIce*log(RatioImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
								blue(rgbimg)*ColorFraction, blue(rgbimg))
				green(rgbimg) = tert((MeanFreePathInIce*log(RatioImg)-ThicknessCorr < MinThicknessForColorDisplay),\
								green(rgbimg)*ColorFraction, green(rgbimg))
			}
		}
		else {
			red(rgbimg) = tert((ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr > MinThicknessForColorDisplay) &&\
							(ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
							red(rgbimg)*ColorFraction, red(rgbimg))
			if (!DisplayRed) {
				blue(rgbimg) = tert((ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr > MinThicknessForColorDisplay) &&\
								(ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
								blue(rgbimg)*ColorFraction, blue(rgbimg))
			}
			else {
				blue(rgbimg) = tert((ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr < MaxThicknessForColorDisplay),\
								blue(rgbimg)*ColorFraction, blue(rgbimg))
				green(rgbimg) = tert((ALSfactor*log(RefLocalIntensity/MedFilImg)-ThicknessCorr < MinThicknessForColorDisplay),\
								green(rgbimg)*ColorFraction, green(rgbimg))
			}
		}
		OpenAndSetProgressWindow("  Optimal thickness","  between",\
								"  "+MinThicknessForColorDisplay+" and "+MaxThicknessForColorDisplay+" nm")
		SetName(rgbImg,"Color Thickness Map")
		SetZoom(rgbImg,zoom)
		DisplayAt(rgbImg,XPosition, YPosition)

		updateimage(rgbimg)
		ColorImgShown = 1
	}
	if (KeyNumber == 27) {
		DeleteImage(Img)
		DeleteImage(MedFilImg)
		OpenAndSetProgressWindow("","","")
		Result("------------------------------------------------------------------------------------------------\n")
		exit(1)
	}
}
DeleteImage(Img)
DeleteImage(MedFilImg)
OpenAndSetProgressWindow("","","")
Result("------------------------------------------------------------------------------------------------\n")

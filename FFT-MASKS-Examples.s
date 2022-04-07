// Example script which shows how use manually applied masks to carry out FFT filtering
// The foremost image should be a FFT with one or more masks applied. These can be spot, array, annular (bandpass) or wedge in any combination

// Implementation of the createmaskfromannotation() command is based on information supplied by Kazuo Ishizuka and Daniel Bank (thanks)

// D. R. G. Mitchell, drmnospam@ansto.gov.au (remove the nospam to get this to work)
// version:20071231, December 2007



// Get the frontmost image (FFT with one or more masks applied)

image front:=getfrontimage()
string imgname=getname(front)
imagedisplay imgdisp=front.imagegetimagedisplay(0)
setwindowposition(front, 142,24)

number xsize, ysize
getsize(front, xsize, ysize)


// Create the mask image and display it

// A mask image is created 5=width of the edge smoothing
// 0=mask is transparent, 'hasmask' a variable which returns true if
// there is a mask present on the selected image, 0 if not.

// Note this command will work with any combination of the various mask types present

number hasmask
compleximage mask=createmaskfromannotations(imgdisp, 5,0, hasmask)

// If no masks are applied to the selected FFT then hasmask=0

if(hasmask==0)
	{
		showalert("There are no masks applied to this FFT!",0)
		exit(0)
	}

setname(mask, "Mask")
showimage(mask)
setwindowposition(mask, 172, 54)


// Multiply the FFT by the mask

compleximage maskedfft=mask*front
converttopackedcomplex(maskedfft)


// Carry out the inverse FFT and display the filtered image

image invfft=packedifft(maskedfft)
setname(invfft,"IFFT of "+imgname)
showimage(invfft)
setwindowposition(invfft, 202, 84)


// Synthesise another FFT image to which to apply the masks present in the original image
// in reality you would select another FFT - eg for filtering a series of images

// Get the current foremost image which is the filtered inverse FFT we just created
// and do the FFT on it again to create another FFT

compleximage secondfft:=realfft(invfft)
converttopackedcomplex(secondfft)
showimage(secondfft)


// Get the image display of this FFT

imagedisplay secondfftdisp=secondfft.imagegetimagedisplay(0)
setname(secondfft, "Masked FFT of Filtered Image")
setwindowposition(secondfft, 232, 114)


// In the case of spot masks (type=8) they can be accessed as follows with the command 
	
// 	component spotmask=imgdisp.componentgetnthchildoftype(8,0)

// If there are more than one masks of a given type (spot=8 in this case) present
// Count them with :

//	number nomasks=imgdisp.componentcountchildrenoftype(8)

// and access them individually using the following command
//	componentgetnthchildrenoftype(8,i)
// where i is the mask number - 0, 1, 2, etc


// The section of code below (between the *******) would copy only those masks of type 8 (spot)
// It is commented out here and so does nothing

// The last section of code (between the &&&&&&&) copies all mask types
number i

/*
*********

for(i=0; i<nomasks; i++)
{

	// Spot masks are type 8, array mask=9, bandpass=15, wedge=19
	// The second number in the above command is the index, 0= frontmost compoenent

	component spotmask=imgdisp.componentgetnthchildoftype(8,i)
	component newmask=componentclone(spotmask,1)

	// Add it to the foremost FFT we just synthesised

	secondfftdisp.componentaddchildatend(newmask)
	newmask.componentsetselected(1) // select the masks to improve their visibility

}

*********
*/


// if other types of components of unknwown type are present - such as annular masks (type 15) a more generic method of copying them is required
// Components of unkown type can be accessed and copied as follows:


// Cound the total number of components in the image - note this includes non-mask components like scale bars, text, arrows etc.

// &&&&&&&

number nocomps=imgdisp.componentcountchildren()

result("\n\nComponent types present in the original image : \n\n")

// Loop through all the components getting their type number - if they are mask annotations copy them, otherwise they are ignored

for(i=0; i<nocomps; i++)
	{
		// Get the next component and its type

		component thiscomponent=imgdisp.componentgetchild(i)
		number comptype=thiscomponent.componentgettype()

		result("\n"+i+" Type = "+comptype)

		// As other annotations such as scale markers (type 31) will get picked up
		// it is necessary to filter when copying annotations, to avoid copying these

		if(comptype==8 || comptype==9 || comptype==15 || comptype==19) // this will select only the four types of mask component spot, array, bandpass, wedge
		{
			component masktocopy=componentclone(thiscomponent,1)
			secondfftdisp.componentaddchildatend(masktocopy)
			masktocopy.componentsetselected(1)
		}

		
}

// &&&&&&&


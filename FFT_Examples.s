// Some example functions which show how to do FFT/IFFT manipulations
// Please use/develop/expand and correct these examples at will.

// D. R. G. Mitchell, ANSTO Materials, drm@ansto.gov.au
// version 1.0, February 2007
// Thanks to Bernhard Schaffer and Kazuo Ishizuka for advice and assistance

// To use this script, have an image with periodic information in it foremost. Something like a HRTEM image will 
// do fine. The image must be square and have dimensions an integral power of 2 eg 512 x 512, 1024 x 1024 etc. 


// The script shows how to :

// Calculate the FFT of an image
// Calculate the inverse FFT of an FFT
// Create a Butterworth filter to use for high frequency filtering
// Apply the Butterworth filter to a FFT
// Carry out the inverse FFT of the above to show the effect of filtering
// Extract the real component of a complex image
// Extract the imaginary component of a complex image
// Compute the magnitude component of the FFT
// Compute the Phase component of the FFT - don't stare at it too long
// Compute the Power Spectrum of an image.



// Some functions:


// This function tests the passed in image to make sure it is the right data type, is square and is of dimension 2n x 2n

void testfftcompatibility(image frontimage)
	{
		number xsize, ysize, imagetype, modlog2value
		getsize(frontimage, xsize, ysize)

		// Get the datatype of the image
		imagetype=imagegetdatatype(frontimage)

		// Trap for complex or RGB images - these are not compatible with FFTing
		if(imagetype==3 ||imagetype==13 || imagetype==23) // 3=packed complex, 13=complex 16, 23=RGB
			{
				showalert("The foremost image must be of type Integer or Real!",0)
				exit(0)
			}

		// Checks to make sure that the image dimensions are an integral power of 2
		modlog2value=mod(log2(xsize), 1)

		if (xsize!=ysize || modlog2value!=0)
			{
				showalert("Image dimensions must be an integral power of 2 for FFT!",0)
				exit(0)
			}
}



// This function carried out the forward FFT. The function used (realFFT()) requires a real image
// so a clone of the passed in image is created and converted to a real image

image forwardfft(realimage frontimage)
	{

		// Get some info on the passed in image
		number xsize, ysize, imagetype
		string imgname=getname(frontimage)
		getsize(frontimage, xsize, ysize)

		// create a complex image of the correct size to store the result of the FFT
		compleximage fftimage=compleximage("",8,xsize, ysize)

		// Clone the passed in image and convert it to type real (required for realFFT())
		image tempimage=imageclone(frontimage)
		converttofloat(tempimage)
		fftimage=realfft(tempimage)	
		deleteimage(tempimage)

		return fftimage
	}



// The Butterworth Filter Function - this creates a filter which can be applied to a FFT
// to exclude the high frequency component - ie remove noise.

image butterworthfilter(number imgsize, number bworthorder, number zeroradius)
	{
		// See John Russ's Image Processing Handbook, 2nd Edn, p 316
		image butterworthimg=realimage("",4,imgsize, imgsize)
		butterworthimg=0

		// note the halfpointconst value sets the value of the filter at the halfway point
		// ie where the radius = zeroradius. A value of 0.414 sets this value to 0.5
		// a value of 1 sets this point to root(2)

		number halfpointconst=0.414
		butterworthimg=1/(1+halfpointconst*(iradius/zeroradius)**(2*bworthorder))
		return butterworthimg
	}



// Function to carry out image processing on the FFT and return the result
// The passed in images are the original HRTEM image and a Butterworth filter to remove the high frequency component
// Note if the Butterworth image is inverted then the low frequency component is filtered and the high frequencies are retained.
// Be aware if the central region of the FFT is removed by a mask, then weird things will happed to
// the resulting inverse image. It is better to leave a pinhole in the mask to allow the very lowest
// frequencies through. This pinhole should have a gradual edge to avoid ringing. An example of this is
// shown in my HRTEM Filter script on this database.

image FFTfiltering(image frontimage, image butterworthimg)
	{
		number xsize, ysize
		getsize(frontimage, xsize, ysize)
		
		// Compute the FFT of passed in image, then mulitply it by the Butterworth filter image
		compleximage fftimage=forwardfft(frontimage)
		compleximage maskedfft=fftimage*butterworthimg
		return maskedfft
	}




// Main program starts here


// Check to make sure an image is shown

number nodocs
nodocs=countdocumentwindowsoftype(5)
if(nodocs==0)
	{
		showalert("There are no images displayed!",0)
		exit(0)
	}


// Get the foremost image and some data from it

image front:=getfrontimage()
number xsize, ysize
getsize(front, xsize, ysize)


// Position the foremost image

setwindowposition(front, 142, 24)
updateimage(front)
string imgname=getname(front)


// Check to make sure the image is compatible with FFT

testfftcompatibility(front)


// Carry out the forward FFT

image fftimage=forwardfft(front)

// packed complex images are Hermitian - see DM help for details
// Creating packed complex FFTs enables use of the packedIFFT() function - see below
// which will return a real image from a FFT. Use of the IFFT() function returns a complex image
// and if used, the converttopackedcomplex() line below should be omitted.

converttopackedcomplex(fftimage)

setname(fftimage, "FFT of "+imgname)
showimage(fftimage)
setwindowposition(fftimage, 172,54)


// Do the inverse FFT - there is an alternative function - IFFT(). However,
// this requires a complex, rather than packed complex, image as its argument
// and returns the original image as a complex image rather than a real image.

image inversefftimg=packedIFFT(fftimage)
showimage(inversefftimg)
setname(inversefftimg, "Inverse FFT of "+imgname)
setwindowposition(inversefftimg, 202, 84)


// Carry out filtering by masking out parts of the FFT then doing the inverse
// In this case a Butterworth filter is used. This selects the low frequency
// part of the FFT and filters out the high frequency stuff - removing noise.
// The Butterworth filter, has a value of 1 in the central region, then rolls off to a value
// of zero near the edge of the FFT. Graduated filters like this are essential in FFT filtering
// If sharp cut offs are used, 'ringing' artefacts may appear in the inverse FFT. Changing the 
// values of Butterworth order (currently=3) and zero radius (currently = xsize/5) will change 
// the slope of the roll off and the radius at which the filter's value drops to half respectively.

image butterworthimage=butterworthfilter(xsize, 3, xsize/5)
showimage(butterworthimage)
setname(butterworthimage, "Butterworth Filter")
setwindowposition(butterworthimage, 232, 114)


// Apply the Butterworth filter image to the orignal front image
// and show the resulting masked FFT of the frontimage

compleximage maskimage=fftfiltering(front, butterworthimage)
converttopackedcomplex(maskimage)
showimage(maskimage)
setname(maskimage, "Butterworth Masked FFT of "+imgname)
setwindowposition(maskimage, 262, 144)


// Do the inverse FFT on the masked FFT to illustrate the effect of removing the high frequency component

image invfilteredimg=packedIFFT(maskimage)
showimage(invfilteredimg)
setname(invfilteredimg, "Butterworth Filtered "+imgname)
setwindowposition(invfilteredimg, 292, 174)


// FFTs are complex images containing a real and an imaginary part. FFTs contain two components - magnitude and phase.
// The magnitude component is usually displayed as a power spectrum. This shows the relative magnitudes of the frequencies
// contributing to the image. The FFT you see in Digital Micrograph is actually the absolute value of the magnitude. The code below
// shows how to access the real and imaginary parts of a complex image and compute the magnitude, phase and power spectrum
// Note the phase image does not impart any intuitive information - unless you are into psychedelic drugs.

// The magnitude of a FFT = sqt (real component**2 + imaginary component**2)
// The phase of a FFT  = atan2(real component / imaginary component)
// The Power Spectrum of a FFT = magnitude**2

// Extract and display the real part of the complex image (FFT)
image realimg=real(fftimage)
showimage(realimg)
setwindowposition(realimg, 322,204)
setname(realimg, "Real part of FFT of "+imgname)

// Extract and display the real part of the complex image (FFT)
image imagimg=imaginary(fftimage)
showimage(imagimg)
setwindowposition(imagimg, 352,234)
setname(imagimg, "Imaginary part of FFT of "+imgname)

// Compute the magnitude image
image magimg=sqrt(real(fftimage)**2+imaginary(fftimage)**2)
showimage(magimg)
setwindowposition(magimg, 382, 264)
setname(magimg, "Magnitude of FFT of "+imgname)

// Compute the phase image
image phaseimg=atan(real(fftimage)/imaginary(fftimage))
showimage (phaseimg)
setwindowposition(phaseimg, 412, 294)
setname(phaseimg, "Phase of FFT of "+imgname)

// Compute the Power Spectrum image
image psimg=magimg**2
showimage(psimg)
setwindowposition(psimg, 442, 324)
setname(psimg, "Power Spectrum of "+imgname)










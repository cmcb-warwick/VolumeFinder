/*
 * Calculate signal-to-noise ratio for 3View images using
 * Amira segmentation (segmented area = 2)
 */

macro "Calculate 3View SNR"	{
	if (nImages != 2) exit ("Exactly 2 images are required");
	imgArray = newArray(nImages);
	rowArray = newArray(nImages);
	nZArray = newArray(nImages);
	//print("\\Clear");
	for (i=0; i<nImages; i++)	{
		selectImage(i+1);
		imgArray[i] = getImageID();
		title = getTitle();
		rowArray[i] = title;
		nZArray[i] = nSlices;
	}
	if (nZArray[0] != nZArray[1]) exit ("Not the same size");
	numZ = nZArray[0];
	Dialog.create("Prepare for analysis"); 
	Dialog.addMessage("Which file is which?");
	Dialog.addChoice("am file", rowArray);
	Dialog.addChoice("3View TIFF", rowArray);
	Dialog.show();
	titleAm = Dialog.getChoice();
	title3View = Dialog.getChoice();
	// decisions collected
	setBatchMode(true);
	// threshold am
	selectWindow(titleAm);
	setAutoThreshold("Default dark");
	setThreshold(1, 2);
	setOption("BlackBackground", false);
	run("Convert to Mask", "method=Default background=Dark");
	// make large and medium version
		// duplicate
		run("Duplicate...", "title=med duplicate");
		// dilate
		selectWindow("med");
		run("Dilate", "stack");
		// duplicate that
		run("Duplicate...", "title=large duplicate");
		// dilate
		selectWindow("large");
		run("Dilate", "stack");
		// dilate again
		run("Dilate", "stack");
	// make diff version, kill duplicates
	imageCalculator("Subtract create stack", "large","med");
	// selectWindow("Result of large");
	selectWindow("large");
	close();
	selectWindow("med");
	close();
	// invert 3View
	selectWindow(title3View);
	run("Invert", "stack");
	run("Set Scale...", "distance=0");
	getDimensions(width, height, channels, slices, frames);
	area = width * height;
	// make tables to store data
	tableTitle="[SNR data]";
	if(isOpen("SNR data")) {
		print("Table is open");
	}
		else {
			run("Table...", "name="+tableTitle+" width=600 height=250");
			print(tableTitle, "\\Headings:Slice\tMean\tStdev\tSNR\tArea1\tArea2");
	}
	run("Set Measurements...", "area mean standard redirect=" + title3View + " decimal=3");
	// measure within original mask
	for (i=0; i<numZ; i++)	{
		selectWindow(titleAm);
		setSlice(i+1);
		run("Create Selection");
		run("Measure");
		meanVar = getResult("Mean");
		areaMeanVar = getResult("Area");
		selectWindow("Result of large");
		setSlice(i+1);
		run("Create Selection");
		run("Measure");
		stdevVar = getResult("StdDev");
		areaStdevVar = getResult("Area");
		SNRVar = meanVar / stdevVar;
		if ((areaMeanVar < 10 || areaMeanVar == area) || (areaStdevVar < 10 || areaStdevVar == area)) {
			meanVar = NaN;
			stdevVar = NaN;
			SNRVar = NaN;
		}
		print(tableTitle, (i) + "\t" + meanVar + "\t" + stdevVar + "\t" + SNRVar + "\t" + areaMeanVar + "\t" + areaStdevVar);
	}
	selectWindow(title3View);
	title = replace(title3View,".tif","");
	dir = getInfo("image.directory");
	run("Close All");
	wait(1000);
	call("java.lang.System.gc");
	wait(1000);
	selectWindow("SNR data");
	saveAs("Text", dir+title+"SNR.txt");
	
	setBatchMode(false);
}
	
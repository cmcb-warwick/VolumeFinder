/*/
 * This macro will convert a folder of *.am files into segmented TIFFs
 * *.am are Amira label files. The macro will segment labels =2.
 * Then will skeletonize and analyze a directory of TIFFs
 * Output is a 32-bit color coded TIFF of 1px thick filaments
 */
dir1 = getDirectory("Choose Amira Directory ");
list1 = getFileList(dir1);
dir2 = dir1 + "TIFF/";
File.makeDirectory(dir2);

setBatchMode(true);
for (i = 0; i < list1.length; i++)
    am2TIFFs(dir1, list1[i]);
setBatchMode(false);
 
function am2TIFFs(dir1, filename)
{ 
	st1 = "amirafile=" + dir1 + filename;
	run("Amira...", st1);
	setAutoThreshold("Default dark");
	setThreshold(1, 2);
	setOption("BlackBackground", false);
	run("Convert to Mask", "method=Default background=Dark");
	st2 = replace(filename,".Labels.am","/");
	dir3 = dir2 + st2;
	File.makeDirectory(dir3);
	run("Image Sequence... ", "format=TIFF save=" + dir3);
	close();

	list2 = getFileList(dir3);
	dir4 = dir1 + "skel/";
	File.makeDirectory(dir4);
	
	setBatchMode(true);
	for (i = 0; i < list2.length; i++)
    	TIFF2skel(dir3, list2[i]);
	setBatchMode(false);

}

function TIFF2skel(dir3, filename)
{ 
	open(dir3+filename);
	run("Skeletonize (2D/3D)");
	run("Analyze Skeleton (2D/3D)", "prune=[shortest branch] calculate show display");
	st3 = replace(filename,".tif","");
	newname = st3 + "-labeled-skeletons";
	selectWindow(newname);
	
    saveAs("Tiff", dir4 + newname);
    close();
}
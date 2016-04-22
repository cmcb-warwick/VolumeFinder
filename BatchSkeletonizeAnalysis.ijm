/*/
 * This macro will skeletonize and analyze a directory of TIFFs
 * Output is a 32-bit color coded TIFF of 1px thick filaments
 */
dir1 = getDirectory("Choose Destination Directory ");
dir2 = getDirectory("Choose Destination Directory ");
list = getFileList(dir1);
setBatchMode(true);
for (i = 0; i < list.length; i++)
    processFile(dir1, list[i]);
setBatchMode(false);
 
function processFile(dir1, filename)
{ 
	open(dir1+filename);
	run("Skeletonize (2D/3D)");
	run("Analyze Skeleton (2D/3D)", "prune=[shortest branch] calculate show display");
	str1 = replace(filename,".tif","");
	newname = str1 + "-labeled-skeletons";
	selectWindow(newname);
    saveAs("Tiff", dir2 + newname);
    close();
}
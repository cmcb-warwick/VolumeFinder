/*/
 * This macro will convert a folder of *.am files into segmented TIFFs
 * *.am are Amira label files. The macro will segment labels =2.
 */
dir1 = getDirectory("Choose Destination Directory ");
 
setBatchMode(true);
list = getFileList(dir1);
for (i = 0; i < list.length; i++)
    processFile(dir1, list[i]);
setBatchMode(false);
 
function processFile(dir1, filename)
{ 
	st1 = "amirafile=" + dir1 + filename;
	run("Amira...", st1);
	setAutoThreshold("Default dark");
	setThreshold(1, 2);
	setOption("BlackBackground", false);
	run("Convert to Mask", "method=Default background=Dark");
    saveAs("Tiff", dir1 + filename);
    close();
}
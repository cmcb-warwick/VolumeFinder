#pragma TextEncoding = "MacRoman"		// For details execute DisplayHelpTopic "The TextEncoding Pragma"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function MTs2Vectors()
	DoWindow/K allPlot
	Display /N=allPlot
	ProcessTIFFs()
End

Function ProcessTIFFs()
	
	String expDiskFolderName,expDataFileName
	String FileList, ThisFile, wName
	Variable FileLoop, nWaves, i
	
	NewPath/O/Q/M="Please find disk folder" ExpDiskFolder
	if (V_flag!=0)
		DoAlert 0, "Disk folder error"
		Return -1
	endif
	PathInfo /S ExpDiskFolder
	ExpDiskFolderName=S_path
	FileList=IndexedFile(expDiskFolder,-1,".tif")
	Variable nFiles=ItemsInList(FileList)
	Variable /G fileIndex
	
	for(FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile=StringFromList(FileLoop, FileList)
		expDataFileName=ReplaceString(".tif",ThisFile,"")	// get rid of .tif
		ImageLoad/O/T=tiff/Q/P=expDiskFolder/N=lImage ThisFile
		fileIndex = FileLoop
		Wave lImage
		Extractor(lImage)
		KillWaves /Z lImage // should be killed by Extractor()
	endfor
End

Function Extractor(m0)
	Wave m0
	
	tic()
	ImageStats m0
	NVAR /Z nZ = fileIndex	// global variable
	Variable lastMT = V_max
	String wName
	
	Variable i
	
	for(i = 1; i < (lastMT + 1); i += 1) // MT, 1-based
		Duplicate/O m0, tempXw
		Duplicate/O m0, tempYw
		tempXw = (m0 == i) ? p : NaN
		tempYw = (m0 == i) ? q : NaN
		Redimension/N=(V_npnts) tempXw,tempYw
		WaveTransform zapnans tempXw
		WaveTransform zapnans tempYw
		Print i, ":", numpnts(tempXw) // for debugging
		if(numpnts(tempXw) > 2)
			TheFitter(tempXw,tempYw,i)
		endif
	endfor
	
	KillWaves m0,tempXw,tempYw
	
	toc() // remove
End

////	@param	xW		this is the xWave for fitting
////	@param	yW		this is the yWave for fitting
////	@param	i		passing this variable rather than using another global variable
Function TheFitter(xW,yW,i)
	Wave xW
	Wave yW
	Variable i
	NVAR /Z nZ = fileIndex	// global variable
	
	CurveFit/Q/NTHR=0 line, yW /X=xW /D
	WAVE /Z fit_tempYw
	String wName = "vec_" + num2str(nZ) + "_" + num2str(i) // replace 3 with nZ
	Make/O/N=(2,2) $wName
	Wave m1 = $wName
	m1[0][0] = leftx(fit_tempYw)
	m1[1][0] = rightx(fit_tempYw)
	m1[0][1] = fit_tempYw[0]
	m1[1][1] = fit_tempYw[1]
	AppendToGraph/W=allPlot m1[][1] vs m1[][0]
End

Function tic()
	Variable/G tictoc = startMSTimer
End
 
Function toc()
	NVAR/Z tictoc
	Variable ttTime = stopMSTimer(tictoc)
	Printf "%g seconds\r", (ttTime/1e6)
	KillVariables/Z tictoc
End

//
//Need to deal with wave scaling

Function ScaleIt(xnm,ynm,znm)
	Variable xnm,ynm,znm
	//This will scale the points to real world values
	
	Variable scale=(xnm*ynm*znm)/1000000	//in µm^3
	//need to scale MTs in a different way
	//Works only for MTs 1px wide and not moving in z
	If(xnm !=ynm)
		Print "xnm and ynm are not equal. Please check"
	EndIf
	Variable MTscale=xnm*((PI*12.5)^2)
	
	Wave nPointWave,volWave
	nPointWave *=MTscale
	volWave *=scale
	Label /W=MTvol bottom, "Point Volume (µm\S3\M)"
	Label /W=spindlevol bottom, "Hull Volume (µm\S3\M)"	
End
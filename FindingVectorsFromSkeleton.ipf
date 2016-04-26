#pragma TextEncoding = "MacRoman"		// For details execute DisplayHelpTopic "The TextEncoding Pragma"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Menu item for easy execution
Menu "Macros"
	"MTs2Vectors...",  MTs2Vectors()
End

Function MTs2Vectors()
	Tic()
	ProcessTIFFs()
	DoWindow/F allPlot
	SetAxis/A/R left
	ModifyGraph width={Plan,1,bottom,left}
	Toc()
	Polarise()
End

Function ProcessTIFFs()
	
	// kill all windows and waves before we start
	String fullList = WinList("*", ";","WIN:3")
	String name
	Variable i
 
	for(i = 0; i < ItemsInList(fullList); i += 1)
		name = StringFromList(i, fullList)
		DoWindow/K $name		
	endfor
	KillWaves/A/Z
	
	Variable pxSize = 12
	Variable zSize = 60
	
	Prompt pxSize, "Pixel size, nm"
	Prompt zSize, "Section interval, nm"
	DoPrompt "Please check", pxSize, zSize
	Variable /G gpxSize = pxSize
	
	Variable sp1x = 0
	Variable sp1y = 0
	Variable sp1z = 0
	Variable sp2x = 0
	Variable sp2y = 0
	Variable sp2z = 0
	
	Prompt sp1x, "X1"
	Prompt sp1y, "Y1"
	Prompt sp1z, "Z1"
	Prompt sp2x, "X2"
	Prompt sp2y, "Y2"
	Prompt sp2z, "Z2"
	DoPrompt "Enter centrosome positions, px", sp1x,sp1y,sp1z, sp2x,sp2y,sp2z
	
	Make/O spWave={{sp1x,sp2x},{sp1y,sp2y},{sp1z,sp2z}}
	spWave[][0,1] *= pxSize
	spWave[][2] *= zSize
	
	DoWindow/K allPlot
	Display /N=allPlot
	
	String expDiskFolderName,expDataFileName
	String FileList, ThisFile
	Variable FileLoop
	
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
//		expDataFileName=ReplaceString(".tif",ThisFile,"")	// get rid of .tif
		ImageLoad/O/T=tiff/Q/P=expDiskFolder/N=lImage ThisFile
		fileIndex = FileLoop * zSize
		Wave lImage
		Extractor(lImage)
		KillWaves /Z lImage // should be killed by Extractor()
	endfor
End

////	@param	m0		lImage 2D wave(image)
Function Extractor(m0)
	Wave m0
	
	ImageStats m0
	NVAR /Z nZ = fileIndex	// global variable
	Variable lastMT = V_max
	String wName
	
	Variable i
	
	for(i = 1; i < (lastMT + 1); i += 1) // MT, 1-based
		Duplicate/O m0, tempXw
		Duplicate/O m0, tempYw
		tempXw = (m0[p][q] == i) ? p : NaN
		tempYw = (m0[p][q] == i) ? q : NaN
		Redimension/N=(V_npnts) tempXw,tempYw
		WaveTransform zapnans tempXw
		WaveTransform zapnans tempYw
		if(numpnts(tempXw) > 2)
			TheFitter(tempXw,tempYw,i)
		endif
	endfor
	KillWaves m0,tempXw,tempYw
End

////	@param	xW		this is the xWave for fitting
////	@param	yW		this is the yWave for fitting
////	@param	i		passing this variable rather than using another global variable
Function TheFitter(xW,yW,i)
	Wave xW
	Wave yW
	Variable i
	NVAR /Z nZ = fileIndex	// global variable
	NVAR /Z xySize = gpxSize
	
	CurveFit/Q/NTHR=0 line, yW /X=xW /D
	WAVE /Z fit_tempYw
	String wName = "vec_" + num2str(nZ) + "_" + num2str(i) // replace 3 with nZ
	Make/O/N=(2,2) $wName
	Wave m1 = $wName
	m1[0][0] = leftx(fit_tempYw) * xySize
	m1[1][0] = rightx(fit_tempYw) * xySize
	m1[0][1] = fit_tempYw[0] * xySize
	m1[1][1] = fit_tempYw[1] * xySize
	AppendToGraph/W=allPlot m1[][1] vs m1[][0]
	KillWaves fit_tempYw
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

Function Polarise()
	String VectorList = WaveList("vec_*",";","")
	Variable nVectors = ItemsInList(VectorList)
	// In vector wave, row 0 and 1 are xy coords for points A and B, pick Z from name
	// Spindle poles are 1 and 2
	WAVE spWave
	Variable sp1x = spWave[0][0]
	Variable sp1y = spWave[0][1]
	Variable sp1z = spWave[0][2]
	Variable sp2x = spWave[1][0]
	Variable sp2y = spWave[1][1]
	Variable sp2z = spWave[1][2]
	Variable sp1_A,sp1_B,sp2_A,sp2_B
	Variable ABx, CDx, ABy, CDy
	String wName,expr,zPos,vNo
	Variable vZ,nearest
	Make/O/N=(nVectors)/T pol_Name	// name of vector wave
	Make/O/N=(nVectors) pol_Des	// which spindle pole is it from
	Make/O/N=(nVectors) pol_Rev	// did the polarity get reversed?
	Make/O/N=(nVectors) pol_Angle // what is the angle releative to the spindle axis?
	
	Variable i
	
	for(i = 0; i < nVectors; i += 1)
		wName = StringFromList(i,VectorList)
		Wave w0 = $wName
		pol_Name[i] = wName
		expr="vec\\w([[:digit:]]+)\\w([[:digit:]]+)"
		SplitString/E=(expr) wName, zPos, vNo
		vZ = str2num(zPos)
		sp1_A = sqrt((w0[0][0] - sp1X)^2 + (w0[0][1] - sp1Y)^2 + (vZ - sp1Z)^2)
		sp1_B = sqrt((w0[1][0] - sp1X)^2 + (w0[1][1] - sp1Y)^2 + (vZ - sp1Z)^2)
		sp2_A = sqrt((w0[0][0] - sp2X)^2 + (w0[0][1] - sp2Y)^2 + (vZ - sp2Z)^2)
		sp2_B = sqrt((w0[1][0] - sp2X)^2 + (w0[1][1] - sp2Y)^2 + (vZ - sp2Z)^2)
		nearest = min(sp1_A,sp1_B,sp2_A,sp2_B)
		if(nearest == sp1_A || nearest == sp1_B)
			pol_Des[i] = 1
			if(sp1_A >= sp1_B)
				Reverse/DIM=0 w0
				pol_Rev[i] = 1
			else
				pol_Rev[i] = 0
			endif
			// line AB is between spindle poles
			// line CD is the MT vector
			ABx=sp2X - sp1X
			CDx=w0[1][0] - w0[0][0]
			ABy=sp2Y - sp1Y
			CDy=w0[1][1] - w0[0][1]
//			pol_Angle[i] = acos(((ABx*CDx)+(ABy*CDy)) / (sqrt((ABx^2)+(ABy^2)) * sqrt((CDx^2) + (CDy^2)))) * (180/pi)
			pol_Angle[i] = (atan2(ABy,ABx) - atan2(CDy,CDx)) * (180/pi)
		else
			pol_Des[i] = 2
			if(sp2_A >= sp2_B)
				Reverse/DIM=0 w0
				pol_Rev[i] = 1
			else
				pol_Rev[i] = 0
			endif
			ABx=sp1X - sp2X
			CDx=w0[1][0] - w0[0][0]
			ABy=sp1Y - sp2Y
			CDy=w0[1][1] - w0[0][1]
//			pol_Angle[i] = acos(((ABx*CDx)+(ABy*CDy)) / (sqrt((ABx^2)+(ABy^2)) * sqrt((CDx^2) + (CDy^2)))) * (180/pi)
			pol_Angle[i] = (atan2(ABy,ABx) - atan2(CDy,CDx)) * (180/pi)
		endif
		if(pol_Angle[i] <= 90)
			ModifyGraph/W=allPlot rgb($wName)=(32767,65535-(65535 * (pol_Angle[i]/90)),32767)
		else
			ModifyGraph/W=allPlot rgb($wName)=(32767,65535-(65535 * ((180-pol_Angle[i])/90)),32767)
		endif
	endfor
End
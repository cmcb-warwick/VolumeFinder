#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function AllAnalysis()
	AngleLoader()
	ProcessWaves()
End

//This function loads all the the waves from different Igor pxps in a directory
Function AngleLoader()
	
	NewDataFolder/O/S root:data
	
	String expDiskFolderName,expDataFolderName
	String FileList, ThisFile, wList, ExcList, wName
	Variable FileLoop, nWaves, i
	 
	NewPath/O/Q/M="Please find disk folder" ExpDiskFolder
	if (V_flag!=0)
		DoAlert 0, "Disk folder error"
		Return -1
	endif
	PathInfo /S ExpDiskFolder
	ExpDiskFolderName=S_path
	FileList=IndexedFile(expDiskFolder,-1,".pxp")
	Variable nFiles=ItemsInList(FileList)
	
	for (FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile=StringFromList(FileLoop, FileList)
		expDataFolderName=ReplaceString(".pxp",ThisFile,"")	//get rid of .pxp
		LoadData /L=1/O/P=expDiskFolder/T=$expDataFolderName ThisFile
		SetDataFolder $expDataFolderName
		wList = WaveList("*",";","")
		excList = WaveList("pol*",";","") + WaveList("seg*",";","") + WaveList("e_*",";","")
		wList = RemoveFromList(excList,wList)
		nWaves = ItemsInList(wList)
		for (i = 0; i < nWaves; i += 1)
			wName = StringFromList(i,wList)
			KillWaves $wName
		endfor
		SetDataFolder root:data:
	endfor
End

Function ProcessWaves()
	SetDataFolder root:data:
	DFREF dfr = GetDataFolderDFR()
	String folderName, wName, graphName
	Variable numDataFolders = CountObjectsDFR(dfr, 4)
	Make/O/T/N=(numDataFolders) fileNameWave
	Make/O/N=(numDataFolders) medianWave,meanWave,sdWave
	DoWindow /K histSLayout
	NewLayout /N=histSLayout
	DoWindow /K histELayout
	NewLayout /N=histELayout
	
	Variable i
		
	for(i = 0; i < numDataFolders; i += 1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		fileNameWave[i] = folderName
		wName = ":" + folderName + ":e_AngleWave"
		Wave w0 = $wName
		medianWave[i] = median(w0)
		Wavestats/Q w0
		meanWave[i] = V_avg
		sdWave[i] = V_sdev
		
		wName = ":" + folderName + ":seg_angle_pos_hist"
		graphName = folderName + "_S_plot"
		DoWindow/K $graphName
		Display/N=$graphName $wName
		Label bottom "Angle (¡)"
		Label left "Frequency"
		TextBox/C/N=text0/F=0/X=0.00/Y=0.00 folderName
		SetAxis bottom 0,180
		ModifyGraph mode=7
		ModifyGraph hbFill=4
		ModifyGraph rgb=(32768,32770,65535)
		AppendLayoutObject /W=histSLayout graph $graphName
		
		wName = ":" + folderName + ":e_angleWave_Hist"
		graphName = folderName + "_E_plot"
		DoWindow/K $graphName
		Display/N=$graphName $wName
		Label bottom "Angle (¡)"
		Label left "Frequency"
		TextBox/C/N=text0/F=0/X=0.00/Y=0.00 folderName
		SetAxis bottom 0,180
		ModifyGraph mode=7
		ModifyGraph hbFill=4
		ModifyGraph rgb=(65535,43688,32768)
		AppendLayoutObject /W=histELayout graph $graphName
	endfor
	
	//There are 4 windows so...
	Variable nRow = 2
	Variable nCol = 2
	
	Variable lIndent = 50
	Variable	tIndent = 50
	Variable winWidth = 395
	Variable winHeight = 208
	Variable lArea = lIndent
	Variable tArea = tIndent
	Variable rArea = lIndent + winWidth
	Variable bArea = tIndent + winHeight
	
	DoWindow/K summaryTable
	Edit/N=summaryTable/W=(lArea,tArea,rArea,bArea) fileNameWave,medianWave,meanWave,sdWave
	
	lArea = lIndent
	tArea = tIndent + winHeight + 23
	rArea = lArea + winWidth
	bArea = tArea + winHeight
	DoWindow/K meanPlot
	Display/N=meanPlot/W=(lArea,tArea,rArea,bArea) meanWave vs fileNameWave
	ModifyGraph swapXY=1
	SetAxis/A/N=1/E=1 bottom
	SetAxis/A/R left
	ModifyGraph rgb=(65535,43688,32768)
	Label bottom "Mean Angle (¡)"
	
	lArea = lIndent + winWidth + 1
	tArea = tIndent
	rArea = lArea + winWidth
	bArea = tArea + winHeight
	DoWindow/K sdPlot
	Display/N=sdPlot/W=(lArea,tArea,rArea,bArea) sdWave vs fileNameWave
	ModifyGraph swapXY=1
	SetAxis/A/N=1/E=1 bottom
	SetAxis/A/R left
	ModifyGraph rgb=(65535,43688,32768)
	Label bottom "Standard deviation (¡)"
	
	lArea = lArea
	tArea = tIndent + winHeight + 23
	rArea = lArea + winWidth
	bArea = tArea + winHeight
	DoWindow/K medianPlot
	Display/N=medianPlot/W=(lArea,tArea,rArea,bArea) medianWave vs fileNameWave
	ModifyGraph swapXY=1
	SetAxis/A/N=1/E=1 bottom
	SetAxis/A/R left
	ModifyGraph rgb=(65535,43688,32768)
	Label bottom "Median Angle (¡)"
	//Default Igor Window is 395 x 208 and sits at 35,45,430,253, title bar is 22
	
	DoWindow /K summaryLayout
	NewLayout /N=summaryLayout
	AppendLayoutObject /W=summaryLayout graph meanPlot
	AppendLayoutObject /W=summaryLayout graph sdPlot
	AppendLayoutObject /W=summaryLayout graph medianPlot
	// Tidy report
	DoWindow /F summaryLayout
	// in case these are not captured as prefs
#if igorversion()>=7
	LayoutPageAction size(-1)=(595, 842), margins(-1)=(18, 18, 18, 18)
#endif
	ModifyLayout units=0
	ModifyLayout frame=0,trans=1
	Execute /Q "Tile/A=(4,2) meanPlot,sdPlot,medianPlot"
	SavePICT/E=-2 as "report.pdf"
	// Tidy other report
	DoWindow /F histSLayout
	// in case these are not captured as prefs
#if igorversion()>=7
	LayoutPageAction size(-1)=(595, 842), margins(-1)=(18, 18, 18, 18)
#endif
	ModifyLayout units=0
	ModifyLayout frame=0,trans=1
	Execute /Q "Tile"
	SavePICT/E=-2 as "histS.pdf"
	
	// Tidy other report
	DoWindow /F histELayout
	// in case these are not captured as prefs
#if igorversion()>=7
	LayoutPageAction size(-1)=(595, 842), margins(-1)=(18, 18, 18, 18)
#endif
	ModifyLayout units=0
	ModifyLayout frame=0,trans=1
	Execute /Q "Tile"
	SavePICT/E=-2 as "histE.pdf"
	
	SetDataFolder root:
End

// To run this, designate which folders belong to which condition
// make desigWave with the same number of points as fileNameWave
// assign a value to each condition
// make condWave where the row number equals the condition name
Function MakeComparison()
	SetDataFolder root:data
	WAVE/T/Z fileNameWave
	if(!WaveExists(fileNameWave))
		abort "You need to run AllAnalysis() first"
	endif
	WAVE/Z desigWave
	WAVE/Z/T condWave
	if(!WaveExists(desigWave))
		abort "Make desigWave and/or condWave"
	endif
	
	Variable nFolders = numpnts(fileNameWave)
	Variable desigMax = wavemax(desigWave) + 1 // desigWave is 0-based
	String containerName, wName, condName
	Variable i,j
	
	for(i = 0; i < desigMax; i += 1)
		containerName = condWave[i] + "_angleWave"
		Make/O $containerName
		Wave w1 = $containerName

		for(j = 0; j < nFolders; j += 1)
			if(desigwave[j] == i)
				wName = ":" + fileNameWave[j] + ":e_angleWave"
				Wave w0 = $wName
				Concatenate/NP=0 {w0}, w1
			endif
		endfor
	endfor
	CompareAlphaAll()
	SetDataFolder root:
End

Function CompareAlphaAll()
	String wList = WaveList("*angleWave",";","")
	Variable nWaves = ItemsInList(wList)
	String w0Name,w1Name
	Make/O/N=(nWaves,nWaves) resultMat
	Make/O/N=(nWaves) labelPos=p
	Make/O/N=(nWaves)/T labelWave
	Variable i,j
	
	for(i = 0; i < nWaves; i += 1)
		w0Name = StringFromList(i,wList)
		Wave w0 = $w0Name
		labelWave[i] = ReplaceString("_AngleWave",w0Name,"")
		for(j = 0; j < nWaves; j += 1)
			if(i == j)
				resultMat[i][j] = 0
			else
				w1Name = StringFromList(j,wList)
				Wave w1 = $w1Name
				resultMat[i][j] = CompareAlpha(w0,w1)
			endif
		endfor
	endfor
	KillWindow/Z result
	NewImage/N=result resultMat
	ModifyImage/W=result resultMat ctab= {0.0001,1,RedWhiteBlue,0},minRGB=(52428,52428,52428),maxRGB=0
	ModifyGraph/W=result userticks(left)={labelpos,labelWave}
	ModifyGraph/W=result userticks(top)={labelpos,labelWave}
	ModifyGraph/W=result tick=3,tkLblRot(left)=0,tkLblRot(top)=90,tlOffset=0
	ModifyGraph/W=result margin(left)=42,margin(top)=42
	
	String textName,labelValStr
	Duplicate/O resultMat,labelVal
	Variable matsize = numpnts(resultMat)
	Redimension/N=(matsize) labelVal
	DoWindow/F result
	
	for(i = 0; i < matsize; i += 1)
		if(labelVal[i] != 0)
			textName = "text" + num2str(i)
			labelValStr = num2str(Rounder(labelVal[i],2))
			Tag/C/N=$textName/F=0/B=1/X=0.00/Y=0.00/L=0 resultMat, i, labelValStr
		endif
	endfor
End

//// @param	w0c	wave containing angle differences from ideal distribution (may have NaNs)
//// @param	w1c	wave containing angle differences from ideal distribution (may have NaNs)
Function CompareAlpha(w0c,w1c)
	Wave w0c,w1c
	
	Duplicate/O w0c, w0
	Duplicate/O w1c, w1
	WaveTransform zapnans w0
	WaveTransform zapnans w1
	
	Variable tempvar = 0
	FindDuplicates/RN=w0ue/TOL=0.0001 w0
	Variable nAngles = numpnts(w0ue)
	
	Variable i
	
	for(i = 0; i < nAngles; i += 1)
		Extract/FREE/O w0,w2,w0 > (w0ue[i] - 0.0001) && w0 < (w0ue[i] + 0.0001)
		Extract/FREE/O w1,w3,w1 > (w0ue[i] + 0.0001)
		tempvar += numpnts(w2) * numpnts(w3)
	endfor
	tempvar /= (numpnts(w0) * numpnts(w1))
//	Print tempvar
	KillWaves w0ue,w0,w1
	return tempvar
End

////	@param	value				this is the input value that requires rounding
////	@param	numSigDigits		number of significant digits for the rounding procedure
Function Rounder(value, numSigDigits)
	Variable value, numSigDigits
 
	String str
	Sprintf str, "%.*g\r", numSigDigits, value
	return str2num(str)
End
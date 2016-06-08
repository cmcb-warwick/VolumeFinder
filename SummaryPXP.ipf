#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
////	@param	cammandVar	command variable. Set to 1 to get rid of vec waves etc
Function AllAnalysis(cVar)
	Variable cVar
	AngleLoader(cVar)
	ProcessWaves()
End


//This function loads all the the waves from different Igor pxps in a directory
////	@param	cammandVar	command variable. Set to 1 to get rid of vec waves etc
Function AngleLoader(cVar)
	Variable cVar
	
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
		if(cVar == 1)	// get rid of excess waves
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
		endif
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
		wName = ":" + folderName + ":segAngleWave_all_pos"
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
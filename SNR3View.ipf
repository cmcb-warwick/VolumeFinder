#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu "Macros"
	"Load SNR txt files",  SNRLoadAndDisplay()
End

Function SNRLoadAndDisplay()
	SNRTXTLoader()
	DisplaySNRsForAll()
End

Function SNRTXTLoader()
	
	NewDataFolder/O/S root:data
	
	String expDiskFolderName, expDataFolderName
	String FileList, ThisFile, wavenames, wName, MTwave, wList
	Variable FileLoop, nWaves, i
	 
	NewPath/O/Q/M="Please find disk folder" ExpDiskFolder
	if (V_flag!=0)
		DoAlert 0, "Disk folder error"
		Return -1
	endif
	PathInfo /S ExpDiskFolder
	ExpDiskFolderName=S_path
	FileList = IndexedFile(expDiskFolder,-1,".txt")
	Variable nFiles = ItemsInList(FileList)
	
	for (FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile = StringFromList(FileLoop, FileList)
		expDataFolderName = ReplaceString("SNR.txt",ThisFile,"")	// get rid of SNR.txt
		NewDataFolder/O/S $expDataFolderName
		LoadWave/A/J/D/O/K=1/W/L={0,1,0,1,0}/P=expDiskFolder ThisFile
		SetDataFolder root:data:
	endfor
End

Function DisplaySNRsForAll()
	SetDataFolder root:data:	// relies on earlier load
	DFREF dfr = GetDataFolderDFR()
	String folderName, wName, newName, plotName
	String wList = ""
	Variable numDataFolders = CountObjectsDFR(dfr, 4)
	DoWindow/K allPlot
	Display/N=allPlot
	
	Variable i
		
	for(i = 0; i < numDataFolders; i += 1)
		folderName = GetIndexedObjNameDFR(dfr, 4, i)
		wName = ":" + folderName + ":SNR"
		newName = wName + "wave"
		wList += newName + ";"
		Duplicate/O $wName $newName
		Wave/Z w = $newName
		WaveTransform zapnans w
		plotName = folderName + "_plot"
		DoWindow/K $plotName
		Display/N=$plotName/HIDE=1 w
		if(numpnts(w) > 0)
			AppendToGraph/W=allPlot w
		endif
	endfor
	Print wlist
	Concatenate/O wList, allSNRwave
	SetDataFolder root:
End
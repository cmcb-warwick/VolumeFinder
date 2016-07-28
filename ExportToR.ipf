#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//This function loads all the the waves from different Igor pxps in a directory
Function LoadAndExportToR()
	
	NewDataFolder/O/S root:data
	
	String expDiskFolderName,expDataFolderName
	String FileList, ThisFile, wList, killList, wName, exportFileName
	Variable FileLoop, nWaves, i
	 
	NewPath/O/Q/M="Please find disk folder" ExpDiskFolder
	if (V_flag!=0)
		DoAlert 0, "Disk folder error"
		Return -1
	endif
	PathInfo /S ExpDiskFolder
	ExpDiskFolderName = S_path
	FileList = IndexedFile(expDiskFolder,-1,".pxp")
	Variable nFiles = ItemsInList(FileList)
	
	for (FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile = StringFromList(FileLoop, FileList)
		expDataFolderName = ReplaceString(".pxp",ThisFile,"")	//get rid of .pxp
		LoadData /L=1/O/P=expDiskFolder/T=$expDataFolderName ThisFile
		//
		SetDataFolder $expDataFolderName
		wList = WaveList("vec_*",";","")
		nWaves = ItemsInList(wList)
		Make/O/N=(nWaves,6) exportWave
		Make/O/T/N=(nWaves) exportLabel
		
		for (i = 0; i < nWaves; i += 1)
			wName = StringFromList(i,wList)
			Wave w0 = $wName
			exportWave[i][0,2] = w0[0][q]
			exportWave[i][3,5] = w0[1][q-3]
			exportLabel[i] = wName
		endfor
		// Get rid of excess waves
		killList = RemoveFromList("exportWave;exportLabel",WaveList("*",",",""))
		KillWaves/Z killList
		// now save as csv
		exportFileName = expDataFolderName + ".txt"
		Save/J/M="\n"/DLIM=","/O/P=expDiskFolder exportWave as exportFileName
		exportFileName = expDataFolderName + "_labels.txt"
		Save/J/M="\n"/DLIM=","/O/P=expDiskFolder exportLabel as exportFileName
		SetDataFolder root:data:
	endfor
	SetDataFolder root:
End
#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
Function ProcessAll()
	DataLoader()
	AxisChecker()
End

//This function loads all the the waves from different Igor pxps in a directory
Function DataLoader()
	
	// make a wave to colour the p1,c and p2 points (r, g and b)
	Make/O/N=(3,4) colorwave=0
	colorwave[][3] = 1
	colorwave[0][0] = 1
	colorwave[1][1] = 1
	colorwave[2][2] = 1
	
	NewDataFolder/O/S root:data
	
	String expDiskFolderName,expDataFolderName
	String FileList, ThisFile, wList, killList, wName
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
		//
		SetDataFolder $expDataFolderName
		wList=WaveList("vec_*",";","")
		nWaves=ItemsInList(wList)
		Make/FREE/N=(1,3) gapw=NaN
		for (i = 0; i < nWaves; i += 1)
			wName = StringFromList(i,wList)
			Wave w0 = $wName
			Concatenate/NP=0 {gapw}, $wName	// add gap row
		endfor
		Concatenate/O/NP=0/KILL wList, ThreeDVecWave
		// Get rid of excess waves
		killList = waveList("vec_*",",","") + WaveList("elli_*",",","")
		KillWaves/Z killList
		// Now make *_ax wave
		wName = "root:" + expDataFolderName + "_ax"
		Make/O/N=(3,3) $wName
		Wave w0 = $wName
		WAVE/Z spWave
		MatrixOp/O/FREE cWave = sumCols(spWave)
		cWave /= 2
		w0[0][] = spwave[0][q]
		w0[1][] = cWave[0][q]
		w0[2][] = spwave[1][q]
		wName = ReplaceString("_ax", wName, "_bx")
		Duplicate/O w0, $wName
		// now plot out in 3D
		GizPlotter(expDataFolderName)
		SetDataFolder root:data:
	endfor
End

//// @param	folderName	this is a string containing the folder in data:
Function GizPlotter(folderName)
	String folderName
	if(igorversion()<7)
		Print "Igor 7 is needed"
		Return 0
	endif
	WAVE/Z ThreeDVecWave
	Wave colorwave = root:colorwave
	String wName = "root:" + folderName + "_ax"
	Wave w0 = $wName
	wName = ReplaceString("_ax", wName, "_bx")
	Wave w1 = $wName
	// wsize of new gizmo is 35,45,550,505, so 1.8 times is
	NewGizmo/N=$folderName/W=(35,45,962,873)
	AppendToGizmo path=ThreeDVecWave,name=mts
	ModifyGizmo modifyObject=mts, objectType=path, property={pathcolor,0,0,0,1}
	ModifyGizmo setDisplayList=0,object=mts
	AppendToGizmo path=w0,name=spax
	ModifyGizmo modifyObject=spax, objectType=path, property={pathcolor,1,0,0,1}
	ModifyGizmo setDisplayList=1,object=spax
	AppendToGizmo scatter=w0,name=spspots
	ModifyGizmo modifyObject=spspots, objectType=scatter, property={colorWave,colorwave}
	ModifyGizmo modifyObject=spspots, objectType=scatter, property={ scatterColorType,1}
	ModifyGizmo ModifyObject=spspots,objectType=scatter,property={ size,0.3}
	ModifyGizmo setDisplayList=2,object=spspots
	// Append the second "bx" wave
	AppendToGizmo path=w1,name=spbx
	ModifyGizmo modifyObject=spbx, objectType=path, property={pathcolor,0.5,0.5,0.5,1}
	ModifyGizmo setDisplayList=3,object=spbx
	AppendToGizmo scatter=w1,name=sbspots
	ModifyGizmo modifyObject=sbspots, objectType=scatter, property={colorWave,colorwave}
	ModifyGizmo modifyObject=sbspots, objectType=scatter, property={ scatterColorType,1}
	ModifyGizmo ModifyObject=sbspots,objectType=scatter,property={ size,0.2}
	ModifyGizmo setDisplayList=4,object=sbspots
End

Function AxisChecker()
	// User interaction to check spindle axis
End

// This function makes P2, given points P1 and C.
Function FindP2()
	SetDataFolder root:
	String wName = StringFromList(0,WaveList("*",";","WIN:"))
	Wave w0 = $wName
	w0[2][] = w0[1][q] + (w0[1][q] - w0[0][q])
End

// This is used to export the waves for use by FindingVectorsFromSkeleton.ipf
Function GetBx()
	SetDataFolder root:
	String wList = WaveList("*_bx",";","")
	String wName
	Variable nWaves = ItemsInList(wList)
	Make/O/N=(nWaves)/T labelWave
	Make/O/N=(nWaves,3) r_p1Wave,r_cWave,r_p2Wave
	
	Variable i
	
	for(i = 0; i < nWaves; i += 1)
		wName = StringFromList(i,wList)
		Wave w0 = $wName
		Duplicate/O w0, w1
		w1[][0,1] /=12	// rescale to pixels
		w1[][2] /=60
		wName = ReplaceString("_bx",wName,"")
		labelWave[i] = wName
		r_p1Wave[i][] = w1[0][q]
		r_cWave[i][] = w1[1][q]
		r_p2wave[i][] = w1[2][q]
	endfor
	KillWaves w1
	Save/C labelWave,r_p1Wave,r_cWave,r_p2Wave
End

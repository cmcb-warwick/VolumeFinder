#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
Function ProcessAll()
	FindC()
	DataLoader()
//	Execute "TileWindows/O=65536/W=(10,30,1000,830)"
End

Function FindC()
	WAVE/Z p1x,p1y,p1z,p2x,p2y,p2z
	if(!WaveExists(p1x))
		Abort "No wave detected"
	endif
	Concatenate/O {p1x,p1y,p1z}, p1wave
	Concatenate/O {p2x,p2y,p2z}, p2wave
	p1wave[][0,1] *= 12
	p2wave[][0,1] *= 12
	p1wave[][2] *= 60
	p2wave[][2] *= 60
	MatrixOp/O cWave = (p2wave + p1wave) / 2
	
	WAVE/T dataNameWave
	Variable nWaves = numpnts(p1x)
	String wName
	
	Variable i
	
	for(i = 0; i < nWaves; i += 1)
		wName = dataNameWave[i] + "_ax"
		Make/O/N=(3,3) $wName
		Wave w0 = $wName
		w0[0][] = p1wave[i][q]
		w0[1][] = cWave[i][q]
		w0[2][] = p2wave[i][q]
		wName = ReplaceString("_ax", wName, "_bx")
		Duplicate/O w0, $wName
	endfor
	// make a wave to colour the p1,c and p2 points (r, g and b)
	Make/O/N=(3,4) colorwave=0
	colorwave[][3] = 1
	colorwave[0][0] = 1
	colorwave[1][1] = 1
	colorwave[2][2] = 1
End

//This function loads all the the waves from different Igor pxps in a directory
Function DataLoader()
	
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
	String zPos, vNo
	String expr="vec\\w([[:digit:]]+)\\w([[:digit:]]+)"
	
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
			SetScale/I x 0,0,"", $wName	// remove scaling
			SplitString/E=(expr) wName, zPos, vNo
			Make/O/FREE/N=2 zw0=str2num(zPos)
			Concatenate/NP=1 {zw0}, $wName	// add z column
			Concatenate/NP=0 {gapw}, $wName	// add gap row
		endfor
		Concatenate/O/NP=0/KILL wList, ThreeDVecWave
		GizPlotter(expDataFolderName)
		SetDataFolder root:data:
	endfor
End

Function GizPlotter(folderName)
	String folderName
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

Function FindP2()
	SetDataFolder root:
	String wName = StringFromList(0,WaveList("*",";","WIN:"))
	Wave w0 = $wName
	w0[2][] = w0[1][q] + (w0[1][q] - w0[0][q])
End
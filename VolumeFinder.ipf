#pragma TextEncoding = "MacRoman"		// For details execute DisplayHelpTopic "The TextEncoding Pragma"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Use this function to load and process TIFF stacks in one folder
// TIFFs must be binarized versions of amira segmentation files
Function VolumeFinder()
	
	String expDiskFolderName, expDataFileName
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
	
	Variable /G vol
	Variable /G nI
	
	Make/O/D/N=(nFiles) volWave, volHWave
	Make/O/T/N=(nFiles) fileWave
	Make/O/D/N=(nFiles) nPointWave
	
	for (FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile = StringFromList(FileLoop, FileList)
		expDataFileName = ReplaceString(".tif",ThisFile,"")	// get rid of .tif
		expDataFileName = ReplaceString(".labels",expDataFileName,"")	// get rid of .labels
		ImageLoad/O/T=tiff/C=-1/LR3D/Q/P=expDiskFolder ThisFile
		VolumeCalc($ThisFile)
		fileWave[FileLoop] = expDataFileName
		volWave[FileLoop] = vol
		nPointWave[FileLoop] = nI

		Wave kCloud	//	path of the 3D convex hull
		wName = expDataFileName + "_kCloud"
		Rename kCloud $wName
		Wave HullWave	// 1D wave of polygonarea for each 2D hull per layer
		volHWave[FileLoop] = sum(HullWave)
		wName = expDataFileName + "_HullWave"
		Rename HullWave $wName
		Wave pCloud	// point cloud of all pixels over threshold
		wName = expDataFileName + "_pCloud"
		Rename pCloud $wName
		Wave LayerWave	// number of pixels over threshold per layer
		wName = expDataFileName + "_LayerWave"
		Rename LayerWave $wName
		wName = expDataFileName + "_LDens"
		MatrixOp/O $wName = LayerWave / HullWave
		WaveTransform zapnans $wName
		KillWaves /Z $ThisFile	//should already be killed
	endfor
	Duplicate nPointWave densityWave
	densityWave /= volWave
	
	//Display results
	DoWindow/K Results
	Edit/N=Results fileWave,nPointWave,volWave,densityWave,volHWave
	DoWindow/K MTvol
	Display/N=MTvol nPointWave vs fileWave
	ModifyGraph swapXY=1
	SetAxis/A/R left
	SetAxis/A/E=1/N=1 bottom
	Label bottom "Point Volume"
	DoWindow/K Spindlevol
	Display/N=spindlevol volWave vs fileWave
	ModifyGraph swapXY=1
	SetAxis/A/R left
	SetAxis/A/E=1/N=1 bottom
	Label bottom "Hull Volume"
	DoWindow/K Density
	Display/N=densityvol densityWave vs fileWave
	ModifyGraph swapXY=1
	SetAxis/A/R left
	SetAxis/A/E=1/N=1 bottom
	Label bottom "Density"

	DoWindow/K summaryLayout
	NewLayout/N=summaryLayout

	AppendLayoutObject/W=summaryLayout graph MTvol
	AppendLayoutObject/W=summaryLayout graph spindlevol
	AppendLayoutObject/W=summaryLayout graph densityvol

#If igorversion()>=7
	LayoutPageAction size(-1)=(595, 842), margins(-1)=(18, 18, 18, 18)
#EndIf
	ModifyLayout units=0
	ModifyLayout frame=0,trans=1
	Execute /Q "Tile"
End

// This function does the calculations for each dataset
////	@param	m0		matrix for processing
Function VolumeCalc(m0)
	Wave m0
	
	Variable timer = startmstimer
	NVAR /Z vol
	NVAR /Z nI	//global variables

	nI = Dimsize(m0,0)
	Variable nJ = Dimsize(m0,1)
	Variable nK = Dimsize(m0,2)
	
	Make/O/N=((nI*nJ*nK),3) m1 = NaN	//slows code but worth it
	
	Variable l = 0		// rows in result wave
	vol = 0
	Variable tempvar, V_value
	
	Variable i, j, k
	
	For (k = 0; k < nK; k += 1) // layers
		For (j = 0; j < nJ; j += 1) // columns
			For (i = 0; i < nI; i += 1)	// rows
				If (m0[i][j][k] != 0)
					m1[l][0] = i
					m1[l][1] = j
					m1[l][2] = k
					l += 1
				EndIf
			EndFor
		EndFor
	EndFor
	MatrixOp/O w0 = sumRows(m1)
	WaveTransform ZapNans w0
	nI = numpnts(w0)
	Duplicate/O/R=(0,nI-1) m1, pCloud
	KillWaves w0, m1, m0		// also gets rid of image to free memory
	
	Duplicate/O/R=[*][2] pCloud, pCloudZ
	Redimension/N=-1 pCloudZ
	Make/O/N=(nK) HullWave = 0, LayerWave = 0
	// HullWave will hold the area of each convex hull per layer
	// LayerWave will hold the number of pixels that are over threshold in that layer
	String wName, wList
	
	For (k = 0; k < nK; k += 1) // layers
		FindValue/V=(k) /Z pCloudZ
		If(V_Value > -1)	// test to see if it's worth calculating this layer
			Duplicate/O/R=[*][0] pCloud, pCloudX
			Duplicate/O/R=[*][1] pCloud, pCloudY
			Redimension/N=-1 pCloudX, pCloudY
			pCloudX = (pCloudZ == k) ? pCloudX : NaN
			pCloudY = (pCloudZ == k) ? pCloudY : NaN
			WaveTransform zapnans pCloudX
			WaveTransform zapnans pCloudY
			LayerWave[k] = numpnts(pCloudX)
			Convexhull /C pCloudX, pCloudY
			Wave W_XHull, W_YHull
			HullWave[k] = PolygonArea(W_XHull,W_YHull)
			Duplicate/O W_XHull, W_ZHull
			W_ZHull = k
			wName = "kCloud_" + num2str(k)
			Concatenate/O/KILL {W_XHull,W_YHull,W_ZHull}, $wName
		EndIf
	EndFor
	wList=WaveList("kCloud_*",";","")
	Concatenate/O/KILL/NP=0 wList, kCloud
	Triangulate3D/VOL kCloud
	vol = V_Value
	KillWaves pCloudX, pCloudY, pCloudZ
	printf "%g\r", stopmstimer(timer)/1e6
End


////	@param	xnm	voxel size, x dimension in nm, i.e. 12
////	@param	ynm	voxel size, y dimension in nm, i.e. 12
////	@param	znm	voxel size, z dimension in nm, i.e. 60
Function ScaleIt(xnm,ynm,znm)
	Variable xnm, ynm, znm
	//This will scale the points to real world values
	
	Variable scale = (xnm * ynm * znm) / (10^9)	//in µm^3
	//need to scale MTs in a different way
	If(xnm != ynm)
		Print "xnm and ynm are not equal. Please check"
	EndIf
	Variable MTscale = (1/3) * (xnm * ((PI*12.5)^2)) // assumes MTs are 3 px wide
	
	Wave nPointWave, volWave
	nPointWave *=MTscale
	volWave *=scale
	Label /W=MTvol bottom, "Point Volume (µm\S3\M)"
	Label /W=spindlevol bottom, "Hull Volume (µm\S3\M)"	
End
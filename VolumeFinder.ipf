#pragma TextEncoding = "MacRoman"		// For details execute DisplayHelpTopic "The TextEncoding Pragma"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

function tic()
	variable/G tictoc = startMSTimer
end
 
function toc()
	NVAR/Z tictoc
	variable ttTime = stopMSTimer(tictoc)
	printf "%g seconds\r", (ttTime/1e6)
	killvariables/Z tictoc
end

Function VolumeCalc(m0,meth)
	Wave m0
	Variable meth
	
	tic()
	NVAR /Z vol	//
	NVAR /Z nI	//global variables

	nI=Dimsize(m0,0)
	Variable nJ=Dimsize(m0,1)
	Variable nK=Dimsize(m0,2)
	
	Make/O/N=((nI*nJ*nK),3) m1=NaN	//slows code but worth it
	
	Variable l=0	//rows in result wave
	vol=0
	Variable tempvar
	
	Variable i,j,k
	
	For (k=0; k<nK; k+=1) //layers
		For (j=0; j<nJ; j+=1) //columns
			For (i=0; i<nI; i+=1)	//rows
				If (m0[i][j][k]!=0)
					m1[l][0]=i
					m1[l][1]=j
					m1[l][2]=k
					l +=1
				EndIf
			EndFor
		EndFor
	EndFor
	MatrixOp/O w0=sumRows(m1)
	WaveTransform ZapNans w0
	nI=numpnts(w0)
	Duplicate/O/R=(0,nI-1) m1, pCloud
	KillWaves w0,m1
	
#if (IgorVersion() >= 7)
	If(meth==1)
		Triangulate3d/VOL pCloud
	Else
		ConvexHull pCloud
		Wave M_Hull
		Triangulate3d/VOL M_Hull
	EndIf
	vol=V_value
//	Print "Volume is", V_value
#else
	If(meth==1)
		Triangulate3d/out=2 pCloud
	Else	
		ConvexHull pCloud
		Wave M_Hull
		Triangulate3d/out=2 M_Hull
		Wave M_TetraPath
		nI=dimsize(M_TetraPath,0)/20	//number of tetrahedra
		Make/O/N=(4,4) waveT=1
		For(i=0; i<nI; i+=1)
			waveT[0][0]=M_TetraPath[0+(i*20)][0]
			waveT[1][0]=M_TetraPath[1+(i*20)][0]
			waveT[2][0]=M_TetraPath[2+(i*20)][0]
			waveT[3][0]=M_TetraPath[7+(i*20)][0]
			waveT[0][1]=M_TetraPath[0+(i*20)][1]
			waveT[1][1]=M_TetraPath[1+(i*20)][1]
			waveT[2][1]=M_TetraPath[2+(i*20)][1]
			waveT[3][1]=M_TetraPath[7+(i*20)][1]
			waveT[0][2]=M_TetraPath[0+(i*20)][2]
			waveT[1][2]=M_TetraPath[1+(i*20)][2]
			waveT[2][2]=M_TetraPath[2+(i*20)][2]
			waveT[3][2]=M_TetraPath[7+(i*20)][2]
			tempvar=MatrixDet(waveT)/6
			If (tempvar<0)
				vol +=tempvar*-1
			else
				vol +=tempvar
			EndIf
		EndFor
		KillWaves WaveT
//		Print "Volume is", vol
	EndIf
#endif
	toc()
End

Function VolumeFinder(opt)
	Variable opt //0 is the calculation of volume from 3D convex hull, 1 is calculation from all points
	
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
	
	Variable /G vol
	Variable /G nI
	
	Make/O/D/N=(nFiles) volWave
	Make/O/T/N=(nFiles) fileWave
	Make/O/D/N=(nFiles) nPointWave
	
	for (FileLoop=0; FileLoop<nFiles; FileLoop+=1)
		ThisFile=StringFromList(FileLoop, FileList)
		expDataFileName=ReplaceString(".tif",ThisFile,"")	//get rid of .tif
		expDataFileName=ReplaceString(".labels",expDataFileName,"")	//get rid of .labels
		ImageLoad/O/T=tiff/C=-1/LR3D/Q/P=expDiskFolder ThisFile
		VolumeCalc($ThisFile,opt)
		fileWave[FileLoop]=expDataFileName
		volWave[FileLoop]=vol
		nPointWave[FileLoop]=nI
		If(igorversion()>=7)
			If(opt!=1)
				Wave M_Hull
				wName=expDataFileName + "_Hull"
				Rename M_Hull $wName
			EndIf
			Wave pCloud
			wName=expDataFileName + "_pCloud"
			Rename pCloud $wName
		Else
			If(opt!=1)
				Wave M_Hull
				wName=expDataFileName + "_Hull"
				Rename M_Hull $wName
			EndIf
			Wave pCloud
			wName=expDataFileName + "_pCloud"
			Rename pCloud $wName
			Wave M_TetraPath
			wName=expDataFileName + "_TP"
			Rename M_TetraPath $wName
		EndIf
		KillWaves $ThisFile
	endfor
	Duplicate nPointWave densityWave
	densityWave /=volWave
	DoWindow /K Results
	Edit /N=Results fileWave,nPointWave,volWave,densityWave
	DoWindow /K MTvol
	Display /N=MTvol nPointWave vs fileWave
	SetAxis/A/N=1 left
	ModifyGraph swapXY=1
	SetAxis/A/R left
	Label bottom "Point Volume"
	DoWindow /K Spindlevol
	Display /N=spindlevol volWave vs fileWave
	SetAxis/A/N=1 left
	ModifyGraph swapXY=1
	SetAxis/A/R left
	Label bottom "Hull Volume"
	DoWindow /K Density
	Display /N=densityvol densityWave vs fileWave
	SetAxis/A/N=1 left
	ModifyGraph swapXY=1
	SetAxis/A/R left
	Label bottom "Density"
End

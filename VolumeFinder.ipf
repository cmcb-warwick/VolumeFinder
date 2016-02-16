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

Function VolumeFinder(m0,meth)
	Wave m0
	Variable meth
	
	tic()
	Variable nI=Dimsize(m0,0)
	Variable nJ=Dimsize(m0,1)
	Variable nK=Dimsize(m0,2)
	
	Make/O/N=((nI*nJ*nK),3) m1=NaN	//slows code but worth it
	Make/O/N=(4,4) waveT=1
	
	Variable l=0	//rows in result wave
	Variable vol=0,tempvar
	
	Variable i,j,k
	
	For (k=0; k<nK; k+=1) //layers
		For (j=0; j<nK; j+=1) //columns
			For (i=0; i<ni; i+=1)	//rows
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
	Print "Volume is", V_value
#else
	If(meth==1)
		Triangulate3d/out=2 pCloud
	Else	
		ConvexHull pCloud
		Wave M_Hull
		Triangulate3d/out=2 M_Hull
		Wave M_TetraPath
		nI=dimsize(M_TetraPath,0)/20	//number of tetrahedra
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
		Print "Volume is", vol
	EndIf
#endif
	toc()
End

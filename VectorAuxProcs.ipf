#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function PlotSlice(zsec)
	Variable zsec
	
	Variable znm = zsec * 60
	String wList = WaveList("Vec_" + num2str(znm) + "_*",";","")
	Variable nWaves = ItemsInList(wList)
	String wName
	DoWindow/K slicePlot
	Display/N=slicePlot
	
	Variable i
	
	for(i = 0; i < nWaves; i += 1)
		wName = StringFromList(i,wList)
		Wave w0 = $wName
		AppendToGraph/W=slicePlot w0[][1] vs w0[][0]
	endfor
	
End

Function PutEllipseBack()
	String elliList = WaveList("elli_*",";","")
	String vecList = ReplaceString("elli_",elliList,"vec_")
	Concatenate/O/NP=0 elliList, elli3D
	Concatenate/O/NP=0 vecList, vec3D
	Variable nRows = DimSize(vec3D,0)
	
	Variable i,j=0

	for(i = 2; i < (nRows/2) * 3; i += 3)
		InsertPoints i, 1, vec3D,elli3D
		elli3D[i][] = NaN
		vec3D[i][] = NaN
	endfor
	
	WAVE e_avWave,e_rWave,e_mpWave,e_prWave
	
	Duplicate/O e_avWave, e_avWave2
	e_avWave2 *= e_rWave[p]
	Duplicate/O/FREE e_avWave2, e_avWave21
	Duplicate/O e_avWave2, e_avWave3
	e_avWave3 += e_mpWave[p][q] // new endpoint
	Duplicate/O e_mpWave, e_avWave4
	e_avWave4 -= e_avWave21[p][q] // new startpoint
	
	Duplicate/O e_prWave, e_prWave2
	e_prWave2 *= e_rWave[p]
	Duplicate/O/FREE e_prWave2, e_prWave21
	Duplicate/O e_prWave2, e_prWave3
	e_prWave3 += e_mpWave[p][q] // new endpoint
	Duplicate/O e_mpWave, e_prWave4
	e_prWave4 -= e_prWave21[p][q] // new startpoint

	nRows = DimSize(e_avWave,0)
	Make/O/N=(nRows*3,3) vec3Dre,elli3Dre
	
	for(i = 0; i < nRows *3; i +=3)
		vec3Dre[i][] = e_avWave4[j][q]
		vec3Dre[i+1][] = e_avWave3[j][q]
		vec3Dre[i+2][] = NaN
		
		elli3Dre[i][] = e_prWave4[j][q]
		elli3Dre[i+1][] = e_prWave3[j][q]
		elli3Dre[i+2][] = NaN
		j += 1
	endfor
	
	Wave zRotationMatrix,yRotationMatrix
	
	Duplicate/O zRotationMatrix, zBackMatrix
	Duplicate/O yRotationMatrix, yBackMatrix
	MatrixTranspose zBackMatrix
	MatrixTranspose yBackMatrix
	
	MatrixMultiply elli3Dre, yBackMatrix
	Wave M_product
	MatrixMultiply M_product, zBackMatrix
	Duplicate/O M_Product, elli3Dre
	
	Wave spWave
	
	Variable cx = (spWave[0][0] + spWave[1][0]) / 2
	Variable cy = (spWave[0][1] + spWave[1][1]) / 2
	Variable cz = (spWave[0][2] + spWave[1][2]) / 2
	
	elli3Dre[][0] += cx
	elli3Dre[][1] += cy
	elli3Dre[][2] += cz
End


Function CheckVectors()
	hgjk
	Wave e_mpWave, e_avWave, e_prWave
	Variable nVec = dimsize(e_mpWave,0)
	Make/O/N=(nVec * 4,3) checkMat
	Variable rr

	Variable i, j=1

	for(i = 0; i < nVec; i += 1)
		checkMat[j][] = e_mpWave[i][q]
		MatrixOp/O/FREE avWave = row(e_avWave,i)
		rr = norm(avWave)
		avWave /= rr/100
		checkMat[j-1][] = e_mpWave[i][q] + avWave[i][q]
		MatrixOp/O/FREE prWave = row(e_prWave,i)
		rr = norm(prWave)
		prWave /= rr/100
		checkMat[j+1][] = e_mpWave[i][q] + prWave[i][q]
		checkMat[j+2][] = NaN
		j += 4
	endfor
End

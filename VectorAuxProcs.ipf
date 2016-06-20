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

Function CheckVectors()
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

// This function will take the elli3Dre ouput and overwrite individual elli_ waves
Function OverwriteElliWaves()
	String elliList = WaveList("elli_*",";","")
	Variable nWaves = ItemsInList(elliList)
	String wName
	Wave m0 = elli3Dre
	
	Variable i,j=0
	
	for(i = 0; i < nWaves; i += 1)
		wName = StringFromList(i, elliList)
		Wave w0 = $wName
		w0[0][] = m0[j][q]
		w0[1][] = m0[j+1][q]
		j +=3
	endfor
End
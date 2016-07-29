#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Function UseLineModel()
	WAVE/Z segLengthWave,pol_Des
	String VectorList = WaveList("vec_*",";","")
	Variable nVectors = ItemsInList(VectorList)
	// In vector wave, row 0 and 1 are xyz coords for points A and B
	// Spindle poles are 1 and 2
	WAVE spWave
	Variable sp1x = spWave[0][0]
	Variable sp1y = spWave[0][1]
	Variable sp2x = spWave[1][0]
	Variable sp2y = spWave[1][1]
	Variable ABx, CDx, ABy, CDy
	String wName
	Make/O/N=(nVectors)/T line_Name	// name of vector wave
	Make/O/N=(nVectors) line_Angle // what is the angle releative to the spindle axis?

	Variable i
	
	for(i = 0; i < nVectors; i += 1)
		wName = StringFromList(i,VectorList)
		Wave w0 = $wName
		line_Name[i] = wName
		// line AB is from nearest spindle pole to midpoint of vector
		// line CD is the MT vector
		if(segLengthWave[i] > 60)
			if(pol_Des[i] == 1)
				ABx = ((w0[1][0] + w0[0][0]) / 2) - sp1X
				ABy = ((w0[1][1] + w0[0][1]) / 2) - sp1Y
				CDx = w0[1][0] - w0[0][0]
				CDy = w0[1][1] - w0[0][1]
				line_Angle[i] = (atan2(ABy,ABx) - atan2(CDy,CDx)) * (180/pi)
			elseif(pol_Des[i] == 2)
				ABx = ((w0[1][0] + w0[0][0]) / 2) - sp2X
				ABy = ((w0[1][1] + w0[0][1]) / 2) - sp2Y
				CDx = w0[1][0] - w0[0][0]
				CDy = w0[1][1] - w0[0][1]
				line_Angle[i] = (atan2(ABy,ABx) - atan2(CDy,CDx)) * (180/pi)
			else
				line_Angle[i] = NaN
			endif
		else
			line_Angle[i] = NaN
		endif
		
		if(line_Angle[i] > 180)
			line_Angle[i] -= 360
		elseif(line_angle[i] < -180)
			line_Angle[i] += 360
		endif
	endfor
	Make/N=90/O line_angle_Hist
	Histogram/B={0,2,90} line_angle,line_angle_Hist
	KillWindow/Z lineHist
	Display/N=lineHist line_angle_Hist
	ModifyGraph/W=lineHist rgb=(32768,43688,65535)
	TextBox/C/N=text0/F=0/A=LT/X=0.00/Y=0.00 "Line comparison"
End

Function CompareAlphaAll()
	String wList = WaveList("*angleWave",";","")
	Variable nWaves = ItemsInList(wList)
	String w0Name,w1Name
	Make/O/N=(nWaves,nWaves) resultMat
	Make/O/N=(nWaves) labelPos=p
	Make/O/N=(nWaves)/T labelWave
	Variable i,j
	
	for(i = 0; i < nWaves; i += 1)
		w0Name = StringFromList(i,wList)
		Wave w0 = $w0Name
		labelWave[i] = ReplaceString("_AngleWave",w0Name,"")
		for(j = 0; j < nWaves; j += 1)
			if(i == j)
				resultMat[i][j] = 0
			else
				w1Name = StringFromList(j,wList)
				Wave w1 = $w1Name
				resultMat[i][j] = CompareAlpha(w0,w1)
			endif
		endfor
	endfor
	KillWindow/Z result
	NewImage/N=result resultMat
	ModifyImage/W=result resultMat ctab= {0.0001,1,RedWhiteBlue,0},minRGB=(52428,52428,52428),maxRGB=0
	ModifyGraph/W=result userticks(left)={labelpos,labelWave}
	ModifyGraph/W=result userticks(top)={labelpos,labelWave}
	ModifyGraph/W=result tick=3,tkLblRot(left)=0,tkLblRot(top)=90,tlOffset=0
	ModifyGraph/W=result margin(left)=42,margin(top)=42
	
	String textName,labelValStr
	Duplicate/O resultMat,labelVal
	Variable matsize = numpnts(resultMat)
	Redimension/N=(matsize) labelVal
	DoWindow/F result
	
	for(i = 0; i < matsize; i += 1)
		if(labelVal[i] != 0)
			textName = "text" + num2str(i)
			labelValStr = num2str(Rounder(labelVal[i],2))
			Tag/C/N=$textName/F=0/B=1/X=0.00/Y=0.00/L=0 resultMat, i, labelValStr
		endif
	endfor
End

//// @param	w0c	wave containing angle differences from ideal distribution (may have NaNs)
//// @param	w1c	wave containing angle differences from ideal distribution (may have NaNs)
Function CompareAlpha(w0c,w1c)
	Wave w0c,w1c
	
	Duplicate/O w0c, w0
	Duplicate/O w1c, w1
	WaveTransform zapnans w0
	WaveTransform zapnans w1
	
	Variable tempvar = 0
	FindDuplicates/RN=w0ue/TOL=0.0001 w0
	Variable nAngles = numpnts(w0ue)
	
	Variable i
	
	for(i = 0; i < nAngles; i += 1)
		Extract/FREE/O w0,w2,w0 > (w0ue[i] - 0.0001) && w0 < (w0ue[i] + 0.0001)
		Extract/FREE/O w1,w3,w1 > (w0ue[i] + 0.0001)
		tempvar += numpnts(w2) * numpnts(w3)
	endfor
	tempvar /= (numpnts(w0) * numpnts(w1))
//	Print tempvar
	KillWaves w0ue,w0,w1
	return tempvar
End

////	@param	value				this is the input value that requires rounding
////	@param	numSigDigits		number of significant digits for the rounding procedure
Function Rounder(value, numSigDigits)
	Variable value, numSigDigits
 
	String str
	Sprintf str, "%.*g\r", numSigDigits, value
	return str2num(str)
End

// A quick procedure to extract and plot out the vectors from one zslice
//// @param	zsec	Which z section is to be visualised
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

// A quick procedure to map out all the vectors in a gizmo
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
// Unlikely to be useful for anything other than error checking
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
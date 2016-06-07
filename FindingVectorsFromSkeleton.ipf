#pragma TextEncoding = "MacRoman"		// For details execute DisplayHelpTopic "The TextEncoding Pragma"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Menu item for easy execution
Menu "Macros"
	"MTs2Vectors...",  MTs2Vectors()
End

Function MTs2Vectors()
	if(ProcessTIFFs() == -1)
		Print "Error"
		Return 0
	endif
	Variable timer = startmstimer
	Polarise()
	segWrapper()
	TidyAndReport()
	printf "%g\r", stopmstimer(timer)/1e6
End

Function ProcessTIFFs()
	
	// kill all windows and waves before we start
	String fullList = WinList("*", ";","WIN:3")
	String name
	Variable i
 
	for(i = 0; i < ItemsInList(fullList); i += 1)
		name = StringFromList(i, fullList)
		DoWindow/K $name		
	endfor
	KillWaves/A/Z
	
	String FileList, ThisFile
	Variable FileLoop
	
	String userResponse
	Prompt userResponse, "Do you have spindle axis waves?", popup, "yes;no;"
	DoPrompt "Axis definition", userResponse
	if (V_flag!=0)
		DoAlert 0, "User pressed cancel"
		Return -1
	endif
	
	if(cmpstr(userResponse,"yes")==0)
		NewPath/O/Q/M="Folder with axis points" axisFolder
		if (V_flag != 0)
			DoAlert 0, "User pressed cancel"
			Return -1
		endif
		LoadWave/W/H/A/C/P=axisFolder "labelWave.ibw"
		LoadWave/W/H/A/C/P=axisFolder "r_p1Wave.ibw"
		LoadWave/W/H/A/C/P=axisFolder "r_cWave.ibw"
		LoadWave/W/H/A/C/P=axisFolder "r_p2Wave.ibw"
	endif
	WAVE/T/Z labelWave
	WAVE/Z r_p1Wave,r_p2Wave
	
	NewPath/O/Q/M="Folder with skeletons" ExpDiskFolder
	if (V_flag != 0)
		DoAlert 0, "User pressed cancel"
		Return -1
	endif
	FileList = IndexedFile(expDiskFolder,-1,".tif")
	Variable nFiles = ItemsInList(FileList)
	Variable /G fileIndex
	ThisFile = StringFromList(0,FileList)
	String baseName = ReplaceString(".Labels0000-labeled-skeletons.tif",ThisFile,"")
	
	Prompt baseName, "Enter baseName"
	DoPrompt "What is the original TIFF stack name?", baseName
	String /G TIFFtitle = baseName
	if (V_flag!=0)
		DoAlert 0, "User pressed cancel"
		Return -1
	endif
	
	Variable pxSize = 12
	Variable zSize = 60
	
	Prompt pxSize, "Pixel size, nm"
	Prompt zSize, "Section interval, nm"
	DoPrompt "Please check", pxSize, zSize
	Variable /G gpxSize = pxSize
	Variable /G gzSize = zSize
	if (V_flag!=0)
		DoAlert 0, "User pressed cancel"
		Return -1
	endif
	
	Variable sp1x = 0
	Variable sp1y = 0
	Variable sp1z = 250
	Variable sp2x = 768
	Variable sp2y = 768
	Variable sp2z = 250
	
	if(cmpstr(userResponse,"yes")==0)
		FindValue/TEXT=baseName labelWave
		i = V_Value
		sp1x = r_p1Wave[i][0]
		sp1y = r_p1Wave[i][1]
		sp1z = r_p1Wave[i][2]
		sp2x = r_p2Wave[i][0]
		sp2y = r_p2Wave[i][1]
		sp2z = r_p2Wave[i][2]
	endif
	
	Prompt sp1x, "X1"
	Prompt sp1y, "Y1"
	Prompt sp1z, "Z1"
	Prompt sp2x, "X2"
	Prompt sp2y, "Y2"
	Prompt sp2z, "Z2"
	DoPrompt "Define centrosome positions, px", sp1x,sp1y,sp1z, sp2x,sp2y,sp2z
	if (V_flag!=0)
		DoAlert 0, "User pressed cancel"
		Return -1
	endif
	
	Variable timer = startmstimer
	
	Make/O spWave={{sp1x,sp2x},{sp1y,sp2y},{sp1z,sp2z}}
	spWave[][0,1] *= pxSize
	spWave[][2] *= zSize
	
	DoWindow/K allPlot
	Display /N=allPlot
	
	for(FileLoop = 0; FileLoop < nFiles; FileLoop += 1)
		ThisFile=StringFromList(FileLoop, FileList)
		ImageLoad/O/T=tiff/Q/P=expDiskFolder/N=lImage ThisFile
		fileIndex = FileLoop * zSize
		Wave lImage
		if(sum(lImage) > 0)
			Extractor(lImage)
		endif
		KillWaves /Z lImage // should be killed by Extractor()
	endfor
	printf "%g\r", stopmstimer(timer)/1e6
End

////	@param	m0		lImage 2D wave(image)
Function Extractor(m0)
	Wave m0
	
	ImageStats m0
	NVAR /Z nZ = fileIndex	// global variable
	Variable lastMT = V_max
	String wName
	
	Variable i
	
	for(i = 1; i < (lastMT + 1); i += 1) // MT, 1-based
		Duplicate/O m0, tempXw
		Duplicate/O m0, tempYw
		tempXw = (m0[p][q] == i) ? p : NaN
		tempYw = (m0[p][q] == i) ? q : NaN
		Redimension/N=(V_npnts) tempXw,tempYw
		WaveTransform zapnans tempXw
		WaveTransform zapnans tempYw
		if(numpnts(tempXw) > 2)
			TheFitter(tempXw,tempYw,i)
		endif
	endfor
	KillWaves m0,tempXw,tempYw
End

////	@param	xW		this is the xWave for fitting
////	@param	yW		this is the yWave for fitting
////	@param	i		passing this variable rather than using another global variable
Function TheFitter(xW,yW,i)
	Wave xW
	Wave yW
	Variable i
	NVAR/Z nZ = fileIndex	// global variable
	NVAR/Z xySize = gpxSize
	WAVE/Z W_coef
	
	CurveFit/Q/NTHR=0 line, yW /X=xW /D
	WAVE /Z fit_tempYw
	if(sum(W_coef) != 0)
		String wName = "vec_" + num2str(nZ) + "_" + num2str(i)
		Make/O/N=(2,3) $wName
		Wave m1 = $wName
		m1[0][0] = (wavemin(xW)) * xySize
		m1[1][0] = (wavemax(xW)) * xySize
		m1[0][1] = (W_coef[0] + (wavemin(xW) * W_coef[1])) * xySize
		m1[1][1] = (W_coef[0] + (wavemax(xW) * W_coef[1])) * xySize
		m1[][2] = nZ
		AppendToGraph/W=allPlot m1[][1] vs m1[][0]
	endif
	KillWaves fit_tempYw
End

Function Polarise()
	String VectorList = WaveList("vec_*",";","")
	Variable nVectors = ItemsInList(VectorList)
	// In vector wave, row 0 and 1 are xy coords for points A and B, pick Z from name
	// Spindle poles are 1 and 2
	WAVE spWave
	Variable sp1x = spWave[0][0]
	Variable sp1y = spWave[0][1]
	Variable sp1z = spWave[0][2]
	Variable sp2x = spWave[1][0]
	Variable sp2y = spWave[1][1]
	Variable sp2z = spWave[1][2]
	Variable sp1_A,sp1_B,sp2_A,sp2_B
	Variable ABx, CDx, ABy, CDy
	String wName
	Variable nearest,cW
	Make/O/N=(nVectors)/T pol_Name	// name of vector wave
	Make/O/N=(nVectors) pol_Des	// which spindle pole is it from
	Make/O/N=(nVectors) pol_Rev	// did the polarity get reversed?
	Make/O/N=(nVectors) pol_Angle // what is the angle releative to the spindle axis?
	// rgb waves as 1D, needs a p=9 point only for 180¡ or -180¡
	Make/O/N=10 rW={257,34952,17476,4369,39321,56797,52428,34952,43690,43690}
	Make/O/N=10 gW={8738,52428,43690,30583,39321,52428,26214,8738,17476,17476}
	Make/O/N=10 bW={34952,61166,39321,13107,13107,30583,30583,21845,39321,39321}
	Variable i
	
	for(i = 0; i < nVectors; i += 1)
		wName = StringFromList(i,VectorList)
		Wave w0 = $wName
		pol_Name[i] = wName
		sp1_A = sqrt((w0[0][0] - sp1X)^2 + (w0[0][1] - sp1Y)^2 + (w0[0][2] - sp1Z)^2)
		sp1_B = sqrt((w0[1][0] - sp1X)^2 + (w0[1][1] - sp1Y)^2 + (w0[1][2] - sp1Z)^2)
		sp2_A = sqrt((w0[0][0] - sp2X)^2 + (w0[0][1] - sp2Y)^2 + (w0[0][2] - sp2Z)^2)
		sp2_B = sqrt((w0[1][0] - sp2X)^2 + (w0[1][1] - sp2Y)^2 + (w0[1][2] - sp2Z)^2)
		nearest = min(sp1_A,sp1_B,sp2_A,sp2_B)
		if(nearest == sp1_A || nearest == sp1_B)
			pol_Des[i] = 1
			if(sp1_A >= sp1_B)
				Reverse/P/DIM=0 w0
				pol_Rev[i] = 1
			else
				pol_Rev[i] = 0
			endif
			// line AB is between spindle poles
			// line CD is the MT vector
			ABx=sp2X - sp1X
			CDx=w0[1][0] - w0[0][0]
			ABy=sp2Y - sp1Y
			CDy=w0[1][1] - w0[0][1]
			pol_Angle[i] = (atan2(ABy,ABx) - atan2(CDy,CDx)) * (180/pi)
		else
			pol_Des[i] = 2
			if(sp2_A >= sp2_B)
				Reverse/DIM=0 w0
				pol_Rev[i] = 1
			else
				pol_Rev[i] = 0
			endif
			ABx=sp1X - sp2X
			CDx=w0[1][0] - w0[0][0]
			ABy=sp1Y - sp2Y
			CDy=w0[1][1] - w0[0][1]
			pol_Angle[i] = (atan2(ABy,ABx) - atan2(CDy,CDx)) * (180/pi)
		endif
		
		if(pol_Angle[i] > 180)
			pol_Angle[i] -= 360
		elseif(pol_angle[i] < -180)
			pol_Angle[i] += 360
		endif
		
		cW = floor(abs(pol_Angle[i])/20)
		if(numtype(cW) == 2)
			RemoveFromGraph/W=allplot $wName
		else
			ModifyGraph/W=allPlot rgb($wName)=(rW[cW],gW[cW],bW[cW])
		endif
	endfor
End

Function TidyAndReport()
	NVAR /Z xySize = gpxSize
	WAVE spWave,pol_Angle,pol_Des,segAngleWave
	SVAR expCond = TIFFtitle
	
	DoWindow/F allPlot
	AppendToGraph/W=allPlot spWave[][1] vs spWave[][0]
	ModifyGraph/W=allPlot width={Plan,1,bottom,left}
	SetAxis/W=allPlot/R left 768*xysize,0
	SetAxis/W=allPlot bottom 0,768*xysize
	ModifyGraph mirror=1,noLabel=2,axRGB=(34952,34952,34952)
	ModifyGraph tlblRGB=(34952,34952,34952),alblRGB=(34952,34952,34952)
	ModifyGraph margin=14
	
	MakeCirclePlot()
	
	String histList = "sp1Hist;sp2Hist;allHist;allposHist;segAngleHist;segposHist;"
	String histName
	Variable i
	
	for(i = 0; i < ItemsInList(histList); i += 1)
		histName = StringFromList(i,histList)
		DoWindow/K $histName
	endfor
	
	Duplicate/O pol_Angle pol_Angle_1,pol_Angle_2
	pol_Angle_1 = (pol_Des == 1) ? pol_Angle_1 : NaN
	pol_Angle_2 = (pol_Des == 2) ? pol_Angle_2 : NaN
	WaveTransform zapnans pol_Angle_1
	WaveTransform zapnans pol_Angle_2
	
	Make/N=360/O pol_Angle_1_Hist
	Histogram/B={-360,2,360} pol_Angle_1,pol_Angle_1_Hist
	Display/N=sp1Hist pol_Angle_1_Hist
	TextBox/C/N=text0/F=0/A=LT/X=0.00/Y=0.00 "Spindle pole 1"
	Make/N=360/O pol_Angle_2_Hist
	Histogram/B={-360,2,360} pol_Angle_2,pol_Angle_2_Hist
	Display/N=sp2Hist pol_Angle_2_Hist
	TextBox/C/N=text0/F=0/A=LT/X=0.00/Y=0.00 "Spindle pole 2"
	
	Concatenate/O {pol_Angle_1,pol_Angle_2}, pol_Angle_all
	Make/N=360/O pol_angle_all_Hist
	Histogram/B={-360,2,360} pol_Angle_all,pol_Angle_all_Hist
	Display/N=allHist pol_Angle_all_Hist
	TextBox/C/N=text0/F=0/A=LT/X=0.00/Y=0.00 "All MTs"
	
	Duplicate/O pol_Angle_all pol_Angle_all_pos
	pol_Angle_all_pos = abs(pol_Angle_all[p])
	Make/N=360/O pol_Angle_all_pos_Hist
	Histogram/B={-360,2,360} pol_Angle_all_pos,pol_Angle_all_pos_Hist
	Display/N=allposHist pol_Angle_all_pos_Hist
	TextBox/C/N=text0/F=0/A=LT/X=0.00/Y=0.00 "All MTs reflection"
	
	Duplicate/O segAngleWave segAngleWave_all
	WaveTransform zapnans segAngleWave_all
	Make/N=360/O seg_angle_Hist
	Histogram/B={-360,2,360} segAngleWave_all,seg_angle_Hist
	Display/N=segAngleHist seg_angle_Hist
	TextBox/C/N=text0/F=0/A=LT/X=0.00/Y=0.00 "Nearest MT Segments"
	
	Duplicate/O segAngleWave_all segAngleWave_all_pos
	segAngleWave_all_pos = abs(segAngleWave_all[p])
	Make/N=360/O seg_angle_pos_Hist
	Histogram/B={-360,2,360} segAngleWave_all_pos,seg_angle_pos_Hist
	Display/N=segposHist seg_angle_pos_Hist
	TextBox/C/N=text0/F=0/A=LT/X=0.00/Y=0.00 "Nearest MT segments reflection"
	
	DoWindow /K summaryLayout
	NewLayout /N=summaryLayout
	AppendLayoutObject /W=summaryLayout graph allPlot
	AppendLayoutObject /W=summaryLayout graph circlePlot
	
	for(i = 0; i < ItemsInList(histList); i += 1)
		histName = StringFromList(i,histList)
		Label/W=$histName bottom "Relative angle (¡)"
		Label/W=$histName left "Frequency"
		ModifyGraph/W=$histName mode=5,hbFill=4
		AppendLayoutObject /W=summaryLayout graph $histName
	endfor

	// Tidy report
	DoWindow /F summaryLayout
	// in case these are not captured as prefs
#if igorversion()>=7
	LayoutPageAction size(-1)=(595, 842), margins(-1)=(18, 18, 18, 18)
#endif
	ModifyLayout units=0
	ModifyLayout frame=0,trans=1
	Execute /Q "Tile/A=(6,2) sp1Hist,sp2Hist,allHist,allposHist,segAngleHist,segposHist"
	TextBox/C/N=text0/F=0/A=RB/X=0.00/Y=0.00 expCond
	ModifyLayout top(allPlot)=425,width(allPlot)=533,height(allPlot)=392
	ModifyLayout top(circlePlot)=432,left(circlePlot)=442,width(circlePlot)=100,height(circlePlot)=100
	SavePICT/E=-2 as expCond + ".pdf"
End

Function segWrapper()
	NVAR/Z nZ = fileIndex
	NVAR/Z zSize = gzSize
	if (!NVAR_Exists(zSize))
		Variable/G gzSize = 60
	endif
	
	String mList = WaveList("vec_*",";","")
	String matList = mList
	Variable nVec = ItemsInList(mList)
	Make/O/T/N=(nVec) segLabelWave=""
	Make/O/N=(nVec) segLengthWave=NaN
	Make/O/T/N=(nVec*500) seg1Wave="",seg2Wave=""
	Make/O/N=(nVec*500) segDistWave=NaN,segAngleWave=NaN
	String mName,subList,negList,sliceList
	Variable tempVar
	String mName0,mName1
	
	Variable i,j,k,l=0
	
	for(i = 0; i < nVec; i += 1)
		mName = StringFromList(i,mList)
		Wave m0 = $mName
		segLabelWave[i] = mName
		MatrixOp/FREE tempmatP = row(m0,0)
		MatrixOp/FREE tempmatQ = row(m0,1)
		MatrixOP/FREE tempMat = tempmatP - tempmatQ
		tempVar = norm(tempMat)
		segLengthWave[i] = tempvar
		if(tempvar <= 60)
			matList = RemoveFromList(mName, matList)
		elseif(numtype(tempvar)==2)
			matList = RemoveFromList(mName, matList)
		endif
	endfor
	
	for(i = 0; i < nZ; i += zSize)
		subList = WaveList("vec_" + num2str(i) + "*",";","")
		if(ItemsInList(subList) > 1)
			negList = matList
			sliceList = matList
			negList = RemoveFromList(subList,negList)	// remove subList from matList copy, making negative list
			sliceList = RemoveFromList(negList,sliceList)	//	remove the negative list from matList copy leaving subList >= 60 nm long
			nVec = ItemsInList(sliceList)
			if(nVec > 1)
				for(j = 0; j < nVec; j += 1)
					mName0 = StringFromList(j,sliceList)
					Wave m0 = $mName0
					for(k = 0; k < nVec; k += 1)
						if(j > k)
							mName1 = StringFromList(k,sliceList)
							Wave m1 = $mName1
							seg1Wave[l] = mName0
							seg2Wave[l] = mName1
							segDistWave[l] = seg2seg(m0,m1)
							if(segDistWave[l] < 120)	//segments that are less than 120 nm are analysed
								segAngleWave[l] = ssAngle(m0,m1)
							else
								segAngleWave[l] = NaN
							endif
							l += 1
						endif
					endfor
				endfor
			endif
		endif
	endfor
	// trim seg* waves, can't zapnans
	nVec = numpnts(seg1Wave) // reuse variable
	DeletePoints l, nVec - l, segLabelWave,segLengthWave,seg1Wave,seg2Wave,segDistWave,segAngleWave
	
	elliWrapper(matlist)
End

////	@param	m0		matrix wave containing 2D coords for segment 1
////	@param	m1		matrix wave containing 2D coords for segment 2
Function seg2seg(m0,m1)
	Wave m0,m1
	MatrixOp/O matP = row(m0,0)
	MatrixOp/O matQ = row(m0,1)
	MatrixOp/O matR = row(m1,0)
	MatrixOp/O matS = row(m1,1)
	
	Variable vSmall = 0.00001
	
	MatrixOP/O mat_u = matQ - matP
   MatrixOP/O mat_v = matS - matR
   MatrixOP/O mat_w = matP - matR
   Variable aa = MatrixDot(mat_u,mat_u) // always >= 0
   Variable bb = MatrixDot(mat_u,mat_v)
   Variable cc = MatrixDot(mat_v,mat_v) // always >= 0
   Variable dd = MatrixDot(mat_u,mat_w)
   Variable ee = MatrixDot(mat_v,mat_w)
   Variable bigD = aa*cc - bb*bb	//always >= 0
   Variable sc, sN, sD = bigD 	// sc = sN / sD, default sD = D >= 0
   Variable tc, tN, tD = bigD	// tc = tN / tD, default tD = D >= 0
	// compute the line parameters of the two closest points
	if (bigD < vSmall)  // the lines are almost parallel
		sN = 0         // force using point P0 on segment S1
		sD = 1        // to prevent possible division by 0.0 later
		tN = ee
		tD = cc
    else                 // get the closest points on the infinite lines
		sN = (bb*ee - cc*dd)
		tN = (aa*ee - bb*dd)
		if (sN < 0)       // sc < 0 => the s=0 edge is visible
			sN = 0
			tN = ee
			tD = cc
		elseif (sN > sD) // sc > 1  => the s=1 edge is visible
			sN = sD
			tN = ee + bb
			tD = cc
		endif
	endif

	if (tN < 0)            // tc < 0 => the t=0 edge is visible
		tN = 0
		// recompute sc for this edge
		if (-dd < 0)
			sN = 0
		elseif (-dd > aa)
			sN = sD
		else
			sN = -dd
			sD = aa
		endif	
	elseif (tN > tD)      // tc > 1  => the t=1 edge is visible
		tN = tD
		// recompute sc for this edge
		if ((-dd + bb) < 0)
			sN = 0
		elseif ((-dd + bb) > aa)
			sN = sD
		else
			sN = (-dd +  bb)
			sD = aa
		endif
    endif
	// finally do the division to get sc and tc
	sc = (abs(sN) < vSmall ? 0 : sN / sD)
	tc = (abs(tN) < vSmall ? 0 : tN / tD)
	// get the difference of the two closest points
	MatrixOp/O matdP = mat_w + (sc * mat_u) - (tc * mat_v);  // =  S1(sc) - S2(tc)
	Return norm(matdP)   // return the closest distance
End

////	@param	m0		matrix wave containing 2D coords for segment 1
////	@param	m1		matrix wave containing 2D coords for segment 2
Function ssAngle(m0,m1)
	Wave m0,m1
	
	Variable PQx, RSx, PQy, RSy, angle
	
	PQx = m0[1][0] - m0[0][0]
	RSx = m1[1][0] - m1[0][0]
	PQy = m0[1][1] - m0[0][1]
	RSy = m1[1][1] - m1[0][1]
	angle = (atan2(PQy,PQx) - atan2(RSy,RSx)) * (180/pi)
	if(angle > 180)
		angle -= 360
	elseif(angle < -180)
		angle += 360
	endif	
	Return angle
End

Function MakeCirclePlot()
	
	WAVE/Z rW,gW,bW
	Make/O/N=(360,2) circleWave=0
	Make/O/N=(360,3) circleColor
	Variable i=0, j
	
	for(i = 0; i < 360; i += 1)
		j = i - 180
		circleWave[i][0] = sin(j*(pi/180))
		circleWave[i][1] = cos(j*(pi/180))
		circleColor[i][0] = rW[floor(abs(j)/20)]
		circleColor[i][1] = gW[floor(abs(j)/20)]
		circleColor[i][2] = bW[floor(abs(j)/20)]
	endfor
	DoWindow/K circlePlot
	Display/N=circlePlot circlewave[][1] vs circleWave[][0]
	DoWindow/F circlePlot
	ModifyGraph/W=circlePlot zColor(circleWave)={circleColor,*,*,directRGB,0}
	ModifyGraph/W=circlePlot margin=5,width={Plan,1,bottom,left}
	ModifyGraph/W=circlePlot noLabel=2,axThick=0
	ModifyGraph/W=circlePlot mode=3,marker=19
	SetDrawEnv xcoord= bottom,ycoord= left,linefgc= (65535,0,0),arrow= 1;DelayUpdate
	DrawLine 0,0,0,1
End

////	@param	elliList	list of eligible vector waves
Function elliWrapper(elliList)
	String elliList
	
	WAVE spWave
	// find spindle midpoint
	Variable cx = (spWave[0][0] + spWave[1][0]) / 2
	Variable cy = (spWave[0][1] + spWave[1][1]) / 2
	Variable cz = (spWave[0][2] + spWave[1][2]) / 2
	
	// centre spindle axis
	Duplicate/O spWave, e_spWave
	e_spWave[][0] -= cx
	e_spWave[][1] -= cy
	e_spWave[][2] -= cz
	// find theta and phi for e_spwave
	Variable wx = e_spWave[0][0] - 0
	Variable wy = e_spWave[0][1] - 0
	Variable wz = e_spWave[0][2] - 0
	// inclination/polar, theta. azimuth, phi
	Variable theta = acos(wz / (sqrt( (wx^2) + (wy^2) + (wz^2) ) ) )
	Variable phi = atan2(wy,wx)
	// rotate spindle axis
	Make/O zRotationMatrix={{cos(phi),sin(phi),0},{-sin(phi),cos(phi),0},{0,0,1}}
	Make/O yRotationMatrix={{cos(theta),0,-sin(theta)},{0,1,0},{sin(theta),0,cos(theta)}}
	MatrixMultiply e_spWave, zRotationMatrix
	Wave M_Product
	MatrixMultiply M_Product, yRotationMatrix
	Duplicate/O M_Product r_spWave
	// determine length c (point c to point p1) 
	Variable cc = sqrt(wx^2 + wy^2 + wz^2)
	
	// loop through all MT vectors
	Variable nVec = ItemsInList(elliList)
	String mName, newName
	Variable zt
	Make/O/N=(nVec,3) e_mpWave,e_avWave,e_prWave // midpoint, actual vector, proposed vector
	Make/O/N=(nVec) e_rWave,e_angleWave
	Make/O/N=(nVec)/T e_nameWave
	Variable rr // length of vector for normalisation
	Variable i
	
	for(i = 0; i < nVec; i += 1)
		mName = StringFromList(i,elliList)
		Wave m0 = $mName
		newName = ReplaceString("vec_",mName,"elli_")
		Duplicate/O m0, $newName
		Wave m1 = $newName
		// subtract c from all points
		m1[][0] -= cx
		m1[][1] -= cy
		m1[][2] -= cz
		// rotate all points by theta and phi
		MatrixMultiply m1, zRotationMatrix
		MatrixMultiply M_Product, yRotationMatrix
		Duplicate/O M_Product $newname
		e_nameWave[i] = newName
		// find midpoint of all MTs
		wx = (m1[0][0] + m1[1][0]) / 2
		wy = (m1[0][1] + m1[1][1]) / 2
		wz = (m1[0][2] + m1[1][2]) / 2
		Make/O/FREE/N=(1,3) mpWave = {{wx},{wy},{wz}}
		if(norm(mpWave) < cc)
			e_mpWave[i][] = mpWave[0][q]
			// transform z coord for mhat(x)
			zt = (wz^2 - cc^2) / wz
			// make actual vector
			MatrixOp/O/FREE avWave = row(m1,1)
			avWave[0][] -= mpWave[0][q]
			rr = norm(avWave)
			avWave /= rr // normalise
			e_avWave[i][] = avWave[0][q]
			e_rWave[i] = rr
			// make proposed endpoint then vector
			Make/O/FREE/N=(1,3) prWave = {{wx},{wy},{zt}}
			prWave /= rr
			prWave[0][] += mpWave[0][q]
			e_prWave[i][] = prWave[0][q]
			MatrixOp/O/FREE interMat = avWave . prWave
			e_angleWave[i] = acos(interMat[0])
		else
			e_avWave[i][] = NaN
			e_prWave[i][] = NaN
			e_rWave[i] = NaN
			e_angleWave[i] = NaN
		endif
	endfor
End
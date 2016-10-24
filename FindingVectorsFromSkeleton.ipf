#pragma TextEncoding = "MacRoman"		// For details execute DisplayHelpTopic "The TextEncoding Pragma"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// Menu item for easy execution
Menu "Macros"
	Submenu "Spatial Analysis"
	"MTs2Vectors...",  MTs2Vectors()
	"Remake Report", TidyAndReport()
	"Redo Ellipse Comparison", ReDoElliAnalysis()
	End
End

// Workflow to load and analyse a dataset from set of TIFFs through to report
Function MTs2Vectors()
	if(ProcessTIFFs() == -1)
		Print "Error"
		Return 0
	endif
	Variable timer = startmstimer
	Polarise()
	segWrapper()
	elliWrapper()
	printf "%g\r", stopmstimer(timer)/1e6
	MakeMaps()
	TidyAndReport()
End

// Workflow to just reanalyse the data
Function ReDoElliAnalysis()
	elliWrapper()
	TidyAndReport()
End

// Loads and processes a folder of TIFFs
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

// This pulls the skeletons out from each TIFF and sends to TheFitter
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

// Fits a 2D line to the skeleton and uses this as a vec* wave
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
	endif
	KillWaves fit_tempYw
End

// Orients vectors away from the nearest spindle pole
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
	Variable nearest
	Make/O/N=(nVectors)/T pol_Name	// name of vector wave
	Make/O/N=(nVectors) pol_Des	// which spindle pole is it from
	Make/O/N=(nVectors) pol_Rev	// did the polarity get reversed?
	Make/O/N=(nVectors) pol_Angle // what is the angle relative to the spindle axis?
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
			ABx = sp2X - sp1X
			CDx = w0[1][0] - w0[0][0]
			ABy = sp2Y - sp1Y
			CDy = w0[1][1] - w0[0][1]
			pol_Angle[i] = (atan2(ABy,ABx) - atan2(CDy,CDx)) * (180/pi)
		else
			pol_Des[i] = 2
			if(sp2_A >= sp2_B)
				Reverse/DIM=0 w0
				pol_Rev[i] = 1
			else
				pol_Rev[i] = 0
			endif
			ABx = sp1X - sp2X
			CDx = w0[1][0] - w0[0][0]
			ABy = sp1Y - sp2Y
			CDy = w0[1][1] - w0[0][1]
			pol_Angle[i] = (atan2(ABy,ABx) - atan2(CDy,CDx)) * (180/pi)
		endif
		
		if(pol_Angle[i] > 180)
			pol_Angle[i] -= 360
		elseif(pol_angle[i] < -180)
			pol_Angle[i] += 360
		endif
	endfor
End

Function MakeMaps()

	NVAR /Z xySize = gpxSize
	WAVE spWave,pol_Angle,pol_Des,segAngleWave,e_angleWave
	WAVE/T e_nameWave

	DoWindow/K allPlot // for back compatability
	DoWindow/K polePlot
	Display /N=polePlot
	DoWindow/K elliPlot
	Display /N=elliPlot
	
	String vecList = WaveList("vec_*",";","")
	String wName
	Variable nVec = ItemsInList(vecList)
	
	Variable i
	
	for(i = 0; i < nVec; i += 1)
		wName = StringFromList(i,vecList)
		AppendToGraph/W=polePlot $wName[][1] vs $wName[][0]
		AppendToGraph/W=elliPlot $wName[][1] vs $wName[][0]
	endfor
 
	vecList = TraceNameList("elliPlot",";",1)
	nVec = ItemsInList(VecList)	
	
	Make/O/N=(9,3) colorWave
	colorWave[][0] = {65535,65278,65021,65021,65021,61937,55769,42662,32639}
	colorWave[][1] = {62965,59110,53456,44718,36237,26985,18504,13878,10023}
	colorWave[][2] = {60395,52942,41634,27499,15420,4883,257,771,1028}
	Variable cW
	String elliName
	
	for(i = 0; i < nVec; i += 1)	
		wName = StringFromList(i,vecList)
		elliName = ReplaceString("vec",wName,"elli")
		FindValue/TEXT=elliName e_NameWave
			if (V_Value != -1)
				cW = floor(abs(e_angleWave[V_Value])/20)
				if (numtype(cW) == 0)
					ModifyGraph/W=elliPlot rgb($wName)=(colorWave[cW][0],colorWave[cW][1],colorWave[cW][2])
				endif
			else
				RemoveFromGraph/W=elliPlot $wName
			endif
	endfor
	
	// format polePlot
	DoWindow/F polePlot
	ModifyGraph /W=polePlot rgb=(32896,32896,32896)
	AppendToGraph/W=polePlot spWave[][1] vs spWave[][0]
	ModifyGraph /W=polePlot rgb(spWave)=(65535,0,0)
	ModifyGraph/W=polePlot width={Plan,1,bottom,left}
	SetAxis/W=polePlot/R left 768*xysize,0
	SetAxis/W=polePlot bottom 0,768*xysize
	ModifyGraph mirror=1,noLabel=2,axRGB=(34952,34952,34952)
	ModifyGraph tlblRGB=(34952,34952,34952),alblRGB=(34952,34952,34952)
	ModifyGraph margin=14
	SavePICT/WIN=polePlot/E=-5/RES=300/TRAN=1/W=(0,0,392,392) as "Clipboard"
	LoadPICT/O/Q "Clipboard", polePic
	KillWindow/Z polePlot
	
	// format elliPlot
	DoWindow/F elliPlot
	ModifyGraph/W=elliPlot gbRGB=(32896,32896,32896)
	ModifyGraph/W=elliPlot width={Plan,1,bottom,left}
	SetAxis/W=elliPlot/R left 768*xysize,0
	SetAxis/W=elliPlot bottom 0,768*xysize
	ModifyGraph mirror=1,noLabel=2,axRGB=(34952,34952,34952)
	ModifyGraph tlblRGB=(34952,34952,34952),alblRGB=(34952,34952,34952)
	ModifyGraph margin=14
	SavePICT/WIN=elliPlot/E=-5/RES=300/TRAN=1/W=(0,0,392,392) as "Clipboard"
	LoadPICT/O/Q "Clipboard", elliPic
	
	vecList = TraceNameList("elliPlot",";",1)
	nVec = ItemsInList(VecList)	
	
	for(i = 0; i < nVec; i += 1)	
		wName = StringFromList(i,vecList)
		elliName = ReplaceString("vec",wName,"elli")
		FindValue/TEXT=elliName e_NameWave
			if (e_angleWave[V_Value] < 20)
				RemoveFromGraph/W=elliPlot $wName
			endif
	endfor
	
	SavePICT/WIN=elliPlot/E=-5/RES=300/TRAN=1/W=(0,0,392,392) as "Clipboard"
	LoadPICT/O/Q "Clipboard", wonkPic
	KillWindow/Z elliPlot
End

// Creates PDF report of all the analysis
Function TidyAndReport()
	NVAR /Z xySize = gpxSize
	WAVE spWave,pol_Angle,pol_Des,segAngleWave,e_angleWave
	SVAR expCond = TIFFtitle
 
	MakeMaps()
	
	// leave histlist like this in the case where code is run on a very old pxp
	String histList = "sp1Hist;sp2Hist;allHist;allposHist;segAngleHist;segposHist;elliHist;"
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
	Concatenate/O {pol_Angle_1,pol_Angle_2}, pol_Angle_all
	Duplicate/O pol_Angle_all pol_Angle_all_pos
	pol_Angle_all_pos = abs(pol_Angle_all[p])
	Make/N=180/O pol_Angle_all_pos_Hist
	Histogram/B={0,2,90} pol_Angle_all_pos,pol_Angle_all_pos_Hist
	Display/N=allposHist pol_Angle_all_pos_Hist
	ModifyGraph/W=allposHist rgb=(32767,32767,32767)
	TextBox/C/N=text0/F=0/A=RT/X=0.00/Y=0.00 "Spindle axis"
	
	Duplicate/O segAngleWave segAngleWave_all
	Duplicate/O segAngleWave_all segAngleWave_all_pos
	segAngleWave_all_pos = abs(segAngleWave_all[p])
	Make/N=90/O seg_angle_pos_Hist
	Histogram/B={0,2,90} segAngleWave_all_pos,seg_angle_pos_Hist
	Display/N=segposHist seg_angle_pos_Hist
	ModifyGraph/W=segposHist rgb=(32768,32770,65535)
	TextBox/C/N=text0/F=0/A=RT/X=0.00/Y=0.00 "Nearest MT segments"
	
	Make/N=90/O e_angleWave_Hist
	Histogram/B={0,2,90} e_angleWave,e_angleWave_Hist
	Display/N=elliHist e_angleWave_Hist
	ModifyGraph/W=elliHist rgb=(65535,43688,32768)
	TextBox/C/N=text0/F=0/A=RT/X=0.00/Y=0.00 "Ellipse comparison"
	
	DoWindow /K summaryLayout
	NewLayout /N=summaryLayout
	AppendLayoutObject /W=summaryLayout picture polePic
	AppendLayoutObject /W=summaryLayout picture elliPic
	AppendLayoutObject /W=summaryLayout picture wonkPic
	
	histlist = "allposHist;segposHist;elliHist;"
	
	for(i = 0; i < ItemsInList(histList); i += 1)
		histName = StringFromList(i,histList)
		Label/W=$histName bottom "Relative angle (¡)"
		Label/W=$histName left "Frequency"
		ModifyGraph/W=$histName mode=5,hbFill=4
		SetAxis/W=$histName/A/N=1/E=1 left
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
	ModifyLayout left(allposHist)=300,top(allposHist)=21,width(allposHist)=180,height(allposHist)=130
	ModifyLayout left(segposHist)=300,top(segposHist)=171,width(segposHist)=180,height(segposHist)=130
	ModifyLayout left(elliHist)=300,top(elliHist)=321,width(elliHist)=180,height(elliHist)=130
	TextBox/C/N=text0/F=0/A=RB/X=0.00/Y=0.00 expCond
	ModifyLayout left(polePic)=21,top(polePic)=21,width(polePic)=250,height(polePic)=250
	ModifyLayout left(elliPic)=21,top(elliPic)=285,width(elliPic)=250,height(elliPic)=250
	ModifyLayout left(wonkPic)=21,top(wonkPic)=551,width(wonkPic)=250,height(wonkPic)=250
	SavePICT/E=-2 as expCond + ".pdf"
End

// Analysis of short MT segments within 120 nm of one another
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
	
	// exclude short MT segments on the basis of length (60 nm)
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
							if(segDistWave[l] < 120)	// neighbour segments less than 120 nm apart are analysed
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
End

// Function to find the distance between two MT segments (at closest approach)
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

// Function to find the angle between two MT segments
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

// Function to compare midpoint of MT segment to ellipsoid tangent
Function elliWrapper()
	// first get list of eligible vectors
	WAVE/Z segLengthWave
	WAVE/T/Z segLabelWave
	Variable nWaves = numpnts(segLengthWave)
	String mName, matList = ""
	Variable i
	
	for(i = 0; i < nWaves; i += 1)
		if(segLengthWave[i] > 60)
			matList = matList + segLabelWave[i] + ";"
		endif
	endfor
	
	WAVE spWave
	// find spindle midpoint, c
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
	Variable nVec = ItemsInList(matList)
	String newName
	Variable zt
	Make/O/N=(nVec,3) e_mpWave,e_avWave,e_prWave // midpoint, actual vector, proposed vector
	Make/O/N=(nVec) e_rWave,e_angleWave
	Make/O/N=(nVec)/T e_nameWave
	Variable rr // length of vector for normalisation
	
	for(i = 0; i < nVec; i += 1)
		mName = StringFromList(i,matList)
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
		// find midpoint
		wx = (m1[0][0] + m1[1][0]) / 2
		wy = (m1[0][1] + m1[1][1]) / 2
		wz = (m1[0][2] + m1[1][2]) / 2
		Make/O/FREE/N=(1,3) mpWave = {{wx},{wy},{wz}}
		e_mpWave[i][] = mpWave[0][q]
		// removing this exclusion criteria // if(norm(mpWave) < cc)
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
		rr = norm(prWave)
		prWave /= rr
		e_prWave[i][] = prWave[0][q]
	endfor
	
	PutEllipseBack(matList,cx,cy,cz)
	
	WAVE/Z vec3D,elli3Dre
	nVec = dimsize(vec3D,0)
	Make/O/N=(nVec/3,3) matvA,matvB,mateA,mateB
	Variable j=0
	
	for(i = 0; i < nVec/3; i += 1)
		matvA[i][] = vec3D[j][q]
		matvB[i][] = vec3D[j+1][q]
		mateA[i][] = elli3Dre[j][q]
		mateB[i][] = elli3Dre[j+1][q]
		j += 3
	endfor
	
	// subtract to get vectors
	matvB[][] -= matvA[p][q]
	mateB[][] -= mateA[p][q]
	// project onto z = 0
	matvB[][2] = 0
	mateB[][2] = 0
	
	nVec = dimsize(matvB,0)
	Variable tempvar
	
	for(i = 0; i < nVec; i += 1)
		MatrixOp/O/FREE avWave = row(matvB,i)
		MatrixOp/O/FREE prWave = row(mateB,i)
		MatrixOp/O/FREE interMat = avWave . prWave
		tempvar = norm(avWave) * norm(prWave)
		interMat /=tempvar
		e_angleWave[i] = acos(interMat[0])
	endfor
	e_angleWave *= (180 / pi)
End

// Function to lay the spindle back down so that projection can be done
////	@param	eList	string with wavelist of eligible vec_ waves
////	@param	cx		coords for c, the midpoint of p1 and p2
////	@param	cy		coords for c, the midpoint of p1 and p2
////	@param	cz		coords for c, the midpoint of p1 and p2
Function PutEllipseBack(matList,cx,cy,cz)
	String matList
	Variable cx,cy,cz
	
	String elliList = ReplaceString("vec_",matList,"elli_")
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
	Duplicate/O e_avWave2, e_avWaveEP
	e_avWaveEP += e_mpWave[p][q] // new endpoint
	Duplicate/O e_mpWave, e_avWaveSP
	e_avWaveSP -= e_avWave21[p][q] // new startpoint
	
	Duplicate/O e_prWave, e_prWave2
	e_prWave2 *= e_rWave[p]
	Duplicate/O/FREE e_prWave2, e_prWave21
	Duplicate/O e_prWave2, e_prWaveEP
	e_prWaveEP += e_mpWave[p][q] // new endpoint
	Duplicate/O e_mpWave, e_prWaveSP
	e_prWaveSP -= e_prWave21[p][q] // new startpoint

	nRows = DimSize(e_avWave,0)
	Make/O/N=(nRows*3,3) vec3Dre,elli3Dre
	
	for(i = 0; i < nRows *3; i +=3)
		vec3Dre[i][] = e_avWaveSP[j][q]
		vec3Dre[i+1][] = e_avWaveEP[j][q]
		vec3Dre[i+2][] = NaN
		
		elli3Dre[i][] = e_prWaveSP[j][q]
		elli3Dre[i+1][] = e_prWaveEP[j][q]
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
	
	elli3Dre[][0] += cx
	elli3Dre[][1] += cy
	elli3Dre[][2] += cz
	
	KillWaves vec3Dre,elli3D,e_avWave2,e_prWave2
End
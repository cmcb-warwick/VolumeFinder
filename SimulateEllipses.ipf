#pragma TextEncoding = "MacRoman"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

// These functions make a set of uniformly randomly distributed points
// generate elliptical segments off these points and plot them our for display
Function DoSim(num)
	Variable num
	UniformSphere(num,1)
	DoEllipse(num)
	PlotIt()
End

Function UniformSphere(num,Radius)
	Variable num,Radius

	Make/O/N=(num) xw,yw,zw
	Variable phi,theta,rr

	Variable i

	for(i = 0; i < num; i += 1)
		phi = pi + enoise(pi)
		theta = acos(enoise(1))
		rr = Radius * ((0.5 + enoise(0.5))^(1/3))
		xw[i] = rr * sin(theta) * cos(phi)
		yw[i] = rr * sin(theta) * sin(phi)
		zw[i] = rr * cos(theta)
	endfor
End

Function DoEllipse(num)
	Variable num
	WAVE/Z xw,yw,zw
	if(!WaveExists(xw))
		Abort "Missing wave"
	endif
	Concatenate/O {xw,yw,zw}, pointw
	Make/o/n=(num) ztrans,normw
	ztrans = (zw[p]^2 - 1) / zw[p]
	Concatenate/O {xw,yw,ztrans}, pointw_t
	normw = sqrt(pointw_t[p][0]^2 + pointw_t[p][1]^2 + pointw_t[p][2]^2)
	pointw_t /= normw[p] * 4
	MatrixOp/O newpointw = pointw_t + pointw
End

Function PlotIt()
	WAVE pointw,newpointw
	Variable nWaves = dimsize(newpointw,0)
	String wName
	DoWindow/K xzplot
	Display/N=xzplot
	DoWindow/K yzplot
	Display/N=yzplot
	DoWindow/K xyplot
	Display/N=xyplot
	Variable i

	for(i = 0; i < nWaves; i += 1)
		wName = "vec_xz_" + num2str(i)
		Make/O/N=(2,2) $wName
		Wave w0 = $wName
		w0[0][0] = pointw[i][0]
		w0[0][1] = pointw[i][2]
		w0[1][0] = newpointw[i][0]
		w0[1][1] = newpointw[i][2]
		AppendToGraph/W=xzplot w0[][1] vs w0[][0]
		//
		wName = "vec_yz_" + num2str(i)
		Make/O/N=(2,2) $wName
		Wave w0 = $wName
		w0[0][0] = pointw[i][1]
		w0[0][1] = pointw[i][2]
		w0[1][0] = newpointw[i][1]
		w0[1][1] = newpointw[i][2]
		AppendToGraph/W=yzplot w0[][1] vs w0[][0]
		//
		wName = "vec_xy_" + num2str(i)
		Make/O/N=(2,2) $wName
		Wave w0 = $wName
		w0[0][0] = pointw[i][0]
		w0[0][1] = pointw[i][1]
		w0[1][0] = newpointw[i][0]
		w0[1][1] = newpointw[i][1]
		AppendToGraph/W=xyplot w0[][1] vs w0[][0]
	endfor
	DoWindow/F xzplot
	SetAxis left -1,1;DelayUpdate
		SetAxis bottom -1,1
	SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0;DelayUpdate
		DrawOval -1,1,1,-1
	ModifyGraph width={Plan,1,bottom,left}
	SetAxis left -1,1;DelayUpdate
	SetAxis bottom -1,1;DelayUpdate
	ModifyGraph mirror=1
	Label left "z";DelayUpdate
	Label bottom "y"

	DoWindow/F yzplot
	SetAxis left -1,1;DelayUpdate
		SetAxis bottom -1,1
	SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0;DelayUpdate
		DrawOval -1,1,1,-1
	ModifyGraph width={Plan,1,bottom,left}
	SetAxis left -1,1;DelayUpdate
	SetAxis bottom -1,1;DelayUpdate
	ModifyGraph mirror=1
	Label left "z";DelayUpdate
	Label bottom "x"

	DoWindow/F xyplot
	SetAxis left -1,1;DelayUpdate
		SetAxis bottom -1,1
	SetDrawEnv xcoord= bottom,ycoord= left,fillpat= 0;DelayUpdate
		DrawOval -1,1,1,-1
	ModifyGraph width={Plan,1,bottom,left}
	SetAxis left -1,1;DelayUpdate
	SetAxis bottom -1,1;DelayUpdate
	ModifyGraph mirror=1
	Label left "y";DelayUpdate
	Label bottom "x"
End

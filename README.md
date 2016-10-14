# VolumeFinder
Procedures for volume analysis and spatial statistics of 3D point sets in IgorPro.

Two types of analysis are possible

1. [**Volume analysis**](#volume-analysis) <code>VolumeFinder.ipf</code>
2. [**Spatial statistics**](#spatial-statistics) <code>FindingVectorsFromSkeleton.ipf</code>

Microtubules are first segmented in Amira. Amira mesh files are converted to TIFFs and skeletons using a FIJI macro [am2skel.ijm](https://github.com/quantixed/VolumeFinder/blob/master/am2skel.ijm). This process .am files to first threshold them and produce categorised 1 px thick MT trajectories in 2D (one for each z-slice). These are called skeletons. The thresholded TIFFs are used for Volume Analysis and the skeletons are used for Spatial Statistics.

###Volume analysis
This workflow measures the density of microtubules in a stack of TIFFs. Igor will compute the volume of microtubules as a density of the volume in which they are contained. This was written for analysis of segmented data from SBF-SEM (3View). 

To do this call <code>VolumeFinder()</code>. Now, point Igor at the directory containing the TIFFs.
You can scale the output to real world values using <code>ScaleIt(xnm,ynm,znm)</code>. Using the correct voxel size. This will scale the point volumes and hull volumes to µm^3.

Caution:

* Igor 7 only. Removed the ability to run in Igor 6.3

###Spatial Statistics

Skeletons are processed by Igor <code>FindingVectorsFromSkeleton.ipf</code> to form 2D vectors which can then be used for spatial statistical analysis. Vectors are found by a linear fit to xy coordinates.

Igor will produce a report which shows three spatial statistics:

* A comparison of all MT vectors with the spindle axis (defined by two xyz coords at the start of the procedure). This is colour coded (with a key) to show variance in angle from the spindle axis. Histograms summarise this information (4 histograms: 1 for each pole, 1 for all angles, 1 for all angles, abs() values).
* Two further histograms compare MTs that are longer than 60 nm are within 80 nm of other MTs. This is independent of the spindle axis.
* A comparison between the trajectories of MT segments with ellipsoid tangents calculated from an idealised spindle.

Each cell/movie is analysed as a separate pxp. Use [SummaryPXP.ipf](https://github.com/quantixed/VolumeFinder/blob/master/SummaryPXP.ipf) to make a summary report of all your data. Compare distributions using the command `MakeComparison()`.

####Extra code

A little tool called `checkAxis.ipf` was developed to help visualise and correct spindle axis in 3D via gizmo. Current workflow is to: 1. run the load and analysis (using input coordinates for poles); 2. use checkaxis to refine the axis (for all datasets); 3. redo the analysis.

A toy called `SimulateEllipses.ipf` was developed to model idealised spindles as ellipsoid tangents.

Some extra procedures can be found in `VectorAuxProcs.ipf`. The most useful of these is `CompareAlphaAll()` which is a statistical method to compare two distributions. Comparisons for all combinations of experimental conditions are carried out. Needs e_AngleWaves from various experiments combinining into single AngleWave waves per condition. This is now incorporated into `SummaryPXP.ipf`. Another method is `UseLineModel()` which will compare MT segments to a diamond/straight-line model of spindle. Comparison of these angle distributions with those against the ellipsoid tangents is produced.
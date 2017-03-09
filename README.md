# VolumeFinder
Procedures for volume analysis and spatial statistics of 3D point sets in IgorPro. A detailed walkthrough of the analysis procedure is available [here](https://github.com/quantixed/VolumeFinder/blob/master/volumefinder-analysis-3d.pdf). This README contains a brief overview.

Two types of analysis are possible

1. [**Volume analysis**](#volume-analysis)
2. [**Spatial statistics**](#spatial-statistics)

Microtubules are first segmented in Amira. Amira mesh files are converted to TIFFs and skeletons using a FIJI macro [am2skel.ijm](https://github.com/quantixed/VolumeFinder/blob/master/am2skel.ijm). This process .am files to first threshold them and produce categorised 1 px thick MT trajectories in 2D (one for each z-slice). These are called skeletons. The thresholded TIFFs are used for Volume Analysis and the skeletons are used for Spatial Statistics.

###Setup

Place all procedures in `User Procedures` directory which can be found in:

Mac: `/Users/<user>/Documents/WaveMetrics`

Windows: `C:\Users\<user>\Documents\WaveMetrics`

Load `VFMasterproc.ipf` into a new experiment and then one of the following options:

- Volume Finder
- Spatial Analysis
- All analysis
- Export to R

From the `Macros` menu.

**Caution:** Igor 7 only. Most of the code will not compile or run in Igor 6.3 and below.

###Volume analysis
This workflow measures the density of microtubules in a stack of TIFFs. Igor will compute the volume of microtubules as a density of the volume in which they are contained. This was written for analysis of segmented data from SBF-SEM (3View). 

To do this call <code>VolumeFinder()</code>. Now, point Igor at the directory containing the TIFFs.
You can scale the output to real world values using <code>ScaleIt(xnm,ynm,znm)</code>. Using the correct voxel size. This will scale the point volumes and hull volumes to µm^3.

###Spatial Statistics

Skeletons are processed by Igor <code>FindingVectorsFromSkeleton.ipf</code> to form 2D vectors which can then be used for spatial statistical analysis. Vectors are found by a linear fit to xy coordinates.

Igor will produce a report which shows three spatial statistics:

* A comparison of all MT vectors with the spindle axis (defined by two xyz coords at the start of the procedure). This is colour coded (with a key) to show variance in angle from the spindle axis. Histograms summarise this information (4 histograms: 1 for each pole, 1 for all angles, 1 for all angles, abs() values).
* Two further histograms compare MTs that are longer than 60 nm are within 80 nm of other MTs. This is independent of the spindle axis.
* A comparison between the trajectories of MT segments with ellipsoid tangents calculated from an idealised spindle.

Each cell/movie is analysed as a separate pxp. Use [SummaryPXP.ipf](https://github.com/quantixed/VolumeFinder/blob/master/SummaryPXP.ipf) to make a summary report of all your data. Compare distributions using the command `MakeComparison()`.

####Extra code

A little tool called `checkAxis.ipf` was developed to help visualise and correct spindle axis in 3D via gizmo. Current workflow is to: 1. run the load and analysis (using input coordinates for poles); 2. use checkaxis to refine the axis (for all datasets); 3. redo the analysis.

###Analysis using R

The analysis can be reproduced in R. Simply use this [R markdown file](https://github.com/quantixed/VolumeFinder/blob/master/Mitotic_spindle_modelling.Rmd), following the instructions [here](https://github.com/quantixed/VolumeFinder/blob/master/Mitotic_spindle_modelling.html). The analysis in R requires the xyz coordinates of the start and end points of all lines generated from the skeletons. These coordinates can be output in csv format using [ExportToR.ipf](https://github.com/quantixed/VolumeFinder/blob/master/ExportToR.ipf), see the instructions for further details. Alternatively, you may use some other non-Igor workflow to get the coordinates and run the analysis in R.

###Calculation of SNR

An [ImageJ macro](https://github.com/quantixed/VolumeFinder/blob/master/SNR3View.ijm) will extract the mean pixel density in segmented MT regions (per slice) and calculate the SD of a halo around the MTs (excluding MTs themselves), SNR is calculated and output as a csv. [Igor code](https://github.com/quantixed/VolumeFinder/blob/master/SNR3View.ipf) Igor code is available to crunch the output.
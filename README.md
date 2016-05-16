# VolumeFinder
This repo has procedures for volume analysis and spatial statistics of 3D point sets in IgorPro.

Two FIJI/Igor paired scripts represent two workflows

1. <code>VolumeFinder.ipf</code> & <code>amThreshTiff.ijm</code>
2. <code>FindingVectorsFromSkeleton.ipf</code> & <code>BathSkeletonAnalysis.ijm</code>

###Volume analysis
This code is to measure the density of microtubules in a stack of TIFFs. Microtubules are first segmented in Amira and then converted to TIFFs using a FIJI macro. Finally, Igor will work out the volume of the microtubules as a density of the volume in which they are contained. 

1. Segmentation is first done in Amira. Segmented microtubule labels have the value 2.
2. Amira files are thresholded and converted to TIFF in FIJI using the [amThreshTiff.ijm](https://github.com/quantixed/VolumeFinder/blob/master/amThreshTiff.ijm) macro
3. These TIFFs are batch-processed by Igor

To do this call <code>VolumeFinder(2)</code>. Option 2 specifies the fastest calculation method. Now point Igor at the directory containing the TIFFs.
You can scale the output to real world values using <code>ScaleIt(xnm,ynm,znm)</code>. This will scale the point volumes and hull volumes to µm^3.

Caution:
* For best performance /VOL flag is used, only available in Igor 7 Beta 6
* Code will compile in Igor 6.3+ but will use a slower method
* Option 0 is the most straightforward, but is very slow. Benchmarking with <code>tic()</code> <code>toc()</code> timed a complicated data set (768 x 768 x 500, 1.2 x 10^6 points) at ~3 h on a Mac Pro 6 Core. Option 2 speeds this to ~90 s.

###Spatial Statistics
Again Amira mesh files are used as a starting point. The FIJI script will process these to produce categorised 1 px thick MT trajectories in 2D (one for each z-slice). These are called skeletons. Skeletons are processed by Igor to form 2D vectors which can then be used for spatial statistical analysis. Igor will print a report which shows a comparison of all MT vectors with the spindle axis (defined by two xyz coords at the start of the procedure). This is colour coded (with a key) to show variance in angle from the spindle axis. Histograms summarise this information (4: 1 for each pole, 1 for all angles, 1 for all angles, abs values). Two further histograms compare MTs that are longer than 60 nm within 80 nm of other MTs. This is independnet of the spindle axis.

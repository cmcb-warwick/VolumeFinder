# VolumeFinder
Volume analysis of 3D point sets in IgorPro

This code is to measure the density of microtubules in a stack of TIFFs. Microtubules are first segmented in Amira and then converted to TIFFs using a FIJI macro. Finally, Igor will work out the volume of the microtubules as a density of the volume in which they are contained. 

1. Segmentation is first done in Amira. Segmented microtubule labels have the value 2.
2. Amira files are thresholded and converted to TIFF in FIJI using the [amThreshTiff.ijm](https://github.com/quantixed/VolumeFinder/blob/master/amThreshTiff.ijm) macro
3. These TIFFs are batch-processed by Igor

To do this call <code>VolumeFinder(0)</code>. 0 specifies the fastest calculation method. Point Igor at the directory containing the TIFFs.

Caution:
* This code is very slow at present. Benchmarking with <code>tic()</code> <code>toc()</code> timed a complicated data set (768 x 768 x 500, 1.2 x 10^6 points) at ~3 h on a Mac Pro in Igor 7
* For best performance /VOL flag is used, only available in the latest build of Igor 7 beta

The BCCH samples are stored in Matlab .mat files where the name of the
mat file is the ARFCN number, e.g. 50.mat for ARFCN 50. Inside the mat
file there is a variable named bb_data containing complex valued I-Q
samples at symbol rate of at least 8 multi-frames.

When inserting new ARFCNs the constants in GsmPhy.m need to be adapted
accordingly.

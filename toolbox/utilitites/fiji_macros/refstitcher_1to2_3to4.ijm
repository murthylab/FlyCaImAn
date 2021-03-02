// This function will stitch videos in 1-n order
args=getArgument()
args=split(args,"*") 
FileDir=args[0];
FileName=args[1];
FNum=args[2];
ch2use=args[3];
p_width=args[4];
p_heigh=args[5];
p_depth=args[6];
peak_num=args[7];
init_x=args[8];
init_y=args[9];
init_z=args[10];
init_xb=args[11];
init_yb=args[12];
init_zb=args[13];
fusion_method=args[14];
Debugflag=args[15];
im_format=args[16];

// open files and reshape them
print("Collecting all stacks to stitch");

for (i=1; i<=FNum; i++) {
    imName = FileName + "_" + i + im_format;
    print("reshaping image: " + imName);
    open(FileDir + imName);
    selectWindow(imName);
    run("Properties...", "unit=microns pixel_width=" + p_width + " pixel_height=" + p_heigh + " voxel_depth=" + p_depth);
    getDimensions(w, h, channels, slices, frames);
    z = slices/2; // assumes that the volume has 2 channels
    run("Stack to Hyperstack...", "order=xyczt(default) channels=2 slices=" + z + " frames=1 display=Color");
    setMinAndMax(0, 2050);
}

print("Done");

// Choose fusion method
if (fusion_method==0){
    method = " fusion_method=[Linear Blending] ";
    print("Using Linear Blending");
}

if (fusion_method==1){
    method = " fusion_method=[Max. Intensity] ";
    print("Using Max. Intensity");
}

// stitch 1 and 2-3

peakNum = " check_peaks=" + peak_num;
posInit = " compute_overlap x=" + init_x + " y=" + init_y + " z=" + init_z;
print(posInit);
print(peakNum);

if (ch2use==2){
    ch2reg = " registration_channel_image_1=[Only channel 2] registration_channel_image_2=[Only channel 2]";
    print("Using 2nd channel or green");
} else {
    ch2reg = " registration_channel_image_1=[Only channel 1] registration_channel_image_2=[Only channel 1]";
    print("Using 1st channel or red");
}

print("Stitching all pairs");

// fusing images 1-2
im1 = "first_image=" + FileName + "_1" + im_format;
im2 = "second_image=" + FileName + "_2" + im_format;
   
newIm = " fused_image=" + FileName + "_1_a" + im_format;
print("Stitching images round 1");
order2run = im1 + " " + im2 + method + newIm + peakNum + posInit + ch2reg;
print(order2run);
run("Pairwise stitching", order2run);
selectWindow(FileName + "_1_a" + im_format);
getDimensions(w, h, channels, slices, frames);
w = w - 1;
h = h - 1;
// h = h - 20;
// h = h - 80;
run("TransformJ Crop", "x-range=0," + w + " y-range=0," + h + " z-range=1," + slices + " c-range=1,2");

// close unused windows
selectWindow(FileName + "_1" + im_format);
close();
selectWindow(FileName + "_2" + im_format);
close();
selectWindow(FileName + "_1_a" + im_format);
close();

// rename final window to be used
selectWindow(FileName + "_1_a" + im_format + " cropped");
rename(FileName + "_1_a" + im_format);

// fusing images 3-4
if (FNum>2){

    im1 = "first_image=" + FileName + "_3" + im_format;
    if (FNum==4){
        im2 = "second_image=" + FileName + "_4" + im_format;
    } else {
        im2 = "second_image=" + FileName + "_3" + im_format;
    }

    posInit = " compute_overlap x=" + init_xb + " y=" + init_yb + " z=" + init_zb;
    newIm = " fused_image=" + FileName + "_1_b" + im_format;
    print("Stitching images round 1");
    order2run = im1 + " " + im2 + method + newIm + peakNum + posInit + ch2reg;
    print(order2run);
    run("Pairwise stitching", order2run);
    selectWindow(FileName + "_1_b" + im_format);
    getDimensions(w, h, channels, slices, frames);
    w = w - 1;
    h = h - 1;

    run("TransformJ Crop", "x-range=0," + w + " y-range=0," + h + " z-range=1," + slices + " c-range=1,2");

    // close unused windows
    selectWindow(FileName + "_3" + im_format);
    close();
    if (FNum==4){
        selectWindow(FileName + "_4" + im_format);
        close();
    }

    selectWindow(FileName + "_1_b" + im_format);
    close();

    // rename final window to be used
    selectWindow(FileName + "_1_b" + im_format " cropped");
    rename(FileName + "_1_b" + im_format);

}

if (Debugflag == 1){
    waitForUser("manual checking");
}

// second round of fusion
if (FNum>2){
    im1b = "first_image=" + FileName + "_1_a" + im_format;
    im2b = "second_image=" + FileName + "_1_b" + im_format;
       
    newIm = " fused_image=" + FileName + "_1_c" + im_format;
    print("Stitching images round 2");
    run("Pairwise stitching", im1b + " " + im2b + newIm + posInit + ch2reg);

    print("Done");

    newIm = replace(newIm, " fused_image=", "");
    selectWindow(newIm);

} else {
    selectWindow(FileName + "_1_a" + im_format);
}

if (Debugflag == 1){
    waitForUser("manual checking");
}

// saving image
print("Saving files");

FinalName = FileName + im_format;

if (Debugflag == 1){
    waitForUser("manual checking");
}

if (im_format==".nrrd"){
    run("Properties...", "unit=microns pixel_width=" + p_width + " pixel_height=" + p_heigh + " voxel_depth=" + p_depth);
    run("Nrrd ... ", "nrrd=" + FileDir + FinalName);
}

if (im_format==".nii"){
    run("Properties...", "unit=Micron pixel_width=" + p_width + " pixel_height=" + p_heigh + " voxel_depth=" + p_depth);
    run("NIfTI-1", "save=" + FileDir + FinalName);
}

print("Done");
eval("script", "System.exit(0);");

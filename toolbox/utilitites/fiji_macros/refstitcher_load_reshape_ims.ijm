// This function will load and reshape videos (up to 4)
// Used for stitching debugging (it leaves fiji open)
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

run("Brightness/Contrast...");
run("Channels Tool...");

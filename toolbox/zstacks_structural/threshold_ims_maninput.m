%% 1) Edit manually input_int_ths by looking at the intensity in plotted planes

ipars.input_int_ths = [75 75 75 90 95];

% and re-run
[Data_mask, ipars.int_ths_per_z] = ...
    generate_binary_mask(ipars.input_int_ths, ...
    ipars.z_slices_per_int_ths, Data_smooth);
displayresults(Data_smooth, Data_mask, ipars)

%% 2) display results/save video

pi = [];
pi.range = [0 200];
slice3Dmatrix(double(Data).*Data_mask, pi);

pi.range = [0 500];
% pi.range = [0 10^5];
pi.Y1 = Data_mask;
pi.vgate = 1;
pi.vgate = 'test';
slice3Dmatrix(double(Data), pi);

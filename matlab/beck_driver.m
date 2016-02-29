function [Xout] = beck_driver()

addpath('./beck_FISTA_matlab_files/HNO')

X = double(imread('cameraman.pgm'));
%X = double(imread('cameraman_resize.pgm'));
X = X/255; % scale to [0,1]

[P,center] = psfGauss([9,9],4);

% generate blurred image
B=imfilter(X,P,'symmetric'); 
%B=imfilter(X,P,'circular'); 
% add some Gaussian white noise
randn('seed',314);
Bobs=B + 1e-3*randn(size(B));

% show original and observed blurred image
%figure(1)
%subplot(1,2,1)
%imshow(X,[])
%title('Original')
%subplot(1,2,2)
%imshow(Bobs,[])
%title('Blur+Noise')

% FISTA parameters
%lambda = 1e-4; % used in B+T's example code
lambda = 2e-5; % used in FISTA SIAM paper

pars.MAXITER=100; % do this many iterations
pars.fig=0; % suppress the figure while running FISTA
%pars.BC='periodic';
pars.B = 1; % TODO JMF need to look this up for CDF 9/7 wavelets

% MATLAB wavelet parameters
dwtmode('zpd', 'nodisp');

%extmode = 'zpd'
extmode = 'sym'

levels = 3;

wname  = 'db1'
dwname = 'db1';
%wname  = 'db5'  % filter length 9
%dwname = 'db5'; 
%wname  = 'bior4.4' % filter lengths 9 and 7
%dwname = 'rbio4.4'; 

L = build_wavedec_levels_2d(size(Bobs), levels, wname, extmode);

WAn = @(Y) wavelet_analysis_2d(Y, wname, extmode, levels);
WSy = @(X) wavelet_synthesis_2d(X, L, size(Bobs), wname, extmode, levels);
WSyAd = @(Y) wavelet_synthesis_adjoint_2d(Y, wname, dwname, extmode, levels);

%[Xout,fun_all]=deblur_dwt_FISTA_trans_direct(Bobs,P,center,WAn,WSy,WSyAd,lambda,pars);
[Xout,fun_all,X_iter]=deblur_dwt_FISTA_trans_direct(Bobs,P,center,WAn,WSy,WSyAd,lambda,pars);

% show the original and recovered images
figure(2)
subplot(1,2,1)
imshow(X,[])
title('Original')
subplot(1,2,2)
imshow(Xout,[])
title('Recovered')

fprintf(1, 'recovery l2-error (rel) = %e\n', norm(Xout-Bobs,'fro')/norm(Bobs,'fro'));
fprintf(1, 'recovery nnz (%%nnz) = %d (%3.2f)\n', sum(abs(X_iter(:))>0),sum(abs(X_iter(:))>0)/numel(X_iter)*100);
%fprintf(1, 'recovery %%(big coeffs) = %3.2f\n', sum(abs(X_iter(:)) > 1e-4)/numel(X_iter)*100);

% show the recovered image and some other info
figure(3)
imshow(Xout,[])
%title(sprintf('Recovered - iter=%d, wname=''%s'', extmode=''%s''', pars.MAXITER, wname, extmode));

% Plot the decay of non-zero values in wavelet coeffs
%figure(4);
%wc = sort(abs(X_iter(:)),'descend');
%semilogy(wc);
%axis([0 1e5 1e-10 1e2]);

end


function [X] = wavelet_analysis_2d(Y, wname, extmode, levels)

   lY = size(Y);
   if numel(lY) == 1
      lY = [lY(1) lY(1)];
   elseif numel(lY) > 2 || numel(lY) == 0
      error('lY should have at most 2 entries')
   end
   
   assert(levels >= 1, 'Number of decomposition levels should be >= 1.');
   assert(levels <= wmaxlev(lY(1), wname), 'Number of decomposition levels too high.');
   assert(levels <= wmaxlev(lY(2), wname), 'Number of decomposition levels too high.');
   
   [Lo_D, Hi_D] = wfilters(wname, 'd'); % decomp filters
   lf = length(Lo_D);
  
   dwtmode('zpd', 'nodisp'); % wavedec2 doesn't take the 'mode' arg like (i)dwt2
   Ye = wextend('2D', extmode, Y, lf-1, 'b');
   [X,L] = wavedec2(Ye, levels, wname);

end

function [Y] = wavelet_synthesis_2d(X, L, lY, wname, extmode, levels)

   %lX = size(X);
   %if numel(lX) == 1
   %   lX = [lX(1) lX(1)];
   %elseif numel(lX) > 2 || numel(lX) == 0
   %   error('lX should have at most 2 entries')
   %end
   %
   %assert(levels >= 1, 'Number of decomposition levels should be >= 1.');
   %assert(levels <= wmaxlev(lX(1), wname), 'Number of decomposition levels too high.');
   %assert(levels <= wmaxlev(lX(2), wname), 'Number of decomposition levels too high.');
   
   [Lo_D, Hi_D] = wfilters(wname, 'd'); % decomp filters
   lf = length(Lo_D);
  
   dwtmode('zpd', 'nodisp'); % wavedec2 doesn't take the 'mode' arg like (i)dwt2
   Ye = waverec2(X, L, wname);
   %lY = L(end,:);  % L coming from our build_wavedec_levels accounts for extension!
   Y = extension_pinv_2d(Ye, lY, lf-1, extmode);

end

function [X] = wavelet_synthesis_adjoint_2d(Y, wname, dwname, extmode, levels)

   lY = size(Y);
   if numel(lY) == 1
      lY = [lY(1) lY(1)];
   elseif numel(lY) > 2 || numel(lY) == 0
      error('lY should have at most 2 entries')
   end
   
   assert(levels >= 1, 'Number of decomposition levels should be >= 1.');
   assert(levels <= wmaxlev(lY(1), wname), 'Number of decomposition levels too high.');
   assert(levels <= wmaxlev(lY(2), wname), 'Number of decomposition levels too high.');
   
   [Lo_D, Hi_D] = wfilters(wname, 'd'); % decomp filters
   lf = length(Lo_D);
  
   dwtmode('zpd', 'nodisp'); % wavedec2 doesn't take the 'mode' arg like (i)dwt2
   %Ye = wextend('2D', extmode, Y, lf-1, 'b'); % temp: this is "close" to adjoint of pinv
   Ye = extension_pinv_adjoint_2d(Y, lY, lf-1, extmode);
   [X,L] = wavedec2(Ye, levels, dwname);

end


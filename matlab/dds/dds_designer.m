function [N,M]=dds_designer(fref,fres,fmax,ftarget)
    M=ceil(log2(fmax/fres));
    N=ceil(log2(fmax*2^M/fref));
    disp(sprintf('M=%d, N=%d',M,N));
    
    dphi=ftarget*2^M/fref;
    fh=ceil(dphi)*fref/2^M;
    fl=floor(dphi)*fref/2^M;
    disp(sprintf('High: dphi=%d, fout=%0.2f, %% error=%.5f',ceil(dphi),fh,100*abs(fh-ftarget)/ftarget));
    disp(sprintf('Low: dphi=%d, fout=%0.2f, %% error=%.5f',floor(dphi),fl,100*abs(fl-ftarget)/ftarget));
    if(abs(fh-ftarget)>abs(fl-ftarget))
        disp(sprintf('Optimal low-side reference: dphi=%d',floor(dphi)));
    else
        disp(sprintf('Optimal high-side reference: dphi=%d',ceil(dphi)));
    end
end
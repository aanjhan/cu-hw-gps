function fft_plot(signal,fs)
    plot(linspace(-fs/2,fs/2,length(signal)),abs(fftshift(fft(signal))));
end
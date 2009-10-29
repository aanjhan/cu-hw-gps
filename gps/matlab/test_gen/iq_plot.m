function iq_plot(data)
    plot(data(:,1),data(:,2),'x');
    title('I/Q Accumulation Plot');
    xlabel('In-Phase (I)');
    ylabel('Quadrature (Q)');
    
    xmax=max(abs(data(:,1)));
    ymax=max(abs(data(:,2)));
    
    axis([-xmax xmax -ymax ymax]);
    
    return;
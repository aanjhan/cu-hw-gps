function integer log2;
   input integer value;

   begin
      if(value==0)log2=1;
      else begin
         for(log2=0;value>0;log2=log2+1)
           value=value>>1;
      end
   end
endfunction

function integer max_width;
   input integer value;
   max_width=log2(value);
endfunction // max_width

function integer max_value;
   input integer width;

   begin
      max_value = (1<<width)-1;
   end
endfunction // max_value
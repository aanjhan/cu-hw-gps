function integer max_width;
   input integer value;

   begin
      if(value==0)max_width=1;
      else begin
         for(max_width=0;value>0;max_width=max_width+1)
           value=value>>1;
      end
   end
endfunction // max_width

function integer max_value;
   input integer width;

   begin
      max_value = (1<<width)-1;
   end
endfunction // max_value
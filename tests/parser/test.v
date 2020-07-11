module mymodule #(
   parameter APARAM = 2,
   parameter signed [4:0] BPARAM = 2
) (
   input wire clk_i
);

(* mark_debug = "true" *) reg areg;

always @   begin
   areg <= 1'b1;
end

endmodule

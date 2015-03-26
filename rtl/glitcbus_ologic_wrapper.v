`timescale 1ns / 1ps

module glitcbus_ologic( input TFF_T1,
								output TFF_TQ,
								input TFF_TCE,
								input OFF_D1,
								input OFF_OCE,
								output OFF_OQ,
								input CLK);
								
	reg output_ff = 0;
	reg trist_ff = 0;
	always @(posedge CLK) begin
		if (OFF_OCE) output_ff <= OFF_D1;
		if (TFF_TCE) trist_ff <= TFF_T1;
	end
	
	assign TFF_TQ = trist_ff;
	assign OFF_OQ = output_ff;
	
endmodule

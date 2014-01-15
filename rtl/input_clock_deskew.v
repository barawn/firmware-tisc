`timescale 1ns / 1ps
module input_clock_deskew(
		input I,
		input IB,
		output O,
		output OB
    );

	parameter DEVICE = "7SERIES";
	parameter DIFF_PAIR = "TRUE";
	parameter DIFF_OUT = "TRUE";

	wire I_buffered;
	generate
		if (DIFF_PAIR == "TRUE") begin : DIFF_PAIR
			IBUFGDS i_ibufgds(.I(I),.IB(IB),.O(I_buffered));
		end else begin : SE
			IBUFG i_ibufg(.I(I),.O(I_buffered));
		end
	endgenerate
	
	generate
		if (DEVICE == "7SERIES") begin : MMCME2
			wire I_feedback_out;
			wire I_feedback_out_b;
			MMCME2_BASE deskew_mmcm(.CLKIN1(I_buffered),
											.CLKFBOUT(I_feedback_out),
											.CLKFBOUTB(I_feedback_out_b),
											.CLKFBIN(O));
			if (DIFF_OUT == "TRUE") begin : DIFF_OUT
				BUFG o_bufg(.I(I_feedback_out),.O(O));
				BUFG ob_bufg(.I(I_feedback_out_b),.O(OB));
			end else begin : SE_OUT
				BUFG o_bufg(.I(I_feedback_out),.O(O));
			end
		end else if (DEVICE == "SPARTAN6") begin : DCM_SP
			wire I_feedback_out;
			wire I_feedback_out_b;
			DCM_SP deskew_dcm(.CLKIN(I_buffered),
									.CLK0(I_feedback_out),
									.CLK180(I_feedback_out_b),
									.CLKFB(O));
			if (DIFF_OUT == "TRUE") begin : DIFF_OUT
				BUFG o_bufg(.I(I_feedback_out),.O(O));
				BUFG ob_bufg(.I(I_feedback_out_b),.O(OB));
			end else begin : SE_OUT
				BUFG o_bufg(.I(I_feedback_out),.O(O));
			end
		end
	endgenerate
											
endmodule

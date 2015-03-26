`timescale 1ns / 1ps
module glitcbus_clock_generator(
		input clk_i,
		output ce_o,
		output gclk_debug_o,
		output GCLK,
		output GCLK_MON
    );


	// Autoreset the DCM. Maybe make this controllable.
	reg [3:0] reset_counter = {4{1'b0}};
	wire [4:0] reset_counter_plus_one = reset_counter + 1;
	reg reset = 0;

	always @(posedge clk_i) begin
		if (!reset_counter_plus_one[4]) reset_counter <= reset_counter_plus_one;
		reset <= !reset_counter_plus_one[4];
	end

	reg clock_enable = 0;
	reg gclk_debug = 0;
	(* IOB = "TRUE" *)
	reg gclk_output = 0;
	(* IOB = "TRUE" *)
	reg gclk_mon_output = 0;

	wire shifted_clk_for_gclk;
	
	always @(posedge clk_i) begin
		clock_enable <= ~clock_enable;
		gclk_debug <= clock_enable;
	end
	
	always @(posedge shifted_clk_for_gclk) begin
		gclk_output <= clock_enable;
		gclk_mon_output <= clock_enable;
	end

	// Advance clk_i by about 10 ns (1/3 of the clock)
	// This takes care of the 8-10 ns delay in the clock
	// risetime due to the long trace.
	DCM_SP #(.PHASE_SHIFT(-90),.CLKOUT_PHASE_SHIFT("FIXED")) 
		u_dcm(.CLKIN(clk_i),.CLKFB(shifted_clk_for_gclk),.CLK0(shifted_clk_for_gclk),.RST(reset));

	assign GCLK = gclk_output;
	assign GCLK_MON = gclk_mon_output;
	assign gclk_debug_o = gclk_debug;
	assign ce_o = clock_enable;

endmodule

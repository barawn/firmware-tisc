`timescale 1ns / 1ps
//
// Programming procedure:
// 1) Write '1' to a bit from bit 0 to bit 3 (for GLITCA->D respectively)
// 2) Wait for that bit to be cleared and the INIT bit (bit 8 to bit 11) to be set.
// 3) Program via the GLITCBUS interface.
// 4) Wait for DONE to go high.
module glitc_conf_controller(
		input clk_i,
		input cyc_i,
		input stb_i,
		input we_i,
		input [3:0] adr_i,
		input [31:0] dat_i,
		output [31:0] dat_o,
		output ack_o,
		output [3:0] gready_o,
		output [3:0] PROGRAM_B,
		output [3:0] INIT_B,
		input [3:0] DONE
    );

	reg [3:0] init_seen = {4{1'b0}};
	reg [3:0] done_seen = {4{1'b0}};
	reg [3:0] prog_request = {4{1'b0}};
	reg [3:0] program = {4{1'b0}};
	reg [3:0] prog_init_done = {4{1'b0}};
	reg [3:0] counter = {4{1'b0}};	
	integer i;
	always @(posedge clk_i) begin
		for (i=0;i<4;i=i+1) begin
			if (prog_init_done[i]) prog_request[i] <= 0;
			else if (cyc_i && stb_i && we_i && dat_i[i]) prog_request[i] <= 1;
			
			if (prog_request[i]) done_seen[i] <= 0;
			else if (DONE[i]) done_seen[i] <= 1;

			if (prog_request[i]) init_seen[i] <= 0;
			else if (INIT_B[i]) init_seen[i] <= 0;

			program[i] <= !prog_request[i];
			prog_init_done[i] <= (prog_request[i] && counter == {4{1'b1}});
		end

		// If a write to initiate *any* of the programs goes, reset the counter.
		// Otherwise, if any of the program requests is going, increment counter.
		// (This means if someone tries to issue requests of 0, 1, 2, 3, sequentially,
		//  it will work, but 0, 1, 2 will have a slightly longer PROGRAM_B).
		if (cyc_i && stb_i && we_i && (dat_i[3:0] != {4{1'b0}})) counter <= {4{1'b0}};
		else if (prog_request != {4{1'b0}}) counter <= counter + 1;
	end
	assign dat_o = {{12{1'b0}},{4{1'b0}},done_seen,{4{1'b0}},init_seen,{4{1'b0}},prog_request};
	assign ack_o = cyc_i && stb_i;
	assign gready_o = done_seen;
	assign PROGRAM_B = ~program;
	
endmodule

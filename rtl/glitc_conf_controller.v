////////////////////////////////////////////////////////////////////////////////
// This file is a part of the Antarctic Impulsive Transient Antenna (ANITA)
// project, a collaborative scientific effort between multiple institutions. For
// more information, contact Peter Gorham (gorham@phys.hawaii.edu).
//
// All rights reserved.
//
// Author: Patrick Allison, Ohio State University (allison.122@osu.edu)
// Author:
// Author:
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps
//
// Programming procedure:
// 1) Write '1' to a bit from bit 0 to bit 3 (for GLITCA->D respectively)
// 2) Wait for that bit to be cleared and the INIT bit (bit 8 to bit 11) to be set.
// 3) Program via the GLITCBUS interface.
// 4) Wait for DONE to go high.
// 5) Write '1' to a bit from bit 4 to bit 7 (for GLITCA->D respectively).
`include "wishbone.vh"
module glitc_conf_controller(
		input clk_i,
		`WBS_NAMED_BARE_PORT(32, 5, 4),
		output [3:0] gready_o,
		output [3:0] gprogram_o,
		inout [3:0] PROGRAM_B,
		input [3:0] INIT_B,
		input [3:0] DONE
    );

	reg ack = 0;
	reg [3:0] init_seen = {4{1'b0}};
	reg [3:0] done_seen = {4{1'b0}};
	reg [3:0] config_done = {4{1'b0}};
	reg [3:0] prog_request = {4{1'b0}};
	reg [3:0] program = {4{1'b0}};
	reg [3:0] prog_init_done = {4{1'b0}};
	reg [3:0] counter = {4{1'b0}};	
	integer i;
	always @(posedge clk_i) begin
		for (i=0;i<4;i=i+1) begin
			if (prog_init_done[i]) prog_request[i] <= 0;
			else if (cyc_i && stb_i && we_i && dat_i[i]) prog_request[i] <= 1;
			
			if (prog_request[i]) config_done[i] <= 0;
			else if (cyc_i && stb_i && we_i && dat_i[4+i]) config_done[i] <= 1;

			if (prog_request[i]) done_seen[i] <= 0;
			else if (DONE[i]) done_seen[i] <= 1;

			if (prog_request[i]) init_seen[i] <= 0;
			else if (INIT_B[i]) init_seen[i] <= 1;

			program[i] <= prog_request[i];
			prog_init_done[i] <= (prog_request[i] && counter == {4{1'b1}});
		end

		// If a write to initiate *any* of the programs goes, reset the counter.
		// Otherwise, if any of the program requests is going, increment counter.
		// (This means if someone tries to issue requests of 0, 1, 2, 3, sequentially,
		//  it will work, but 0, 1, 2 will have a slightly longer PROGRAM_B).
		if (cyc_i && stb_i && we_i && (dat_i[3:0] != {4{1'b0}})) counter <= {4{1'b0}};
		else if (prog_request != {4{1'b0}}) counter <= counter + 1;

		ack <= cyc_i && stb_i;
	end

	generate
		genvar j;
		for (j=0;j<4;j=j+1) begin : PROG_OUTPUT
			OBUFT u_prog_obuft(.I(1'b0),.T(!program[j]),.O(PROGRAM_B[j]));
		end
	endgenerate

	assign dat_o = {{12{1'b0}},{4{1'b0}},done_seen,{4{1'b0}},init_seen,config_done,prog_request};
	assign ack_o = ack && cyc_i && stb_i;
	assign rty_o = 0;
	assign err_o = 0;
	assign gready_o = done_seen && config_done;
	assign gprogram_o = program;
endmodule

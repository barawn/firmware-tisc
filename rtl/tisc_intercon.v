`timescale 1ns / 1ps
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

// TISC WISHBONE interconnect.
`include "wishbone.vh"

module tisc_intercon(
			input clk_i,
			input rst_i,
			`WBS_NAMED_PORT(pcic, 32, 21, 4),
			`WBS_NAMED_PORT(wbvio, 32, 21, 4),
			`WBS_NAMED_PORT(i2cc, 32, 21, 4),
			`WBM_NAMED_PORT(gbm, 32, 20, 4),
			`WBM_NAMED_PORT(gcc, 32, 6, 4),
			`WBM_NAMED_PORT(tisc, 32, 6, 4),
			output [70:0] debug_o
    );
	// Masks work by matching the address & ~mask = base.
	localparam [20:0] TISC_BASE = 21'h000000; 
	localparam [20:0] TISC_MASK = 21'h0FFFBF; // Top bit + bit 6 (1011 = 0xB)
	localparam [20:0] GCC_BASE  = 21'h000040;
	localparam [20:0] GCC_MASK  = 21'h0FFFBF;
	localparam [20:0] GBM_BASE  = 21'h100000;
	localparam [20:0] GBM_MASK  = 21'h0FFFFF;

	wire [2:0] cyc_arr = {i2cc_cyc_i, wbvio_cyc_i, pcic_cyc_i};
	wire [2:0] stb_arr = {i2cc_stb_i, wbvio_stb_i, pcic_stb_i};
	wire [2:0] we_arr = {i2cc_we_i, wbvio_we_i, pcic_we_i};
	wire [2:0] gnt_arr;
	
	arbiter u_arbiter(.clk(clk_i),.rst(rst_i),
							.req0(cyc_arr[0]),.gnt0(gnt_arr[0]),
							.req1(cyc_arr[1]),.gnt1(gnt_arr[1]),
							.req2(cyc_arr[2]),.gnt2(gnt_arr[2]),
							.req3(1'b0));
							
	wire cyc = |(cyc_arr & gnt_arr);
	wire stb = |(stb_arr & gnt_arr);
	wire we = |(we_arr & gnt_arr);
	reg [20:0] adr;
	reg [31:0] dat_o;
	reg [3:0] sel;
	always @(*) begin
		if (gnt_arr[2]) begin
			adr <= i2cc_adr_i;
			dat_o <= i2cc_dat_i;
			sel <= i2cc_sel_i;
		end else if (gnt_arr[1]) begin
			adr <= wbvio_adr_i;
			dat_o <= wbvio_dat_i;
			sel <= wbvio_sel_i;
		end else begin
			adr <= pcic_adr_i;
			dat_o <= pcic_dat_i;
			sel <= pcic_sel_i;
		end
	end
	`define SLAVE_MAP(prefix, mask, base) \
		wire sel_``prefix = ((adr & ~ mask ) == base ); \
		assign prefix``_cyc_o = cyc && sel_``prefix ; \
		assign prefix``_stb_o = stb && sel_``prefix ; \
		assign prefix``_we_o = we && sel_``prefix; \
		assign prefix``_adr_o = (adr & mask ); \
		assign prefix``_dat_o = dat_o; \
		assign prefix``_sel_o = sel	

	`SLAVE_MAP(tisc, TISC_MASK, TISC_BASE);
	`SLAVE_MAP(gcc, GCC_MASK, GCC_BASE);
	`SLAVE_MAP(gbm, GBM_MASK, GBM_BASE);

	reg muxed_ack;
	reg muxed_err;
	reg muxed_rty;
	reg [31:0] muxed_dat_i;

	always @(*) begin
		if (sel_tisc) begin
			muxed_ack <= tisc_ack_i;
			muxed_err <= tisc_err_i;
			muxed_rty <= tisc_rty_i;
			muxed_dat_i <= tisc_dat_i;
		end else if (sel_gcc) begin
			muxed_ack <= gcc_ack_i;
			muxed_err <= gcc_err_i;
			muxed_rty <= gcc_rty_i;
			muxed_dat_i <= gcc_dat_i;
		end else begin
			muxed_ack <= gbm_ack_i;
			muxed_err <= gbm_err_i;
			muxed_rty <= gbm_rty_i;
			muxed_dat_i <= gbm_dat_i;
		end 
	end
	
	assign pcic_ack_o = gnt_arr[0] && muxed_ack;
	assign pcic_err_o = gnt_arr[0] && muxed_err;
	assign pcic_rty_o = gnt_arr[0] && muxed_rty;
	assign pcic_dat_o = muxed_dat_i;
	
	assign wbvio_ack_o = gnt_arr[1] && muxed_ack;
	assign wbvio_err_o = gnt_arr[1] && muxed_err;
	assign wbvio_rty_o = gnt_arr[1] && muxed_rty;
	assign wbvio_dat_o = muxed_dat_i;
	
	assign i2cc_ack_o = gnt_arr[2] && muxed_ack;
	assign i2cc_err_o = gnt_arr[2] && muxed_err;
	assign i2cc_rty_o = gnt_arr[2] && muxed_rty;
	assign i2cc_dat_o = muxed_dat_i;
	
	reg [31:0] wbc_debug_data = {32{1'b0}};
	reg [20:0] wbc_debug_adr = {21{1'b0}};
	reg [3:0] wbc_debug_sel = {4{1'b0}};
	reg wbc_debug_cyc = 0;
	reg wbc_debug_stb = 0;
	reg wbc_debug_ack = 0;
	reg wbc_debug_we = 0;
	reg wbc_debug_err = 0;
	reg wbc_debug_rty = 0;
	reg [3:0] wbc_debug_gnt = {4{1'b0}};
	always @(posedge clk_i) begin
		if (we) wbc_debug_data <= dat_o;
		else wbc_debug_data <= muxed_dat_i;
		
		wbc_debug_adr <= adr;
		wbc_debug_cyc <= cyc;
		wbc_debug_sel <= sel;
		wbc_debug_stb <= stb;
		wbc_debug_we <= we;
		wbc_debug_ack <= muxed_ack;
		wbc_debug_err <= muxed_err;
		wbc_debug_rty <= muxed_rty;
		wbc_debug_gnt <= {{1'b0},gnt_arr};
	end

	assign debug_o[0 +: 32] = wbc_debug_data;
	assign debug_o[32 +: 21] = wbc_debug_adr;
	assign debug_o[53 +: 4] = wbc_debug_sel;
	assign debug_o[57] = wbc_debug_cyc;
	assign debug_o[58] = wbc_debug_stb;
	assign debug_o[59] = wbc_debug_we;
	assign debug_o[60] = wbc_debug_ack;
	assign debug_o[61] = wbc_debug_err;
	assign debug_o[62] = wbc_debug_rty;
	assign debug_o[63 +: 4] = wbc_debug_gnt;
	
endmodule

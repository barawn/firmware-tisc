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
// Quad GLITCBUS master. This module also handles the programming interface as well.
// There's a separate module (in the TISC address space) which handle the programming
// state of each FPGA. Each FPGA can be programmed/reprogrammed individually.
//
// That module does:
// Assert PROGRAM_B: set "gready_i[N]" to 0. (N=0 to 3)
// Assert INIT_B
// Deassert PROGRAM_B
// Deassert INIT_B
// 
// It then watches for DONE being asserted, and sets gready_i[N] to 1.
//
//
`include "wishbone.vh"
module glitcbus_master(
		input [3:0] gready_i,
		output [3:0] GSEL_B,
		inout [7:0] GAD,
		output GRDWR_B,
		output GCLK,
		input clk_i,
		output [7:0] gad_debug_o,
		output grdwr_b_debug_o,
		output [3:0] gsel_b_debug_o,
		output gclk_debug_o,
		output [15:0] debug_o,
		`WBS_NAMED_BARE_PORT(32, 20, 4)
		);

	// Bits [19:18] select which GLITC we're talking to.
	// If "gready_i" for that GLITC is 0, then we treat it as a configuration
	// load. Otherwise we treat it as a GLITCBUS transaction.
	wire [1:0] glitc_sel = adr_i[19:18];
	// 16-bit GLITCBUS address.
	wire [15:0] glitc_adr = adr_i[17:2];
	
	reg [1:0] clock_counter = {2{1'b0}};
	always @(posedge clk_i) begin
		clock_counter <= clock_counter + 1;
	end
	
	// Step down the GLITCBUS interface to 16 MHz.
	reg clock_enable = 0;
	always @(posedge clk_i) begin
		clock_enable <= (clock_counter == {2{1'b1}});
//		clock_enable <= ~clock_enable;
	end
	// This becomes the GLITCBUS clock. It's functionally
	// inverted from clock_enable: e.g. its rising edge
	// comes at the same time as all of the signals change.
	(* IOB = "TRUE" *)
	reg glitcbus_clock = 0;
	reg glitcbus_clock_debug = 0;
	always @(posedge clk_i) begin
		glitcbus_clock <= clock_counter[1];
		glitcbus_clock_debug <= clock_counter[1];
//		glitcbus_clock <= clock_enable;
//		glitcbus_clock_debug <= clock_enable;
	end
	assign GCLK = glitcbus_clock;
	assign gclk_debug_o = glitcbus_clock_debug;
	
	localparam FSM_BITS = 5;
	//% Waiting...
	localparam [FSM_BITS-1:0] IDLE = 0;
	//% Config write. Assert RDWR_B first.
	localparam [FSM_BITS-1:0] CONFIG_RDWR_B = 1;
	//% Then byte 0.
	localparam [FSM_BITS-1:0] CONFIG_WRITE_BYTE_0 = 2;
	//% Then byte 1.
	localparam [FSM_BITS-1:0] CONFIG_WRITE_BYTE_1 = 3;
	//% Then byte 2.
	localparam [FSM_BITS-1:0] CONFIG_WRITE_BYTE_2 = 4;
	//% Then byte 3.
	localparam [FSM_BITS-1:0] CONFIG_WRITE_BYTE_3 = 5;
	//% Read wait 0 (catch up to bus).
	localparam [FSM_BITS-1:0] CONFIG_READ_WAIT_0 = 6;
	//% Read wait 1 (data now on bus, wait for latch by FF).
	localparam [FSM_BITS-1:0] CONFIG_READ_WAIT_1 = 7;
	//% Read wait 2, for no apparent reason.
	localparam [FSM_BITS-1:0] CONFIG_READ_WAIT_2 = 8;
	//% Read wait 3, for no apparent reason.
	localparam [FSM_BITS-1:0] CONFIG_READ_WAIT_3 = 9;
	//% Read byte 0.
	localparam [FSM_BITS-1:0] CONFIG_READ_BYTE_0 = 10;
	//% Read byte 1.
	localparam [FSM_BITS-1:0] CONFIG_READ_BYTE_1 = 11;
	//% Read byte 2.
	localparam [FSM_BITS-1:0] CONFIG_READ_BYTE_2 = 12;
	//% Read byte 3.
	localparam [FSM_BITS-1:0] CONFIG_READ_BYTE_3 = 13;
	//% Finish.
	localparam [FSM_BITS-1:0] CONFIG_DONE = 14;
	//% GLITCBUS transaction. Select phase.
	localparam [FSM_BITS-1:0] GB_SEL = 15;
	//% GLITCBUS transaction. Address high phase.
	localparam [FSM_BITS-1:0] GB_ADDRESS = 16;
	//% GLITCBUS transaction. Address low phase.
	localparam [FSM_BITS-1:0] GB_ADDRESS2 = 17;
	//% GLITCBUS transaction. Wait 1 phase.
	localparam [FSM_BITS-1:0] GB_WAIT = 18;
	//% GLITCBUS transaction. Read wait phase.
	localparam [FSM_BITS-1:0] GB_READ_WAIT = 19;
	//% GLITCBUS transaction. Second read wait phase.
	localparam [FSM_BITS-1:0] GB_READ_WAIT_2 = 20;
	//% GLITCBUS transaction. BYTE3 phase.
	localparam [FSM_BITS-1:0] GB_BYTE3 = 21;
	//% GLITCBUS transaction. BYTE2 phase.
	localparam [FSM_BITS-1:0] GB_BYTE2 = 22;
	//% GLITCBUS transaction. BYTE1 phase.
	localparam [FSM_BITS-1:0] GB_BYTE1 = 23;
	//% GLITCBUS transaction. BYTE0 phase.
	localparam [FSM_BITS-1:0] GB_BYTE0 = 24;
	//% GLITCBUS transaction. Completion phase.
	localparam [FSM_BITS-1:0] GB_DONE = 25;
	//% State variable.
	reg [FSM_BITS-1:0] state = IDLE;
	
	always @(posedge clk_i) begin
		if (clock_enable) begin
			case (state)
				IDLE: if (cyc_i && stb_i) begin
					if (!gready_i[glitc_sel]) begin
						state <= CONFIG_RDWR_B;
					end else
						state <= GB_SEL;
				end
				// The config sequence takes 4 cycles.
				CONFIG_RDWR_B: if (we_i) state <= CONFIG_WRITE_BYTE_0;
									else state <= CONFIG_READ_WAIT_0;
				CONFIG_READ_WAIT_0: state <= CONFIG_READ_WAIT_1;
				CONFIG_READ_WAIT_1: state <= CONFIG_READ_WAIT_2;
				CONFIG_READ_WAIT_2: state <= CONFIG_READ_WAIT_3;
				CONFIG_READ_WAIT_3: state <= CONFIG_READ_BYTE_0;
				CONFIG_READ_BYTE_0: state <= CONFIG_READ_BYTE_1;
				CONFIG_READ_BYTE_1: state <= CONFIG_READ_BYTE_2;
				CONFIG_READ_BYTE_2: state <= CONFIG_READ_BYTE_3;
				CONFIG_READ_BYTE_3: state <= CONFIG_DONE;			
				CONFIG_WRITE_BYTE_0: state <= CONFIG_WRITE_BYTE_1;
				CONFIG_WRITE_BYTE_1: state <= CONFIG_WRITE_BYTE_2;
				CONFIG_WRITE_BYTE_2: state <= CONFIG_WRITE_BYTE_3;
				CONFIG_WRITE_BYTE_3: state <= CONFIG_DONE;
				CONFIG_DONE: state <= IDLE;
				GB_SEL: state <= GB_ADDRESS;					// select phase
				GB_ADDRESS: state <= GB_ADDRESS2;			// address high phase
				GB_ADDRESS2: state <= GB_WAIT;				// address low phase
				GB_WAIT: if (we_i) state <= GB_BYTE3;		// wait1 phase
								else 	 state <= GB_READ_WAIT;
				GB_READ_WAIT: state <= GB_READ_WAIT_2;		// wait2 phase for read
				GB_READ_WAIT_2: state <= GB_BYTE3;			// byte3 phase for read
				GB_BYTE3: state <= GB_BYTE2;					// wait2 phase for write, byte2 phase for read
				GB_BYTE2: state <= GB_BYTE1;					// byte3 phase for write, byte1 phase for read
				GB_BYTE1: state <= GB_BYTE0;					// byte2 phase for write, byte0 phase for read
				GB_BYTE0: state <= GB_DONE;					// byte1 phase for write, completion for read
				GB_DONE: state <= IDLE;
			endcase
		end
	end
	wire write_end = ((state == GB_BYTE0) && we_i) || (state == CONFIG_WRITE_BYTE_3) || (state == IDLE);
	wire read_end = ((state == GB_BYTE1) && !we_i) || (state == CONFIG_READ_BYTE_3) || (state == IDLE);
	wire begin_conf_cycle = (state == IDLE) && cyc_i && stb_i && !gready_i[glitc_sel];
	// OE_B needs to be low at GB_ADDRESS2, so oe_b_int_reg needs to be 0 during GB_ADDRESS,
	// which means it needs to be set in GB_SEL.
	// OE_B also needs to be low, for a write, at CONFIG_DONE, when things are actually asserted.
	// This means oe_b_int_reg needs to be 0 in CONFIG_WRITE_BYTE_3, which means it needs to be set in
	// CONFIG_WRITE_BYTE_3.
	reg oe_b_int_reg = 1;
	always @(posedge clk_i) begin
		if (clock_enable) begin
			if ((state == GB_SEL) || (state == CONFIG_RDWR_B && we_i)) oe_b_int_reg <= 0;
			else if ((state == GB_ADDRESS2 && !we_i) || write_end) oe_b_int_reg <= 1;
		end
	end

	reg rdwr_b_int_reg = 1;
	always @(posedge clk_i) begin
		if (clock_enable) begin
			if (begin_conf_cycle || (state == GB_SEL))
				rdwr_b_int_reg <= !we_i;
		end
	end
	
	// We want sel_int_reg asserted in GB_SEL, so GSEL_B is asserted in GB_ADDRESS.
	// We also want GSEL_B asserted at CONFIG_WRITE_BYTE or CONFIG_READ_BYTE, so we assert it in
	// CONFIG_RDWR_B (and deassert in CONFIG_WRITE_BYTE or CONFIG_READ_BYTE).
	reg [3:0] sel_int_reg = {4{1'b1}};
	always @(posedge clk_i) begin
		if (clock_enable) begin
			if ((state == GB_SEL) || (state == CONFIG_RDWR_B)) sel_int_reg[glitc_sel] <= 0;
			else if (write_end || read_end) sel_int_reg[glitc_sel] <= 1;
		end
	end
	
	wire [7:0] gad_to_ff;
	
	(* IOB = "TRUE" *)
	reg [7:0] gad_q = {8{1'b0}};

	reg [7:0] gad_out_debug = {8{1'b0}};

	(* IOB = "TRUE" *)
	reg [3:0] gsel_out = {4{1'b1}};
	reg [3:0] gsel_out_debug = {4{1'b1}};
	
	reg gad_oe_b_debug = 1;
	
	(* IOB = "TRUE" *)
	reg grdwr_b_out = 1;
	reg grdwr_b_out_debug = 1;
	
	reg [15:0] address_out = {16{1'b0}};
	reg [31:0] data_out = {32{1'b0}};
	reg ack = 0;
	
	always @(posedge clk_i) begin
		if (clock_enable) begin
			#1 gad_q <= gad_to_ff;
		end
	end
	// I've given up all belief that Map actually works, so we'll
	// force the OLOGIC design to a hard macro and rewrite things
	// here to match a CE/Data paradigm.	
	reg [7:0] gad_out_mux;
	always @(*) begin
		if (state == GB_ADDRESS) gad_out_mux <= glitc_adr[15:8];
		else if (state == GB_ADDRESS2) gad_out_mux <= glitc_adr[7:0];
		else if (state == GB_BYTE3 || state == CONFIG_WRITE_BYTE_0) gad_out_mux <= dat_i[31:24];
		else if (state == GB_BYTE2 || state == CONFIG_WRITE_BYTE_1) gad_out_mux <= dat_i[23:16];
		else if (state == GB_BYTE1 || state == CONFIG_WRITE_BYTE_2) gad_out_mux <= dat_i[15:8];
		else gad_out_mux <= dat_i[7:0];
	end
	wire gad_out_ce = (state == GB_ADDRESS || state == GB_ADDRESS2 || state == CONFIG_WRITE_BYTE_0 || state == CONFIG_WRITE_BYTE_1 || state == CONFIG_WRITE_BYTE_2 || state == CONFIG_WRITE_BYTE_3 ||
							 state == GB_BYTE3 || state == GB_BYTE2 || state == GB_BYTE1 || state == GB_BYTE0) && clock_enable;	
	always @(posedge clk_i) begin
		if (gad_out_ce) gad_out_debug <= gad_out_mux;
	end
	always @(posedge clk_i) begin
		if (clock_enable) gsel_out <= sel_int_reg;
		if (clock_enable) gsel_out_debug <= sel_int_reg;
	end
	always @(posedge clk_i) begin
		if (clock_enable) grdwr_b_out <= rdwr_b_int_reg;
		if (clock_enable) grdwr_b_out_debug <= rdwr_b_int_reg;
	end
	always @(posedge clk_i) begin
		if (clock_enable) gad_oe_b_debug <= oe_b_int_reg;
	end

	always @(posedge clk_i) begin
		if (clock_enable) begin
			if (!we_i) begin
				if (state == GB_BYTE3 || state == CONFIG_READ_BYTE_0) #1 data_out[31:24] <= gad_q;
				if (state == GB_BYTE2 || state == CONFIG_READ_BYTE_1) #1 data_out[23:16] <= gad_q;
				if (state == GB_BYTE1 || state == CONFIG_READ_BYTE_2) #1 data_out[15:8] <= gad_q;
				if (state == GB_BYTE0 || state == CONFIG_READ_BYTE_3) #1 data_out[7:0] <= gad_q;
			end
		end
	end
	always @(posedge clk_i) begin
		ack <= ((state == CONFIG_DONE) || (state == GB_BYTE0)) && clock_enable;
	end

	generate
		genvar i,j;
		for (i=0;i<8;i=i+1) begin : LOOP
			wire gad_out_to_pad;
			wire gad_in_from_pad;
			wire gad_oeb_to_pad;
			wire gad_oeb_to_odelay;
			wire gad_out_to_odelay;
			//
			// NOTE NOTE NOTE NOTE NOTE
			//
			// There is a known bug with TRCE that just completely *#@^!s up the clock-to-out timing analysis using IODELAY2s
			// in IO mode. So *IGNORE* the GAD<> delays in the datasheet report. They're garbage. Just use the GRDWR_B
			// and GSEL_B clock-to-out delays, and add maybe a nanosecond for safety. 
			IODELAY2 #(.DELAY_SRC("IO"),.IDELAY_TYPE("DEFAULT"),.ODELAY_VALUE(40)) u_iodelay(.ODATAIN(gad_out_to_odelay),
																													  .IDATAIN(gad_in_from_pad),
																													  .T(gad_oeb_to_odelay),
																													  .TOUT(gad_oeb_to_pad),
																													  .DOUT(gad_out_to_pad),
																													  .DATAOUT(gad_to_ff[i]));
			glitcbus_ologic u_ologic(.TFF_T1(oe_b_int_reg),.TFF_TQ(gad_oeb_to_odelay), .TFF_TCE(clock_enable),
											 .OFF_D1(gad_out_mux[i]), .OFF_OCE(gad_out_ce), .OFF_OQ(gad_out_to_odelay),
											 .CLK(clk_i));
			IOBUF u_iobuf(.IO(GAD[i]),.T(gad_oeb_to_pad),.I(gad_out_to_pad),.O(gad_in_from_pad));
		end
		for (j=0;j<4;j=j+1) begin : GSEL_LOOP
			IODELAY2 #(.DELAY_SRC("ODATAIN"),.ODELAY_VALUE(40)) u_iodelay(.ODATAIN(gsel_out[j]),
																							 .DOUT(GSEL_B[j]));
		end		
	endgenerate
	// GAD only goes to the IOB, so it's delayed by one clock. So to duplicate it, we 
	// have to reclock the other signals.
	reg [7:0] gad_out_debug_delayed = {8{1'b0}};
	reg gad_oe_b_debug_delayed = 1;
	reg [3:0] gsel_out_debug_delayed = {4{1'b1}};
	reg grdwr_b_out_debug_delayed = 1;
	reg [4:0] state_delayed = {5{1'b0}};
	always @(posedge clk_i) begin
		if (clock_enable) begin
			gad_out_debug_delayed <= gad_out_debug;
			gsel_out_debug_delayed <= gsel_out_debug;
			grdwr_b_out_debug_delayed <= grdwr_b_out_debug;
			gad_oe_b_debug_delayed <= gad_oe_b_debug;
			state_delayed <= state;
		end
	end
	assign gad_debug_o = (gad_oe_b_debug_delayed) ? gad_q : gad_out_debug_delayed;
	assign grdwr_b_debug_o = grdwr_b_out_debug_delayed;
	assign gsel_b_debug_o = gsel_out_debug_delayed;
	
	IODELAY2 #(.DELAY_SRC("ODATAIN"),.ODELAY_VALUE(40)) u_iodelay_grdwr(.ODATAIN(grdwr_b_out), .DOUT(GRDWR_B));

	assign ack_o = ack;
	assign dat_o = data_out;
	assign err_o = 0;
	assign rty_o = 0;
	assign debug_o[4:0] = state_delayed;
	assign debug_o[5] = gad_oe_b_debug_delayed;
endmodule

module glitcbus_ologic( input TFF_T1,
								output TFF_TQ,
								input TFF_TCE,
								input OFF_D1,
								input OFF_OCE,
								output OFF_OQ,
								input CLK);
endmodule


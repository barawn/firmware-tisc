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
module glitcbus_master_v2(
		input [3:0] gready_i,
		output [3:0] GSEL_B,
		inout [7:0] GAD,
		output GRDWR_B,
		output GCLK,
		output GCLK_MON,
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
	
	////////////////////////////////////////////////////
	// GLITCBUS Clock Generation
	////////////////////////////////////////////////////

	wire clock_enable;
	wire glitcbus_clock_debug;
	
	glitcbus_clock_generator u_clkgen(.clk_i(clk_i),.ce_o(clock_enable),
												 .gclk_debug_o(gclk_debug_o),
												 .GCLK(GCLK),.GCLK_MON(GCLK_MON));
	

	////////////////////////////////////////////////////
	// GLITCBUS Master 
	////////////////////////////////////////////////////

	//< Outgoing data to GLITCBUS.
	reg [7:0] glitcbus_data_out_mux;
	//< Debug copy of GLITCBUS data output.
	reg [7:0] gad_out_debug;

	//< Incoming data capture.
	reg [31:0] glitcbus_data_in = {32{1'b0}};
	//< Incoming data (from pad to FFs)
	wire [7:0] gad_to_ff;
	//< Incoming data from FFs.
	(* IOB = "TRUE" *)
	reg [7:0] gad_q = {8{1'b0}};

	//< GSEL_B enables for each GLITC.
	reg [3:0] gsel_enable_b = {4{1'b1}};
	//< GSEL_B copies for debug.
	reg [3:0] gsel_out_debug = {4{1'b1}};	
	//< GSEL flipflops.
	(* IOB = "TRUE" *)
	reg [3:0] gsel_b_q = {4{1'b1}};

	//< GRDWR_B flipflops.
	(* IOB = "TRUE" *)
	reg grdwr_b_q = 1'b1;
	//< GRDWR_B copy for debug.
	reg grdwr_b_out_debug = 1'b1;

	//< OE_B debug.
	reg gad_oe_b_debug = 1'b1;
	//< Acknowledge.
	reg ack = 0;
	
	// GLITCBUS/Configuration state machine.
	// These are actually all just long chains, for the most part.

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
	localparam [FSM_BITS-1:0] CONFIG_SEL = 14;
	//% GLITCBUS transaction. Select phase for writes.
	localparam [FSM_BITS-1:0] GB_SEL_WRITE = 15;
	//% GLITCBUS transaction. Address high phase for writes.
	localparam [FSM_BITS-1:0] GB_WRITE_ADDRH = 16;
	//% GLITCBUS transaction. Address low phase for writes.
	localparam [FSM_BITS-1:0] GB_WRITE_ADDRL = 17;
	//% GLITCBUS transaction. Byte 3 write phase.
	localparam [FSM_BITS-1:0] GB_WRITE_BYTE3 = 18;
	//% GLITCBUS transaction. Byte 2 write phase.
	localparam [FSM_BITS-1:0] GB_WRITE_BYTE2 = 19;
	//% GLITCBUS transaction. Byte 1 write phase.
	localparam [FSM_BITS-1:0] GB_WRITE_BYTE1 = 20;
	//% GLITCBUS transaction. Byte 0 write phase.
	localparam [FSM_BITS-1:0] GB_WRITE_BYTE0 = 21;
	//% GLITCBUS transaction. Select phase for reads.
	localparam [FSM_BITS-1:0] GB_SEL_READ = 22;
	//% GLITCBUS transaction. Address high phase for reads.
	localparam [FSM_BITS-1:0] GB_READ_ADDRH = 23;
	//% GLITCBUS transaction. Address low phase for reads.
	localparam [FSM_BITS-1:0] GB_READ_ADDRL = 24;
	//% GLITCBUS transaction. Wait 1 phase for reads.
	localparam [FSM_BITS-1:0] GB_READ_WAIT1 = 25;
	//% GLITCBUS transaction. Wait 2 phase for reads.
	localparam [FSM_BITS-1:0] GB_READ_WAIT2 = 26;
	//% GLITCBUS transaction. Byte 3 read phase.
	localparam [FSM_BITS-1:0] GB_READ_BYTE3 = 27;
	//% GLITCBUS transaction. Byte 2 read phase.
	localparam [FSM_BITS-1:0] GB_READ_BYTE2 = 28;
	//% GLITCBUS transaction. Byte 1 read phase.
	localparam [FSM_BITS-1:0] GB_READ_BYTE1 = 29;
	//% GLITCBUS transaction. Byte 0 read phase.
	localparam [FSM_BITS-1:0] GB_READ_BYTE0 = 30;
	//% GLITCBUS transaction. Completion (ack).
	localparam [FSM_BITS-1:0] DONE = 31;
	//% State variable.
	reg [FSM_BITS-1:0] state = IDLE;
	
	always @(posedge clk_i) begin
		if (clock_enable) begin
			case (state)
				IDLE: if (cyc_i && stb_i) begin
					if (!gready_i[glitc_sel]) begin
						state <= CONFIG_RDWR_B;
					end else if (we_i) state <= GB_SEL_WRITE;
					else state <= GB_SEL_READ;
				end
				// The config sequence takes 4 cycles.
				CONFIG_RDWR_B: state <= CONFIG_SEL;
				CONFIG_SEL: if (we_i) state <= CONFIG_WRITE_BYTE_3;
									  else state <= CONFIG_READ_WAIT_0;
				CONFIG_READ_WAIT_0: state <= CONFIG_READ_WAIT_1;
				CONFIG_READ_WAIT_1: state <= CONFIG_READ_WAIT_2;
				CONFIG_READ_WAIT_2: state <= CONFIG_READ_WAIT_3;
				CONFIG_READ_WAIT_3: state <= CONFIG_READ_BYTE_0;
				CONFIG_READ_BYTE_3: state <= CONFIG_READ_BYTE_2;
				CONFIG_READ_BYTE_2: state <= CONFIG_READ_BYTE_1;
				CONFIG_READ_BYTE_1: state <= CONFIG_READ_BYTE_0;
				CONFIG_READ_BYTE_0: state <= DONE;			
				CONFIG_WRITE_BYTE_3: state <= CONFIG_WRITE_BYTE_2;
				CONFIG_WRITE_BYTE_2: state <= CONFIG_WRITE_BYTE_1;
				CONFIG_WRITE_BYTE_1: state <= CONFIG_WRITE_BYTE_0;
				CONFIG_WRITE_BYTE_0: state <= DONE;
				DONE: state <= IDLE;
				GB_SEL_WRITE: state <= GB_WRITE_ADDRH;
				GB_WRITE_ADDRH: state <= GB_WRITE_ADDRL;
				GB_WRITE_ADDRL: state <= GB_WRITE_BYTE3;
				GB_WRITE_BYTE3: state <= GB_WRITE_BYTE2;
				GB_WRITE_BYTE2: state <= GB_WRITE_BYTE1;
				GB_WRITE_BYTE1: state <= GB_WRITE_BYTE0;
				GB_WRITE_BYTE0: state <= DONE;
				GB_SEL_READ: state <= GB_READ_ADDRH;
				GB_READ_ADDRH: state <= GB_READ_ADDRL;
				GB_READ_ADDRL: state <= GB_READ_WAIT1;
				GB_READ_WAIT1: state <= GB_READ_WAIT2;
				GB_READ_WAIT2: state <= GB_READ_BYTE3;
				GB_READ_BYTE3: state <= GB_READ_BYTE2;
				GB_READ_BYTE2: state <= GB_READ_BYTE1;
				GB_READ_BYTE1: state <= GB_READ_BYTE0;
				GB_READ_BYTE0: state <= DONE;
			endcase
		end
	end

	// OE_B's FF input needs to be 0 for all states except
	// CONFIG_READ_WAIT_0
	// CONFIG_READ_WAIT_1
	// CONFIG_READ_WAIT_2
	// CONFIG_READ_WAIT_3
	// CONFIG_READ_BYTE_0
	// CONFIG_READ_BYTE_1
	// CONFIG_READ_BYTE_2
	// GB_READ_ADDRL
	// GB_READ_WAIT1
	// GB_READ_WAIT2
	// GB_READ_BYTE3
	// GB_READ_BYTE2
	wire oe_b_input = (state == CONFIG_READ_WAIT_0 || state == CONFIG_READ_WAIT_1 ||
								state == CONFIG_READ_WAIT_2 || state == CONFIG_READ_WAIT_3 ||
								state == CONFIG_READ_BYTE_0 || state == CONFIG_READ_BYTE_1 ||
								state == CONFIG_READ_BYTE_2 || state == GB_READ_ADDRL ||
								state == GB_READ_WAIT1 || state == GB_READ_WAIT2 ||
								state == GB_READ_BYTE3 || state == GB_READ_BYTE2);
	// RDWR_B's FF input is 1 for all stages except
	// (CONFIG_RDWR_B && we_i)
	// CONFIG_WRITE_BYTE_0
	// CONFIG_WRITE_BYTE_1
	// CONFIG_WRITE_BYTE_2
	// CONFIG_WRITE_BYTE_3
	// GB_SEL_WRITE
	// GB_WRITE_ADDRH
	// GB_WRITE_ADDRL
	// GB_WRITE_BYTE3
	// GB_WRITE_BYTE2
	// GB_WRITE_BYTE1
	wire rdwr_b_input = !(((state == CONFIG_RDWR_B || state == CONFIG_SEL) && we_i) || (state == CONFIG_WRITE_BYTE_0 ||
								state == CONFIG_WRITE_BYTE_1 || state == CONFIG_WRITE_BYTE_2 ||
								state == CONFIG_WRITE_BYTE_3 || state == GB_SEL_WRITE ||
								state == GB_WRITE_ADDRH	|| state == GB_WRITE_ADDRL ||
								state == GB_WRITE_BYTE3	|| state == GB_WRITE_BYTE2 ||
								state == GB_WRITE_BYTE1));
	// SEL_B's FF input is 1 for (plus qualified against addresses)
	// IDLE
	// CONFIG_RDWR_B
	// CONFIG_WRITE_BYTE_0
	// CONFIG_READ_BYTE_0
	// GB_WRITE_BYTE0
	// GB_READ_BYTE1
	// GB_READ_BYTE0
	wire sel_b_input = (state == IDLE || state == CONFIG_RDWR_B ||
								state == CONFIG_WRITE_BYTE_0 ||
								state == CONFIG_READ_BYTE_0 ||
								state == DONE ||
								state == GB_WRITE_BYTE0 ||
								state == GB_READ_BYTE1 ||
								state == GB_READ_BYTE0);

	integer gsel_i;

	always @(posedge clk_i) begin
		ack <= ((state == CONFIG_WRITE_BYTE_0) || (state == CONFIG_READ_BYTE_0) || (state == GB_READ_BYTE0) || (state == GB_WRITE_BYTE0)) && clock_enable;
		for (gsel_i=0;gsel_i<4;gsel_i=gsel_i+1) begin
			gsel_enable_b[gsel_i] <= !(glitc_sel == gsel_i);
			if (clock_enable)	begin
				gsel_b_q[gsel_i] <= sel_b_input || gsel_enable_b[gsel_i];
				gsel_out_debug[gsel_i] <= sel_b_input || gsel_enable_b[gsel_i];
			end
		end
		if (clock_enable) begin
			#1 if (cyc_i && stb_i) gad_q <= gad_to_ff;
			grdwr_b_q <= rdwr_b_input;
			grdwr_b_out_debug <= rdwr_b_input;
			gad_oe_b_debug <= oe_b_input;
			gad_out_debug <= glitcbus_data_out_mux;
			if (state == CONFIG_READ_BYTE_0 || state == GB_READ_BYTE0) glitcbus_data_in[7:0] <= gad_q;
			if (state == CONFIG_READ_BYTE_1 || state == GB_READ_BYTE1) glitcbus_data_in[15:8] <= gad_q;
			if (state == CONFIG_READ_BYTE_2 || state == GB_READ_BYTE2) glitcbus_data_in[23:16] <= gad_q;
			if (state == CONFIG_READ_BYTE_3 || state == GB_READ_BYTE3) glitcbus_data_in[31:24] <= gad_q;
		end
	end

	//< Output data mux.
	always @(*) begin : GAD_OUTPUT_MUX
		case (state)
			GB_SEL_READ,GB_SEL_WRITE: glitcbus_data_out_mux <= glitc_adr[15:8];
			GB_WRITE_ADDRH,GB_READ_ADDRH: glitcbus_data_out_mux <= glitc_adr[7:0];
			GB_WRITE_ADDRL,CONFIG_SEL: glitcbus_data_out_mux <= dat_i[31:24];
			GB_WRITE_BYTE3,CONFIG_WRITE_BYTE_3: glitcbus_data_out_mux <= dat_i[23:16];
			GB_WRITE_BYTE2,CONFIG_WRITE_BYTE_2: glitcbus_data_out_mux <= dat_i[15:8];
			default: glitcbus_data_out_mux <= dat_i[7:0];
		endcase
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
			IODELAY2 #(.DELAY_SRC("IO"),.IDELAY_TYPE("FIXED"),.IDELAY_VALUE(120),.ODELAY_VALUE(120)) u_iodelay(.ODATAIN(gad_out_to_odelay),
																													  .IDATAIN(gad_in_from_pad),
																													  .T(gad_oeb_to_odelay),
																													  .TOUT(gad_oeb_to_pad),
																													  .DOUT(gad_out_to_pad),
																													  .DATAOUT(gad_to_ff[i]));
			(* BOX_TYPE = "user_black_box" *)
			glitcbus_ologic u_ologic(.TFF_T1(oe_b_input),.TFF_TQ(gad_oeb_to_odelay), .TFF_TCE(clock_enable),
											 .OFF_D1(glitcbus_data_out_mux[i]), .OFF_OCE(clock_enable && cyc_i && stb_i), .OFF_OQ(gad_out_to_odelay),
											 .CLK(clk_i));
			IOBUF u_iobuf(.IO(GAD[i]),.T(gad_oeb_to_pad),.I(gad_out_to_pad),.O(gad_in_from_pad));
		end
		for (j=0;j<4;j=j+1) begin : GSEL_LOOP
			IODELAY2 #(.DELAY_SRC("ODATAIN"),.ODELAY_VALUE(120)) u_iodelay(.ODATAIN(gsel_b_q[j]),
																							 .DOUT(GSEL_B[j]));
		end		
	endgenerate
	IODELAY2 #(.DELAY_SRC("ODATAIN"),.ODELAY_VALUE(120)) u_iodelay_grdwr(.ODATAIN(grdwr_b_q), .DOUT(GRDWR_B));


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
	

	assign ack_o = ack;
	assign dat_o = glitcbus_data_in;
	assign err_o = 0;
	assign rty_o = 0;
	assign debug_o[4:0] = state_delayed;
	assign debug_o[5] = gad_oe_b_debug_delayed;
	assign debug_o[6] = ack;
endmodule

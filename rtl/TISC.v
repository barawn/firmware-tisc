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
`include "wishbone.vh"
`include "pci.vh"
module TISC(
		// CompactPCI control signals.
		input pci_clk,
		inout pci_rst,
		inout pci_inta,
		inout pci_req,
		input pci_gnt,
		inout pci_frame,
		inout pci_irdy,
		input pci_idsel,
		inout pci_devsel,
		inout pci_trdy,
		inout pci_stop,
		inout pci_par,
		inout pci_perr,
		inout pci_serr,
		// CompactPCI data/address, transfer type, byte enables.
		inout [31:0] pci_ad,
		inout [3:0] pci_cbe,
		// GLITCBUS
		output [3:0] GSEL_B,
		output GRDWR_B,
		inout [7:0] GAD,
		output GCLK,
		// Programming
		inout [3:0] PROGRAM_B,
		input [3:0] INIT_B,
		input [3:0] DONE,
		// Clock select and enable
		output SYSCLK_SEL,
		output EN_LOCAL_CLK,
		// JTAG
		output GSEL_JTAG_B
    );
	 
	 
	assign GSEL_JTAG_B = 1;
	// Identifier. This is just the readout of register 0.
	// We don't have a firmware version yet, will add that later.
	localparam [31:0] CPCI_IDENT = "TSC1";

	// WISHBONE master busses.
	`WB_DEFINE(pcic, 32, 21, 4);
	`WB_DEFINE(wbvio, 32, 21, 4);
	`WB_DEFINE(i2cc, 32, 21, 4);
	// WISHBONE slave busses.
	`WB_DEFINE(gbm, 32, 20, 4);
	`WB_DEFINE(gcc, 32, 5, 4);
	`WB_DEFINE(tisc, 32, 5, 4);
	`WB_DEFINE(pcid, 32, 32, 4);
	// Kill the unused bus.
	`WB_KILL(pcid, 32, 32, 4);
	`WB_KILL(i2cc, 32, 21, 4);
	
	`PCI_TRIS(pci_rst);
	`PCI_TRIS(pci_inta);
	`PCI_TRIS(pci_req);
	`PCI_TRIS(pci_frame);
	`PCI_TRIS(pci_irdy);
	`PCI_TRIS(pci_devsel);
	`PCI_TRIS(pci_trdy);
	`PCI_TRIS(pci_stop);
	`PCI_TRIS(pci_par);
	`PCI_TRIS(pci_perr);
	`PCI_TRIS(pci_serr);
	`PCI_TRIS_VECTOR(pci_ad, 32);
	`PCI_TRIS_VECTOR(pci_cbe, 4);	
	

	// Common WISHBONE.
	wire wb_clk;
	wire wb_rst_in;
	wire wb_rst_out;
	wire wb_int_in;
	wire wb_int_out = 0;

	wire clk_i;
	input_clock_deskew #(.DEVICE("SPARTAN6"),.DIFF_PAIR("FALSE"),.DIFF_OUT("FALSE"))
			u_pci_clock_deskew(.I(pci_clk),.O(clk_i));
	assign wb_clk = clk_i;

	pci_bridge32 u_pci(	.pci_clk_i(clk_i),
								`PCI_TRIS_CONNECT(pci_rst),
								.pci_req_o(pci_req_o),
								.pci_req_oe_o(pci_req_oe),
								.pci_gnt_i(pci_gnt),
								`PCI_TRIS_CONNECT(pci_inta),
								`PCI_TRIS_CONNECT(pci_frame),
								`PCI_TRIS_CONNECT(pci_irdy),
								.pci_idsel_i(pci_idsel),
								`PCI_TRIS_CONNECT(pci_devsel),
								`PCI_TRIS_CONNECT(pci_trdy),
								`PCI_TRIS_CONNECT(pci_stop),
								`PCI_TRIS_CONNECT(pci_ad),
								`PCI_TRIS_CONNECT(pci_cbe),
								`PCI_TRIS_CONNECT(pci_par),
								`PCI_TRIS_CONNECT(pci_perr),
								.pci_serr_o(pci_serr_o),
								.pci_serr_oe_o(pci_serr_oe),

								.wb_clk_i(wb_clk),
								.wb_rst_o(wb_rst_in),
								.wb_rst_i(wb_rst_out),
								.wb_int_o(wb_int_in),
								.wb_int_i(wb_int_out),

								`WBM_CONNECT(pcic, wbm),
								`WBS_CONNECT(pcid, wbs)
								// .wbm_cti_o(wbm_cti),
								// .wbm_bte_o(wbm_bte)
	);
	
	wire [70:0] wbc_debug;
	tisc_intercon u_intercon(.clk_i(wb_clk),.rst_i(1'b0),
									 `WBS_CONNECT(pcic, pcic),
									 `WBS_CONNECT(wbvio, wbvio),
									 `WBS_CONNECT(i2cc, i2cc),
									 `WBM_CONNECT(gbm, gbm),
									 `WBM_CONNECT(gcc, gcc),
									 `WBM_CONNECT(tisc, tisc),
									 .debug_o(wbc_debug));	
	wire [7:0] gad_debug;
	wire [3:0] gsel_debug;
	wire grdwr_debug;
	wire gclk_debug;
	wire [15:0] gbm_debug;
	glitcbus_master gb_master(.clk_i(wb_clk),
									`WBS_BARE_CONNECT(gbm),
									.GSEL_B(GSEL_B),
									.GAD(GAD),
									.GRDWR_B(GRDWR_B),
									.GCLK(GCLK),
									.gad_debug_o(gad_debug),
									.gsel_b_debug_o(gsel_debug),
									.grdwr_b_debug_o(grdwr_debug),
									.gclk_debug_o(gclk_debug),
									.gready_i(glitc_ready),
									.debug_o(gbm_debug));
	glitc_conf_controller gc_controller(.clk_i(wb_clk),
													`WBS_BARE_CONNECT(gcc),
													.gready_o(glitc_ready),
													.PROGRAM_B(PROGRAM_B),
													.INIT_B(INIT_B),
													.DONE(DONE));
	tisc_identification #(.IDENT(CPCI_IDENT)) tisc_ident(.clk_i(wb_clk),
																		  .rst_i(1'b0),
																		  `WBS_BARE_CONNECT(tisc),
																		  .SYSCLK_SEL(SYSCLK_SEL),
																		  .EN_LOCAL_CLK(EN_LOCAL_CLK));

	wire [70:0] gb_debug;
	assign gb_debug[0 +: 8] = gad_debug;
	assign gb_debug[8 +: 4] = gsel_debug;
	assign gb_debug[12 +: 4] = INIT_B;
	assign gb_debug[16 +: 4] = PROGRAM_B;
	assign gb_debug[20 +: 4] = DONE;
	assign gb_debug[24] = grdwr_debug;
	assign gb_debug[25] = gclk_debug;
	assign gb_debug[26 +: 4] = glitc_ready;
	assign gb_debug[30 +: 16] = gbm_debug;
	wire [35:0] ila0_control;
	wire [35:0] ila1_control;
	wire [35:0] vio_control;
	wire [7:0] global_debug;
	wire [63:0] vio_sync_in;
	wire [47:0] vio_sync_out;

	wire [31:0] bridge_dat_o = vio_sync_in[0 +: 32];
	wire [19:0] bridge_adr_o = vio_sync_in[32 +: 20];
	wire bridge_we_o = vio_sync_in[52];
	wire bridge_go_o = vio_sync_in[53];
	wire bridge_lock_o = vio_sync_in[54];

  reg [31:0] pci_debug_data = {32{1'b0}};
  reg [19:0] pci_debug_adr = {20{1'b0}};
  reg [3:0] pci_debug_sel = {4{1'b0}};
  reg pci_debug_cyc = 0;
  reg pci_debug_stb = 0;
  reg pci_debug_ack = 0;
  reg pci_debug_we = 0;
  reg pci_debug_err = 0;
  reg pci_debug_rty = 0;

  always @(posedge wb_clk) begin
			 if (pcic_we_o) pci_debug_data <= pcic_dat_o;
			 else pci_debug_data <= pcic_dat_i;

			 pci_debug_adr <= pcic_adr_o;
			 pci_debug_cyc <= pcic_cyc_o;
			 pci_debug_sel <= pcic_sel_o;
			 pci_debug_stb <= pcic_stb_o;
			 pci_debug_we <= pcic_we_o;
			 pci_debug_ack <= pcic_ack_i;
			 pci_debug_err <= pcic_err_i;
			 pci_debug_rty <= pcic_rty_i;
  end
	wire [70:0] pci_debug;
  assign pci_debug[0 +: 32] = pci_debug_data;
  assign pci_debug[32 +: 20] = pci_debug_adr;
  assign pci_debug[52 +: 4] = pci_debug_sel;
  assign pci_debug[56] = pci_debug_cyc;
  assign pci_debug[57] = pci_debug_stb;
  assign pci_debug[58] = pci_debug_we;
  assign pci_debug[59] = pci_debug_ack;
  assign pci_debug[60] = pci_debug_err;
  assign pci_debug[61] = pci_debug_rty;


	wire [31:0] bridge_dat_i;
	wire bridge_done_i;
	wire bridge_err_i;
	assign vio_sync_out[0 +: 32] = bridge_dat_i;
	assign vio_sync_out[32] = bridge_done_i;
	assign vio_sync_out[33] = bridge_err_i;


	wbvio_bridge u_bridge(.clk_i(wb_clk),.rst_i(1'b0),
		.wbvio_dat_i(bridge_dat_o),
		.wbvio_adr_i(bridge_adr_o),
		.wbvio_we_i(bridge_we_o),
		.wbvio_go_i(bridge_go_o),
		.wbvio_lock_i(bridge_lock_o),
		.wbvio_dat_o(bridge_dat_i),
		.wbvio_done_o(bridge_done_i),
		.wbvio_err_o(bridge_err_i),
		.cyc_o(wbvio_cyc_o),
		.stb_o(wbvio_stb_o),
		.we_o(wbvio_we_o),
		.dat_i(wbvio_dat_i),
		.dat_o(wbvio_dat_o),
		.adr_o(wbvio_adr_o),
		.ack_i(wbvio_ack_i),
		.err_i(wbvio_err_i),
		.rty_i(wbvio_rty_i)
	);	
	assign wbvio_sel_o = {4{1'b1}};
	
	tisc_icon u_icon(.CONTROL0(ila0_control),.CONTROL1(ila1_control),.CONTROL2(vio_control));
	tisc_ila u_ila0(.CONTROL(ila0_control),.CLK(wb_clk),.TRIG0(pci_debug));
	tisc_ila u_ila1(.CONTROL(ila1_control),.CLK(wb_clk),.TRIG0(gb_debug));
	tisc_vio u_vio(.CONTROL(vio_control),.CLK(wb_clk),.SYNC_IN(vio_sync_out),.SYNC_OUT(vio_sync_in),.ASYNC_OUT(global_debug));
endmodule

module tisc_identification(
			input clk_i,
			input rst_i,
			`WBS_NAMED_BARE_PORT(32, 5, 4),
			output SYSCLK_SEL,
			output EN_LOCAL_CLK
);

	parameter [31:0] IDENT = "CPCI";
	parameter [7:0] VER_REV = 8'h00;
	parameter [3:0] VER_MINOR = 4'h00;
	parameter [3:0] VER_MAJOR = 4'h00;
	parameter [7:0] VER_DAY = 8'h00;
	parameter [3:0] VER_MONTH = 4'h00;
	parameter [3:0] VER_BOARD = 4'h00;
	localparam [31:0] VERSION = {VER_BOARD,VER_MONTH,VER_DAY,VER_MAJOR,VER_MINOR,VER_REV}; 
	
	wire [31:0] CTRL0;
	wire [31:0] CTRL1 = {32{1'b0}};

	// We have 16 registers: map 0x00 to IDENT, 0x01 to VERSION, 0x02 to CTRL0, 0x03 to CTRL1.
	// Later we'll add an SPI core as well, and maybe a JTAG port. 
	reg [31:0] dat_mux;
	always @(*) begin
		case (adr_i[3:2])
			2'h0: dat_mux <= IDENT;
			2'h1: dat_mux <= VERSION;
			2'h2: dat_mux <= CTRL0;
			2'h3: dat_mux <= CTRL1;
		endcase
	end

	reg sysclk_sel_reg = 1;
	reg en_local_clk_reg = 1;
	always @(posedge clk_i) begin
		if (rst_i) begin 
			sysclk_sel_reg <= 1;
			en_local_clk_reg <= 1;
		end else begin
			if (stb_i && cyc_i && adr_i[3:2] == 2'h2 && we_i) begin 
				sysclk_sel_reg <= dat_i[0];
				en_local_clk_reg <= dat_i[1];
			end
		end
	end
	assign SYSCLK_SEL = sysclk_sel_reg;
	assign EN_LOCAL_CLK = en_local_clk_reg;
	assign CTRL0 = {{30{1'b0}},EN_LOCAL_CLK,SYSCLK_SEL};
	assign ack_o = stb_i && cyc_i;
	assign err_o = 1'b0;
	assign rty_o = 1'b0;
	assign dat_o = dat_mux;
endmodule

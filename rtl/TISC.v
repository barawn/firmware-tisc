`timescale 1ns / 1ps
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
		output [3:0] PROGRAM_B,
		input [3:0] INIT_B,
		input [3:0] DONE
    );

	localparam [31:0] CPCI_IDENT = "TISC";

	// Tristates. Default is active low OE, which is what the IOBUFs take.
`define PCI_TRIS( x ) \
 	wire x``_i;							\
	wire x``_o;							\
	wire x``_oe ;						\
	IOBUF x``_iobuf (.IO( x ), .I( x``_o ), .O( x``_i ), .T( x``_oe) ); \
	wire x``_debug = x``_oe ? x``_i : x``_o
	


	// Tristate bus. The 'dummy' debug is to end on a ';'-statement.
`define PCI_TRIS_BUS( x , y ) \
	wire [ y - 1 : 0 ] x``_i;	\
	wire [ y - 1 : 0 ] x``_o;  \
	wire [ y - 1 : 0 ] x``_oe; \
	wire [ y - 1 : 0 ] x``_debug; \
	wire [ y - 1 : 0 ] x``_debug_dup; \
	generate							\
		genvar x``_iter;			\
		for ( x``_iter = 0 ; x``_iter < y ; x``_iter = x``_iter + 1 ) begin : x``_IOBUF_LOOP \
			IOBUF x``_iobuf(.IO( x [ x``_iter ] ), .I( x``_o[ x``_iter ]), .O( x``_i [ x``_iter ] ),  .T( x``_oe [ x``_iter ] )); \
			assign x``_debug_dup = ( x``_oe[ x``_iter ] ) ? x``_i [ x``_iter ] : x``_o [ x``_iter ] ;  \
		end							\
	endgenerate 					\
	assign x``_debug = x``_debug_dup	
	
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
	`PCI_TRIS_BUS(pci_ad, 32);
	`PCI_TRIS_BUS(pci_cbe, 4);
//	`PCI_TRIS(spoci_scl);
//	`PCI_TRIS(spoci_sda);
`define PCI_TRIS_MAP(x)		\
	.``x``_i  ( ``x``_i ),	\
	.``x``_o  ( ``x``_o ),	\
	.``x``_oe_o ( ``x``_oe )

	// Common WISHBONE.
	wire wb_clk;
	wire wb_rst_in;
	wire wb_rst_out;
	wire wb_int_in;
	wire wb_int_out;
	// WISHBONE -> PCI
	wire [31:0] wbs_adr;
	wire [31:0] wbs_dat_out;
	wire [31:0] wbs_dat_in;
	wire [3:0] wbs_sel;
	wire wbs_cyc;
	wire wbs_stb;
	wire wbs_we;
	wire [2:0] wbs_cti;
	wire [1:0] wbs_bte;
	wire wbs_ack;
	wire wbs_rty;
	wire wbs_err;
	
	// PCI -> WISHBONE
	wire [31:0] wbm_adr;
	wire [31:0] wbm_dat_out;
	wire [31:0] wbm_dat_in;
	wire [3:0] wbm_sel;
	wire wbm_cyc;
	wire wbm_we;
	wire [2:0] wbm_cti;
	wire [1:0] wbm_bte;
	wire wbm_ack;
	wire wbm_rty;
	wire wbm_err;

	wire clk_i;
	input_clock_deskew #(.DEVICE("SPARTAN6"),.DIFF_PAIR("FALSE"),.DIFF_OUT("FALSE"))
			u_pci_clock_deskew(.I(pci_clk),.O(clk_i));
	assign wb_clk = clk_i;
	
	pci_bridge32 u_pci(.pci_clk_i(clk_i),
							`PCI_TRIS_MAP(pci_rst),
							.pci_req_o(pci_req_o),
							.pci_req_oe_o(pci_req_oe),
							.pci_gnt_i(pci_gnt),
							`PCI_TRIS_MAP(pci_inta),
							`PCI_TRIS_MAP(pci_frame),
							`PCI_TRIS_MAP(pci_irdy),
							.pci_idsel_i(pci_idsel),
							`PCI_TRIS_MAP(pci_devsel),
							`PCI_TRIS_MAP(pci_trdy),
							`PCI_TRIS_MAP(pci_stop),
							`PCI_TRIS_MAP(pci_ad),
							`PCI_TRIS_MAP(pci_cbe),
							`PCI_TRIS_MAP(pci_par),
							`PCI_TRIS_MAP(pci_perr),
							.pci_serr_o(pci_serr_o),
							.pci_serr_oe_o(pci_serr_oe),
							
							.wb_clk_i(wb_clk),
							.wb_rst_o(wb_rst_in),
							.wb_rst_i(wb_rst_out),
							.wb_int_o(wb_int_in),
							.wb_int_i(wb_int_out),
							
							.wbs_adr_i(wbs_adr),
							.wbs_dat_i(wbs_dat_out),
							.wbs_dat_o(wbs_dat_in),
							.wbs_sel_i(wbs_sel),
							.wbs_cyc_i(wbs_cyc),
							.wbs_stb_i(wbs_stb),
							.wbs_we_i(wbs_we),
							.wbs_cti_i(wbs_cti),
							.wbs_bte_i(wbs_bte),
							.wbs_ack_o(wbs_ack),
							.wbs_rty_o(wbs_rty),
							.wbs_err_o(wbs_err),
							
							.wbm_adr_o(wbm_adr),
							.wbm_dat_i(wbm_dat_out),
							.wbm_dat_o(wbm_dat_in),
							.wbm_sel_o(wbm_sel),
							.wbm_cyc_o(wbm_cyc),
							.wbm_stb_o(wbm_stb),
							.wbm_we_o(wbm_we),
							.wbm_cti_o(wbm_cti),
							.wbm_bte_o(wbm_bte),
							.wbm_ack_i(wbm_ack),
							.wbm_rty_i(wbm_rty),
							.wbm_err_i(wbm_err));
	// Kill the WISHBONE slave interface.
	assign wbs_cyc = 0;
	assign wbs_stb = 0;
	assign wbs_cti = 0;
	assign wbs_bte = 0;
	assign wb_rst_out = 0;
	assign wb_int_out = 0;
	assign wbs_dat_out = 0;
	assign wbs_adr = 0;
	assign wbs_we = 0;
	
	wire gb_master_stb;
	wire gb_master_ack;
	wire [31:0] gb_master_dat;
	
	wire gc_controller_stb;
	wire gc_controller_ack;
	wire [31:0] gc_controller_dat;
	wire tisc_ident_stb;
	wire tisc_ident_ack;
	wire [31:0] tisc_ident_dat;
						
	wire [1:0] sel = {wbm_adr[18],wbm_adr[4]};
	wire [31:0] register_map[3:0];
	wire [3:0] ack_map;
	wire [3:0] stb_map;
	assign stb_map[0] = (sel == 0);
	assign register_map[0] = tisc_ident_dat;
	assign ack_map[0] = tisc_ident_ack;
	
	assign stb_map[1] = (sel == 1);
	assign register_map[1] = gc_controller_dat;
	assign ack_map[1] = gc_controller_ack;
	
	assign stb_map[2] = (sel == 2);
	assign register_map[2] = gb_master_dat;
	assign ack_map[2] = gb_master_ack;
	
	assign stb_map[3] = (sel == 3);
	assign register_map[2] = gb_master_dat;
	assign ack_map[2] = gb_master_ack;
	
	assign wbm_dat_out = register_map[sel];
	assign wbm_ack = ack_map[sel];
	
	glitcbus_master gb_master(.clk_i(wb_clk),.cyc_i(wbm_cyc),.stb_i(stb_map[2] || stb_map[3]),
									.we_i(wbm_we), .adr_i(wbm_adr[15:0]),.dat_i(wbm_dat_in),.dat_o(gb_master_dat),
									.ack_o(gb_ack),
									.GSEL_B(GSEL_B),
									.GAD(GAD),
									.GRDWR_B(GRDWR_B),
									.GCLK(GCLK),
									.gready_i(glitc_ready));
	glitc_conf_controller gc_controller(.clk_i(wb_clk),.cyc_i(wbm_cyc),.stb_i(stb_map[1]),
													.we_i(wbm_we), .adr_i(wbm_adr[3:0]),.dat_i(wbm_dat_in),
													.dat_o(gc_controller_dat),.ack_o(gc_controller_ack),
													.gready_o(glitc_ready),
													.PROGRAM_B(PROGRAM_B),
													.INIT_B(INIT_B),
													.DONE(DONE));
	tisc_identification tisc_ident(.cyc_i(wbm_cyc), .stb_i(stb_map[0]),.dat_o(tisc_ident_dat),.ack_o(tisc_ident_ack));
	wire [35:0] ila_control;
	wire [7:0] ila_debug = {{5{1'b0}},wbm_ack,wbm_stb,wbm_we};
endmodule

module tisc_identification(
			input cyc_i,
			input stb_i,
			output [31:0] dat_o,
			output ack_o
);

assign ack_o = stb_i && cyc_i;
assign dat_o = "TISC";
endmodule

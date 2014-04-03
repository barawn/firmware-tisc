//////////////////////////////////////////////////////////////////////
////                                                              ////
////  File name "pci_io_mux.v"                                    ////
////                                                              ////
////  This file is part of the "PCI bridge" project               ////
////  http://www.opencores.org/cores/pci/                         ////
////                                                              ////
////  Author(s):                                                  ////
////      - Miha Dolenc (mihad@opencores.org)                     ////
////                                                              ////
////  All additional information is avaliable in the README       ////
////  file.                                                       ////
////                                                              ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2001 Miha Dolenc, mihad@opencores.org          ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//
// CVS Revision History
//
// $Log: not supported by cvs2svn $
// Revision 1.4  2003/01/27 16:49:31  mihad
// Changed module and file names. Updated scripts accordingly. FIFO synchronizations changed.
//
// Revision 1.3  2002/02/01 15:25:12  mihad
// Repaired a few bugs, updated specification, added test bench files and design document
//
// Revision 1.2  2001/10/05 08:14:29  mihad
// Updated all files with inclusion of timescale file for simulation purposes.
//
// Revision 1.1.1.1  2001/10/02 15:33:46  mihad
// New project directory structure
//
//

// this module instantiates output flip flops for PCI interface and
// some fanout downsizing logic because of heavily constrained PCI signals
// PSA, 3/19/14:
// *Complete* fanout downsizing, to relax timing as much as possible.
// We're not resource constrained any more.

// synopsys translate_off
`include "timescale.v"
// synopsys translate_on

module pci_io_mux
(
    reset_in,
    clk_in,
    frame_in,
    frame_en_in,
    frame_load_in,
    irdy_in,
    irdy_en_in,
    devsel_in,
    devsel_en_in,
    trdy_in,
    trdy_en_in,
    stop_in,
    stop_en_in,
    master_load_in,
    master_load_on_transfer_in,
    target_load_in,
    target_load_on_transfer_in,
    cbe_in,
    cbe_en_in,
    mas_ad_in,
    tar_ad_in,

    par_in,
    par_en_in,
    perr_in,
    perr_en_in,
    serr_in,
    serr_en_in,

    req_in,

    mas_ad_en_in,
    tar_ad_en_in,
    tar_ad_en_reg_in,

    ad_en_out,
    frame_en_out,
    irdy_en_out,
    devsel_en_out,
    trdy_en_out,
    stop_en_out,
    cbe_en_out,

    frame_out,
    irdy_out,
    devsel_out,
    trdy_out,
    stop_out,
    cbe_out,
    ad_out,
    ad_load_out,
    ad_en_unregistered_out,

    par_out,
    par_en_out,
    perr_out,
    perr_en_out,
    serr_out,
    serr_en_out,

    req_out,
    req_en_out,
    pci_trdy_in,
    pci_irdy_in,
    pci_frame_in,
    pci_stop_in,

    init_complete_in
);

input reset_in, clk_in ;

input           frame_in ;
input           frame_en_in ;
input           frame_load_in ;
input           irdy_in ;
input           irdy_en_in ;
input           devsel_in ;
input           devsel_en_in ;
input           trdy_in ;
input           trdy_en_in ;
input           stop_in ;
input           stop_en_in ;
input           master_load_in ;
input           target_load_in ;

input [3:0]     cbe_in ;
input           cbe_en_in ;
input [31:0]    mas_ad_in ;
input [31:0]    tar_ad_in ;

input           mas_ad_en_in ;
input           tar_ad_en_in ;
input           tar_ad_en_reg_in ;

input par_in ;
input par_en_in ;
input perr_in ;
input perr_en_in ;
input serr_in ;
input serr_en_in ;

output          frame_en_out ;
output          irdy_en_out ;
output          devsel_en_out ;
output          trdy_en_out ;
output          stop_en_out ;
output [31:0]   ad_en_out ;
output [3:0]    cbe_en_out ;

output          frame_out ;
output          irdy_out ;
output          devsel_out ;
output          trdy_out ;
output          stop_out ;
output [3:0]    cbe_out ;
output [31:0]   ad_out ;
output          ad_load_out ;
output          ad_en_unregistered_out ;

output          par_out ;
output          par_en_out ;
output          perr_out ;
output          perr_en_out ;
output          serr_out ;
output          serr_en_out ;

input           req_in ;

output          req_out ;
output          req_en_out ;

input           pci_trdy_in,
                pci_irdy_in,
                pci_frame_in,
                pci_stop_in ;

input           master_load_on_transfer_in ;
input           target_load_on_transfer_in ;

input           init_complete_in    ;

wire   [31:0]   temp_ad = tar_ad_en_reg_in ? tar_ad_in : mas_ad_in ;

(* KEEP = "TRUE" *)
wire [31:0] ad_en_ctrl;

pci_io_mux_ad_en_crit ad_en_unregistered_gen
(
    .mas_ad_en_in   (mas_ad_en_in),
	 .tar_ad_en_in	  (tar_ad_en_in),
    .pci_frame_in   (pci_frame_in),
    .pci_trdy_in    (pci_trdy_in),
    .pci_stop_in    (pci_stop_in),
    .ad_en_out      (ad_en_unregistered_out)
);

wire load = master_load_in || target_load_in ;
wire load_on_transfer = master_load_on_transfer_in || target_load_on_transfer_in ;

(* KEEP = "TRUE" *)
wire [31:0] ad_load_ctrl;

pci_io_mux_ad_load_crit ad_load_out_gen
(
    .load_in(load),
    .load_on_transfer_in(load_on_transfer),
    .pci_irdy_in(pci_irdy_in),
    .pci_trdy_in(pci_trdy_in),
    .load_out(ad_load_out)
);

generate	
	genvar i;
	for (i=0;i<32;i=i+1) begin : IOB
		pci_io_mux_ad_en_crit ad_en_gen
		(
			 .mas_ad_en_in		  (mas_ad_en_in),
			 .tar_ad_en_in		  (tar_ad_en_in),
			 .pci_frame_in   (pci_frame_in),
			 .pci_trdy_in    (pci_trdy_in),
			 .pci_stop_in    (pci_stop_in),
			 .ad_en_out      (ad_en_ctrl[i])
		);
		pci_io_mux_ad_load_crit ad_load_out_gen
		(
			 .load_in(load),
			 .load_on_transfer_in(load_on_transfer),
			 .pci_irdy_in(pci_irdy_in),
			 .pci_trdy_in(pci_trdy_in),
			 .load_out(ad_load_ctrl[i])
		);
		pci_out_reg ad_iob
		(
			 .reset_in     ( reset_in ),
			 .clk_in       ( clk_in) ,
			 .dat_en_in    ( ad_load_ctrl[i] ),
			 .en_en_in     ( 1'b1 ),
			 .dat_in       ( temp_ad[i] ) ,
			 .en_in        ( ad_en_ctrl[i] ) ,
			 .en_out       ( ad_en_out[i] ),
			 .dat_out      ( ad_out[i] )
		);
	end
endgenerate

wire [3:0] cbe_load_ctrl = {4{ master_load_in }} ;
wire [3:0] cbe_en_ctrl   = {4{ cbe_en_in }} ;

pci_out_reg cbe_iob0
(
    .reset_in     ( reset_in ),
    .clk_in       ( clk_in) ,
    .dat_en_in    ( cbe_load_ctrl[0] ),
    .en_en_in     ( 1'b1 ),
    .dat_in       ( cbe_in[0] ) ,
    .en_in        ( cbe_en_ctrl[0] ) ,
    .en_out       ( cbe_en_out[0] ),
    .dat_out      ( cbe_out[0] )
);

pci_out_reg cbe_iob1
(
    .reset_in     ( reset_in ),
    .clk_in       ( clk_in) ,
    .dat_en_in    ( cbe_load_ctrl[1] ),
    .en_en_in     ( 1'b1 ),
    .dat_in       ( cbe_in[1] ) ,
    .en_in        ( cbe_en_ctrl[1] ) ,
    .en_out       ( cbe_en_out[1] ),
    .dat_out      ( cbe_out[1] )
);

pci_out_reg cbe_iob2
(
    .reset_in     ( reset_in ),
    .clk_in       ( clk_in) ,
    .dat_en_in    ( cbe_load_ctrl[2] ),
    .en_en_in     ( 1'b1 ),
    .dat_in       ( cbe_in[2] ) ,
    .en_in        ( cbe_en_ctrl[2] ) ,
    .en_out       ( cbe_en_out[2] ),
    .dat_out      ( cbe_out[2] )
);

pci_out_reg cbe_iob3
(
    .reset_in     ( reset_in ),
    .clk_in       ( clk_in) ,
    .dat_en_in    ( cbe_load_ctrl[3] ),
    .en_en_in     ( 1'b1 ),
    .dat_in       ( cbe_in[3] ) ,
    .en_in        ( cbe_en_ctrl[3] ) ,
    .en_out       ( cbe_en_out[3] ),
    .dat_out      ( cbe_out[3] )
);

pci_out_reg frame_iob
(
    .reset_in     ( reset_in ),
    .clk_in       ( clk_in) ,
    .dat_en_in    ( frame_load_in ),
    .en_en_in     ( 1'b1 ),
    .dat_in       ( frame_in ) ,
    .en_in        ( frame_en_in ) ,
    .en_out       ( frame_en_out ),
    .dat_out      ( frame_out )
);

pci_out_reg irdy_iob
(
    .reset_in     ( reset_in ),
    .clk_in       ( clk_in) ,
    .dat_en_in    ( 1'b1 ),
    .en_en_in     ( 1'b1 ),
    .dat_in       ( irdy_in ) ,
    .en_in        ( irdy_en_in ) ,
    .en_out       ( irdy_en_out ),
    .dat_out      ( irdy_out )
);

pci_out_reg trdy_iob
(
    .reset_in     ( reset_in ),
    .clk_in       ( clk_in) ,
    .dat_en_in    ( 1'b1 ),
    .en_en_in     ( 1'b1 ),
    .dat_in       ( trdy_in ) ,
    .en_in        ( trdy_en_in ) ,
    .en_out       ( trdy_en_out ),
    .dat_out      ( trdy_out )
);

pci_out_reg stop_iob
(
    .reset_in     ( reset_in ),
    .clk_in       ( clk_in) ,
    .dat_en_in    ( 1'b1 ),
    .en_en_in     ( 1'b1 ),
    .dat_in       ( stop_in ) ,
    .en_in        ( stop_en_in ) ,
    .en_out       ( stop_en_out ),
    .dat_out      ( stop_out )
);

pci_out_reg devsel_iob
(
    .reset_in     ( reset_in ),
    .clk_in       ( clk_in) ,
    .dat_en_in    ( 1'b1 ),
    .en_en_in     ( 1'b1 ),
    .dat_in       ( devsel_in ) ,
    .en_in        ( devsel_en_in ) ,
    .en_out       ( devsel_en_out ),
    .dat_out      ( devsel_out )
);

pci_out_reg par_iob
(
    .reset_in     ( reset_in ),
    .clk_in       ( clk_in) ,
    .dat_en_in    ( 1'b1 ),
    .en_en_in     ( 1'b1 ),
    .dat_in       ( par_in ) ,
    .en_in        ( par_en_in ) ,
    .en_out       ( par_en_out ),
    .dat_out      ( par_out )
);

pci_out_reg perr_iob
(
    .reset_in     ( reset_in ),
    .clk_in       ( clk_in) ,
    .dat_en_in    ( 1'b1 ),
    .en_en_in     ( 1'b1 ),
    .dat_in       ( perr_in ) ,
    .en_in        ( perr_en_in ) ,
    .en_out       ( perr_en_out ),
    .dat_out      ( perr_out )
);

pci_out_reg serr_iob
(
    .reset_in     ( reset_in ),
    .clk_in       ( clk_in) ,
    .dat_en_in    ( 1'b1 ),
    .en_en_in     ( 1'b1 ),
    .dat_in       ( serr_in ) ,
    .en_in        ( serr_en_in ) ,
    .en_out       ( serr_en_out ),
    .dat_out      ( serr_out )
);

pci_out_reg req_iob
(
    .reset_in     ( reset_in ),
    .clk_in       ( clk_in) ,
    .dat_en_in    ( 1'b1 ),
    .en_en_in     ( 1'b1 ),
    .dat_in       ( req_in ) ,
    .en_in        ( init_complete_in ) ,
    .en_out       ( req_en_out ),
    .dat_out      ( req_out )
);

endmodule

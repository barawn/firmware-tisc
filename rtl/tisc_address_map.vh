// This generates an address map.


`ifndef TISC_ADDRESS_MAP_


module tisc_address_map(
			address_base_o,
			address_mask_o
			);
   
   localparam WIDTH = 32;
      
`define ADDRESS_MAP( number, base, mask ) \
`ifdef __AM_MAX_PHASE                     \
`ifdef MAX_ADDRESS                        \
`undef MAX_ADDRESS                        \
`define MAX_ADDRESS number                \
`else                                     \
`ifndef __AM_HEADER__                     \
 output [ WIDTH * `MAX_ADDRESS ] address_base_o; \
 output [ WIDTH * `MAX_ADDRESS ] address_mask_o; \
 `define __AM_HEADER__                    \
`endif                                    \
   assign address_base_o[ number * WIDTH +: WIDTH ] = base ; \
   assign address_mask_o[ number * WIDTH +: WIDTH ] = mask ; \						        
assign 

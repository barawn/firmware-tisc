`timescale 1ns / 1ps

module pci_clock_generator(
		input I,
		output O
    );

	parameter ARCH = "SPARTAN6";
	
	generate
		if (ARCH == "7SERIES") begin : 7SERIES
			MMCME2_BASE mmcm(.CLKIN1(I),
								  .

endmodule

#
#
#

echo FPGA xcvu5p-flvb2104-2-i

create_project -part $FPGA fpga fpga/

# add_files -fileset[\
#     ../rtl/us_udp_tx_v1.v \
#     ../rtl/us_udp_rx.v \
#     ../rtl
# ]
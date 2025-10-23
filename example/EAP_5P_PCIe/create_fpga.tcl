#
#
#

set DIR [pwd]

create_project fpga_udp $DIR/fpga_udp -part xcvu5p-flvb2104-2-i -force

add_files -fileset [get_filesets sources_1] {
    ../../rtl/mac_rx_mode.v
    ../../rtl/eth_axis_fifo.v
    ../../rtl/xpm_sync_fifo.v
    ../../rtl/us_ip_tx_mode.v
    ../../rtl/udp_stack_top.v
    ../../rtl/us_ip_rx_mode.v
    ../../rtl/us_arp_rx.v
    ../../rtl/us_ip_rx.v
    ../../rtl/us_mac_rx.v
    ../../rtl/us_arp_table.v
    ../../rtl/us_ip_tx.v
    ../../rtl/eth_frame_tx.v
    ../../rtl/us_udp_tx_v1.v
    ../../rtl/mac_tx_mode.v
    ../../rtl/axis_counter.v
    ../../rtl/eth_frame_rx.v
    ../../rtl/us_mac_tx.v
    ../../rtl/us_arp_tx.v
    ../../rtl/us_udp_rx.v
    ../../rtl/us_udp_tx.v
    ../../rtl/us_icmp_reply.v  
}
set_property top udp_stack_top [current_fileset]

update_compile_order -fileset sources_1


set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 {
    ../../tb/tb_mac_rx.v
    ../../tb/tb_udp_tx.v
    ../../tb/tb_mac_tx.v
    ../../tb/tb_arp_tx.v
    ../../tb/tb_icmp_reply.v
    ../../tb/tb_udp_rx.v
    ../../tb/tb_xpm_sync_fifo.v
    ../../tb/tb_eth_frame_tx.v
    ../../tb/tb_axis_count.v
    ../../tb/tb_udp_stack_top.sv
    ../../tb/tb_us_ip_rx.v
    ../../tb/tb_us_ip_tx.v
}
update_compile_order -fileset sim_1

set_property top tb_udp_stack_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1
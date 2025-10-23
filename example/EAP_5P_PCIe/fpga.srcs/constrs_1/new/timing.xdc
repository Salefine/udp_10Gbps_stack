

create_clock -name rx_axis_aclk -period 6.4 [get_ports rx_axis_aclk]
create_clock -name tx_axis_aclk -period 6.4 [get_ports tx_axis_aclk]

# =========================================================
# Declare rx_axis_aclk and tx_axis_aclk as asynchronous clocks
# This tells Vivado to ignore timing between these domains.
# =========================================================
set_clock_groups -asynchronous \
    -group [get_clocks rx_axis_aclk] \
    -group [get_clocks tx_axis_aclk]

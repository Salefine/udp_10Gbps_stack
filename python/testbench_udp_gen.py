import struct
from pathlib import Path

# 输出文件
udp_tx_path = Path("./python/udp-tx-data.bin")

# 待写入文本
text = """Welcome to the Xilinx Wiki!
Xilinx is now part of AMD!

The purpose of the wiki is to provide you with the tools you need to complete projects and tasks which use Xilinx products. 

If you have any technical questions on the subjects contained in this Wiki please ask them on the boards located at the AMD Adaptive Support Community. 

There are multiple boards on the Xilinx Community Forums. Please try to select the best one to fit your topic. 

If there are any issues with this Wiki itself or its infrastructure please report them here.

Click on any of the pictures or links to get started and find more information on the topic you are looking for.

Please help us improve the depth and quality of information on this wiki. You may provide us feedback by sending email to wiki-help @ xilinx.com.
"""

# 转换为 ASCII 字节
data_bytes = text.encode('ascii')

# 按 8 字节对齐，不足补 0
if len(data_bytes) % 8 != 0:
    pad_len = 8 - (len(data_bytes) % 8)
    data_bytes += b'\x00' * pad_len

# 写入文件，每 8 字节作为一个 64-bit 大端数
with udp_tx_path.open('wb') as f:
    for i in range(0, len(data_bytes), 8):
        word_bytes = data_bytes[i:i+8]
        f.write(word_bytes)  # 本身已经是大端顺序

print(f"Generated {udp_tx_path.resolve()} successfully.")

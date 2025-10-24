from pathlib import Path
import struct

# ==========================
# MAC/IP/UDP 配置
# ==========================
SRC_MAC = bytes([0xAC, 0x14, 0x45, 0xFF, 0xAF, 0xC4])
DST_MAC = bytes([0xAC, 0x70, 0x12, 0x56, 0x41, 0x23])
SRC_IP  = bytes([192, 168, 1, 144])
DST_IP  = bytes([192, 168, 1, 149])
UDP_SRC_PORT = 0x8080
UDP_DST_PORT = 0x4554


# def ip_checksum(header: bytes) -> int:
#     if len(header) % 2 != 0:
#         header += b'\x00'
#     s = 0
#     for i in range(0, len(header), 2):
#         s += (header[i] << 8) + header[i+1]
#         s = (s & 0xFFFF) + (s >> 16)
#     return (~s) & 0xFFFF

def ip_checksum(header: bytes) -> int:
    # ensure checksum field is zeroed before computing
    if len(header) >= 12:
        header = header[:10] + b'\x00\x00' + header[12:]
    if len(header) % 2 != 0:
        header += b'\x00'
    s = 0
    for i in range(0, len(header), 2):
        s += (header[i] << 8) + header[i+1]
        s = (s & 0xFFFF) + (s >> 16)
    return (~s) & 0xFFFF


def udp_checksum(src_ip, dst_ip, udp_header, payload):
    pseudo = src_ip + dst_ip + bytes([0]) + bytes([17]) + struct.pack("!H", len(udp_header)+len(payload))
    total = pseudo + udp_header + payload
    if len(total) % 2 != 0:
        total += b'\x00'
    s = 0
    for i in range(0, len(total), 2):
        s += (total[i] << 8) + total[i+1]
        s = (s & 0xFFFF) + (s >> 16)
    return (~s) & 0xFFFF

# ==========================
# 读取 bin 文件
# ==========================
mac_file = Path("./mac-tx-data.bin")
with mac_file.open("rb") as f:
    data = f.read()

# 每拍 8 字节，大端转换
words = []
for i in range(0, len(data), 8):
    word = data[i:i+8]
    words.append(word[::-1])  # 反序，转换大端

raw_bytes = b"".join(words)

# ==========================
# 滑动搜索 MAC
# ==========================
i = 0
found_frame = 0
while i < len(raw_bytes)-12:
    dst_mac_candidate = raw_bytes[i:i+6]
    src_mac_candidate = raw_bytes[i+6:i+12]

    if dst_mac_candidate == DST_MAC and src_mac_candidate == SRC_MAC:
        found_frame += 1
        print(f"\n=== Found matching frame #{found_frame} at index {i} ===")
        eth_type = struct.unpack(">H", raw_bytes[i+12:i+14])[0]
        print(f"EtherType: {eth_type:04X}")

        if eth_type == 0x0800:
            ip_header = raw_bytes[i+14:i+34]
            ihl = (ip_header[0] & 0x0F) * 4
            total_length = struct.unpack(">H", ip_header[2:4])[0]
            ip_chk_recv = struct.unpack(">H", ip_header[10:12])[0]
            ip_chk_calc = ip_checksum(ip_header)
            print(f"IP Header Length: {ihl}, Total Length: {total_length}")
            print(f"IP Checksum: received={ip_chk_recv:04X}, calc={ip_chk_calc:04X}")

            protocol = ip_header[9]
            src_ip = ip_header[12:16]
            dst_ip = ip_header[16:20]

            if protocol == 17:
                udp_start = i+14+ihl
                udp_header = raw_bytes[udp_start:udp_start+8]
                udp_src_port, udp_dst_port, udp_len, udp_chk_recv = struct.unpack(">HHHH", udp_header)
                payload = raw_bytes[udp_start+8:udp_start+udp_len]
                udp_chk_calc = udp_checksum(src_ip, dst_ip, udp_header[:6]+b'\x00\x00', payload)
                print(f"UDP src port: {udp_src_port:04X}, dst port: {udp_dst_port:04X}, len={udp_len}")
                print(f"UDP checksum: received={udp_chk_recv:04X}, calc={udp_chk_calc:04X}")

                print("\nPayload (Hex + ASCII):")
                for j in range(0, len(payload), 8):
                    chunk = payload[j:j+8]
                    hex_str = " ".join(f"{b:02X}" for b in chunk)
                    ascii_str = "".join(chr(b) if 32 <= b <= 126 else "." for b in chunk)
                    print(f"{hex_str:<24}    {ascii_str}")

        # 跳过这一帧
        i += (14 + total_length)
    else:
        i += 1

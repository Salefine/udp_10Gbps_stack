# 定义默认目标
all: run

# 执行 Tcl 脚本
run:
	@echo "Running create_fpga.tcl..."
	vivado -mode batch -source create_fpga.tcl
	@echo "FPGA creation completed!"

# 清理生成的文件
clean:
	@echo "Cleaning generated files..."
	rm -rf vivado*.log
	rm -rf vivado*.jou
	rm -rf *.str
	rm -rf xsim
	rm -rf .Xil
	rm -rf *.cache
	rm -rf *.hw
	rm -rf *.sim
	rm -rf *.ip_user_files
	@echo "Clean completed!"

# 显示帮助信息
help:
	@echo "Available targets:"
	@echo "  all     - Run the FPGA creation (default)"
	@echo "  run     - Execute create_fpga.tcl"
	@echo "  clean   - Remove all generated files"
	@echo "  help    - Display this help message"

# 声明伪目标
.PHONY: all run clean help
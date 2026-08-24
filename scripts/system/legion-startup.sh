#!/bin/bash
# Chờ hệ thống nạp driver xong
sleep 5

# # Nạp profile quạt bạn đã lưu 

# # Bật bảo vệ pin (giới hạn 80%) vì Linux hay quên cái này
# sudo env "PATH=$PATH" legion_cli batteryconservation-enable

# # Bật khóa phím Fn
# sudo env "PATH=$PATH" legion_cli fnlock-enable
sudo /home/amtia/.local/bin/legion_cli fancurve-write-preset-to-hw performance-ac
sudo /home/amtia/.local/bin/legion_cli batteryconservation-enable
# sudo /home/amtia/.local/bin/legion_cli fnlock-enable
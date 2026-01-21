#!/bin/bash

# Rclone Android 一鍵安裝腳本
# 支援 Termux 和 Android 裝置

echo "========================================"
echo "    Rclone Android 一鍵安裝腳本 v1.0    "
echo "========================================"

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 檢查是否在Termux中執行
check_termux() {
    if [ ! -d "/data/data/com.termux" ]; then
        echo -e "${RED}錯誤：此腳本需要在Termux中執行！${NC}"
        echo "請先安裝Termux，然後再執行此腳本。"
        exit 1
    fi
}

# 更新套件和安裝必要工具
install_dependencies() {
    echo -e "${BLUE}[1/6] 更新套件清單...${NC}"
    pkg update -y && pkg upgrade -y
    
    echo -e "${BLUE}[2/6] 安裝必要套件...${NC}"
    pkg install -y curl wget git unzip rclone termux-api
    
    # 檢查是否安裝成功
    if command -v rclone &> /dev/null; then
        echo -e "${GREEN}rclone 安裝成功！${NC}"
    else
        echo -e "${RED}rclone 安裝失敗，嘗試替代安裝方法...${NC}"
        install_rclone_alternative
    fi
}

# 替代安裝方法
install_rclone_alternative() {
    echo "下載最新版rclone..."
    ARCH=$(uname -m)
    
    case $ARCH in
        aarch64)
            ARCH="arm64"
            ;;
        armv7l|armv8l)
            ARCH="arm"
            ;;
        i686|x86_64)
            ARCH="amd64"
            ;;
        *)
            ARCH="arm64"
            ;;
    esac
    
    # 下載最新版rclone
    RCLONE_VERSION=$(curl -s https://api.github.com/repos/rclone/rclone/releases/latest | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
    RCLONE_URL="https://github.com/rclone/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-${ARCH}.zip"
    
    echo "下載: $RCLONE_URL"
    wget $RCLONE_URL -O rclone.zip
    unzip rclone.zip
    cd rclone-*-linux-*
    cp rclone /data/data/com.termux/files/usr/bin/
    chmod +x /data/data/com.termux/files/usr/bin/rclone
    cd ..
    rm -rf rclone.zip rclone-*-linux-*
    
    echo -e "${GREEN}rclone 安裝完成！${NC}"
}

# 建立設定目錄和配置文件
setup_config() {
    echo -e "${BLUE}[3/6] 建立設定目錄...${NC}"
    mkdir -p ~/.config/rclone
    mkdir -p ~/cloud-storage
    
    echo -e "${BLUE}[4/6] 建立基本配置...${NC}"
    
    # 建立範例配置文件
    cat > ~/.config/rclone/rclone.conf << 'EOF'
# Rclone 配置文件
# 取消註解並填寫你的雲端儲存設定

# Google Drive 範例
# [gdrive]
# type = drive
# scope = drive
# token = 
# client_id = 
# client_secret = 

# Dropbox 範例
# [dropbox]
# type = dropbox
# token = 

# OneDrive 範例
# [onedrive]
# type = onedrive
# token = 
# drive_id = 
# drive_type = personal

# WebDAV 範例
# [webdav]
# type = webdav
# url = http://example.com/webdav
# vendor = other
# user = username
# pass = password

# FTP 範例
# [ftp]
# type = ftp
# host = ftp.example.com
# user = username
# pass = password

EOF
    
    echo -e "${GREEN}設定檔建立完成！${NC}"
    echo -e "${YELLOW}設定檔位置: ~/.config/rclone/rclone.conf${NC}"
}

# 建立輔助腳本
create_helper_scripts() {
    echo -e "${BLUE}[5/6] 建立輔助腳本...${NC}"
    
    # 建立設定腳本
    cat > ~/rclone-setup.sh << 'EOF'
#!/bin/bash
# Rclone 設定輔助腳本

echo "選擇設定方式："
echo "1) Web GUI 設定 (推薦)"
echo "2) 手動設定"
echo "3) 查看現有設定"
read -p "請選擇 [1-3]: " choice

case $choice in
    1)
        echo "啟動 Web GUI..."
        echo "請在瀏覽器中打開: http://localhost:53682"
        rclone config --web-gui
        ;;
    2)
        echo "啟動手動設定..."
        rclone config
        ;;
    3)
        echo "現有設定："
        rclone config show
        ;;
    *)
        echo "無效選擇"
        ;;
esac
EOF
    
    # 建立掛載腳本
    cat > ~/rclone-mount.sh << 'EOF'
#!/bin/bash
# Rclone 掛載腳本

echo "可用雲端儲存："
rclone listremotes

read -p "輸入要掛載的雲端名稱 (如 gdrive): " remote
read -p "輸入本地掛載點名稱 (預設: cloud): " local_name
local_name=${local_name:-cloud}

LOCAL_PATH="$HOME/storage/shared/$local_name"

# 建立掛載點
mkdir -p "$LOCAL_PATH"

echo "掛載選項："
echo "1) 一般掛載"
echo "2) 只讀掛載"
echo "3) 快取掛載"
read -p "請選擇 [1-3]: " mount_choice

case $mount_choice in
    1)
        rclone mount "$remote": "$LOCAL_PATH" \
            --vfs-cache-mode writes \
            --dir-cache-time 24h \
            --allow-other \
            --daemon
        ;;
    2)
        rclone mount "$remote": "$LOCAL_PATH" \
            --vfs-cache-mode writes \
            --dir-cache-time 24h \
            --allow-other \
            --read-only \
            --daemon
        ;;
    3)
        rclone mount "$remote": "$LOCAL_PATH" \
            --vfs-cache-mode full \
            --vfs-cache-poll-interval 1m \
            --vfs-cache-max-age 24h \
            --dir-cache-time 24h \
            --allow-other \
            --daemon
        ;;
    *)
        echo "無效選擇，使用一般掛載"
        rclone mount "$remote": "$LOCAL_PATH" \
            --vfs-cache-mode writes \
            --dir-cache-time 24h \
            --allow-other \
            --daemon
        ;;
esac

echo "掛載完成！"
echo "掛載點: $LOCAL_PATH"
echo "卸載指令: fusermount -u \"$LOCAL_PATH\""
EOF
    
    # 建立常用命令腳本
    cat > ~/rclone-commands.sh << 'EOF'
#!/bin/bash
# Rclone 常用命令

echo "選擇操作："
echo "1) 列出雲端檔案"
echo "2) 上傳檔案"
echo "3) 下載檔案"
echo "4) 同步資料夾"
echo "5) 複製檔案"
echo "6) 移動檔案"
echo "7) 刪除檔案"
echo "8) 建立目錄"

read -p "請選擇 [1-8]: " choice

case $choice in
    1)
        rclone listremotes
        read -p "選擇雲端 (如 gdrive): " remote
        rclone lsd "${remote}":
        ;;
    2)
        rclone listremotes
        read -p "選擇雲端 (如 gdrive): " remote
        read -p "本地檔案路徑: " local_file
        read -p "雲端目標路徑: " remote_path
        rclone copy "$local_file" "${remote}:${remote_path}"
        ;;
    3)
        rclone listremotes
        read -p "選擇雲端 (如 gdrive): " remote
        read -p "雲端檔案路徑: " remote_file
        read -p "本地目標路徑: " local_path
        rclone copy "${remote}:${remote_file}" "$local_path"
        ;;
    4)
        rclone listremotes
        read -p "選擇雲端 (如 gdrive): " remote
        read -p "本地資料夾: " local_dir
        read -p "雲端資料夾: " remote_dir
        rclone sync "$local_dir" "${remote}:${remote_dir}"
        ;;
    5)
        rclone listremotes
        read -p "來源雲端: " src_remote
        read -p "來源路徑: " src_path
        read -p "目標雲端: " dst_remote
        read -p "目標路徑: " dst_path
        rclone copy "${src_remote}:${src_path}" "${dst_remote}:${dst_path}"
        ;;
    6)
        rclone listremotes
        read -p "來源雲端: " src_remote
        read -p "來源路徑: " src_path
        read -p "目標雲端: " dst_remote
        read -p "目標路徑: " dst_path
        rclone move "${src_remote}:${src_path}" "${dst_remote}:${dst_path}"
        ;;
    7)
        rclone listremotes
        read -p "選擇雲端: " remote
        read -p "要刪除的檔案路徑: " file_path
        rclone delete "${remote}:${file_path}"
        ;;
    8)
        rclone listremotes
        read -p "選擇雲端: " remote
        read -p "要建立的目錄路徑: " dir_path
        rclone mkdir "${remote}:${dir_path}"
        ;;
    *)
        echo "無效選擇"
        ;;
esac
EOF
    
    # 設定執行權限
    chmod +x ~/rclone-setup.sh
    chmod +x ~/rclone-mount.sh
    chmod +x ~/rclone-commands.sh
    
    echo -e "${GREEN}輔助腳本建立完成！${NC}"
}

# 安裝完成訊息
show_completion() {
    echo -e "${BLUE}[6/6] 安裝完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Rclone 安裝設定完成！${NC}"
    echo -e "${YELLOW}重要指令：${NC}"
    echo -e "1. 設定雲端: ${GREEN}./rclone-setup.sh${NC}"
    echo -e "2. 掛載雲端: ${GREEN}./rclone-mount.sh${NC}"
    echo -e "3. 常用命令: ${GREEN}./rclone-commands.sh${NC}"
    echo -e "4. 直接設定: ${GREEN}rclone config${NC}"
    echo ""
    echo -e "${YELLOW}重要提示：${NC}"
    echo "• 首次使用請先執行 ./rclone-setup.sh 設定雲端儲存"
    echo "• 掛載前請確認已授予 Termux 儲存權限"
    echo "• 設定檔位置: ~/.config/rclone/rclone.conf"
    echo "• 雲端檔案會在: /sdcard/cloud/"
    echo -e "${GREEN}========================================${NC}"
}

# 請求儲存權限
request_storage_permission() {
    echo -e "${YELLOW}請授予 Termux 儲存權限...${NC}"
    termux-setup-storage
    echo "等待 5 秒..."
    sleep 5
}

# 主安裝流程
main() {
    check_termux
    request_storage_permission
    install_dependencies
    setup_config
    create_helper_scripts
    show_completion
}

# 執行主程式
main "$@"

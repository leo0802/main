#!/data/data/com.termux/files/usr/bin/bash

# Rclone Termux 一鍵安裝腳本
# 專門為 Termux 環境設計

echo "========================================"
echo "    Rclone Termux 一鍵安裝腳本 v2.0    "
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
        echo "請先從 F-Droid 或 GitHub 安裝 Termux。"
        exit 1
    fi
}

# 更新套件和安裝必要工具
install_dependencies() {
    echo -e "${BLUE}[1/7] 更新套件清單...${NC}"
    yes | pkg update
    yes | pkg upgrade
    
    echo -e "${BLUE}[2/7] 安裝必要套件...${NC}"
    pkg install -y wget curl git unzip termux-api ncurses-utils
    
    # 安裝 rclone
    echo -e "${BLUE}[3/7] 安裝 rclone...${NC}"
    if ! pkg install -y rclone 2>/dev/null; then
        echo -e "${YELLOW}從套件庫安裝失敗，改用官方安裝腳本...${NC}"
        install_rclone_official
    else
        echo -e "${GREEN}rclone 安裝成功！${NC}"
    fi
}

# 使用官方安裝腳本
install_rclone_official() {
    echo "下載官方安裝腳本..."
    curl -O https://rclone.org/install.sh
    
    # 修改安裝腳本以適應 Termux
    sed -i 's|/usr/local/bin|/data/data/com.termux/files/usr/bin|g' install.sh
    sed -i 's|/usr/local/share/man|/data/data/com.termux/files/usr/share/man|g' install.sh
    sed -i 's|sudo ||g' install.sh
    sed -i 's|^install_rclone()|install_rclone() {\n  mkdir -p /data/data/com.termux/files/usr/share/man/man1|g' install.sh
    
    bash install.sh
    rm install.sh
    
    # 檢查安裝
    if command -v rclone >/dev/null 2>&1; then
        echo -e "${GREEN}rclone 安裝成功！${NC}"
    else
        echo -e "${RED}rclone 安裝失敗！${NC}"
        echo "請手動安裝："
        echo "1. wget https://downloads.rclone.org/rclone-current-linux-arm64.zip"
        echo "2. unzip rclone-current-linux-arm64.zip"
        echo "3. cp rclone-*-linux-arm64/rclone ~/../usr/bin/"
        exit 1
    fi
}

# 請求儲存權限
request_storage_permission() {
    echo -e "${BLUE}[4/7] 請求儲存權限...${NC}"
    echo -e "${YELLOW}請點擊「允許」以授予儲存權限${NC}"
    
    # 嘗試多種方式請求權限
    if command -v termux-setup-storage >/dev/null 2>&1; then
        termux-setup-storage
    else
        echo -e "${YELLOW}無法找到 termux-setup-storage，請手動執行：${NC}"
        echo "1. 執行: termux-setup-storage"
        echo "2. 或安裝: pkg install termux-api"
    fi
    
    echo "等待 3 秒..."
    sleep 3
}

# 建立設定目錄和配置文件
setup_config() {
    echo -e "${BLUE}[5/7] 建立設定目錄...${NC}"
    mkdir -p $HOME/.config/rclone
    mkdir -p $HOME/storage/shared/cloud-storage
    
    # 檢查並建立 rclone.conf
    if [ ! -f "$HOME/.config/rclone/rclone.conf" ]; then
        echo -e "${BLUE}建立範例設定檔...${NC}"
        cat > $HOME/.config/rclone/rclone.conf << 'EOF'
# Rclone 配置文件
# 請使用 rclone config 或 ./setup-rclone.sh 進行設定

# 範例設定 (取消註解並填寫)
# [googledrive]
# type = drive
# client_id = 
# client_secret = 
# scope = drive
# token = 

# [onedrive]
# type = onedrive
# token = 

# [dropbox]
# type = dropbox
# token = 

EOF
        echo -e "${GREEN}設定檔建立完成: ~/.config/rclone/rclone.conf${NC}"
    else
        echo -e "${YELLOW}設定檔已存在，跳過建立${NC}"
    fi
}

# 建立輔助腳本
create_helper_scripts() {
    echo -e "${BLUE}[6/7] 建立輔助腳本...${NC}"
    
    # 建立主要設定腳本
    cat > $HOME/setup-rclone.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Rclone 設定助手

echo "=== Rclone 設定選單 ==="
echo "1) Web GUI 設定 (推薦，需瀏覽器)"
echo "2) 命令列互動設定"
echo "3) 顯示現有設定"
echo "4) 手動編輯設定檔"
echo "5) 測試雲端連線"
echo "0) 返回"

read -p "請選擇 [0-5]: " choice

case $choice in
    1)
        echo "啟動 Web GUI..."
        echo "請在手機瀏覽器中開啟: http://localhost:53682"
        echo "按 Ctrl+C 停止 Web GUI"
        rclone config --web-gui --browser false
        ;;
    2)
        rclone config
        ;;
    3)
        rclone config show
        ;;
    4)
        nano $HOME/.config/rclone/rclone.conf
        ;;
    5)
        echo "可用的雲端儲存:"
        rclone listremotes
        read -p "輸入要測試的雲端名稱 (如 googledrive): " remote
        rclone lsd "$remote": || echo "測試失敗，請檢查設定"
        ;;
    0)
        echo "返回主選單"
        ;;
    *)
        echo "無效選擇"
        ;;
esac
EOF

    # 建立掛載管理腳本
    cat > $HOME/mount-rclone.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Rclone 掛載管理器

echo "=== Rclone 掛載選單 ==="
echo "1) 掛載雲端硬碟"
echo "2) 卸載雲端硬碟"
echo "3) 查看掛載狀態"
echo "4) 建立快速掛載"
echo "0) 返回"

read -p "請選擇 [0-4]: " choice

case $choice in
    1)
        echo "可用的雲端儲存:"
        rclone listremotes
        
        read -p "輸入雲端名稱: " remote
        read -p "輸入本地資料夾名稱 (預設: cloud): " foldername
        foldername=${foldername:-cloud}
        
        MOUNT_PATH="$HOME/storage/shared/$foldername"
        
        # 建立掛載點
        mkdir -p "$MOUNT_PATH"
        
        echo "選擇掛載模式:"
        echo "1) 標準模式 (可讀寫)"
        echo "2) 唯讀模式"
        echo "3) 快取模式 (離線可用)"
        
        read -p "請選擇 [1-3]: " mode
        
        case $mode in
            1)
                OPTIONS="--vfs-cache-mode writes --allow-other --daemon"
                ;;
            2)
                OPTIONS="--read-only --allow-other --daemon"
                ;;
            3)
                OPTIONS="--vfs-cache-mode full --vfs-cache-poll-interval 5m --allow-other --daemon"
                ;;
            *)
                OPTIONS="--vfs-cache-mode writes --allow-other --daemon"
                ;;
        esac
        
        echo "正在掛載 $remote 到 $MOUNT_PATH ..."
        rclone mount "$remote": "$MOUNT_PATH" $OPTIONS &
        
        if [ $? -eq 0 ]; then
            echo -e "✓ 掛載成功！\n路徑: $MOUNT_PATH"
        else
            echo -e "✗ 掛載失敗"
        fi
        ;;
        
    2)
        echo "尋找掛載點..."
        mounts=$(ls -d $HOME/storage/shared/*/ 2>/dev/null || echo "")
        
        if [ -z "$mounts" ]; then
            echo "未找到掛載點"
        else
            echo "可卸載的掛載點:"
            select mount in $mounts; do
                if [ -n "$mount" ]; then
                    fusermount -u "$mount" && echo "卸載成功" || echo "卸載失敗"
                    break
                fi
            done
        fi
        ;;
        
    3)
        echo "當前掛載狀態:"
        mount | grep rclone || echo "沒有找到 rclone 掛載"
        ;;
        
    4)
        # 快速掛載到預設位置
        REMOTE=$(rclone listremotes | head -1)
        if [ -n "$REMOTE" ]; then
            REMOTE=${REMOTE%:}
            MOUNT_PATH="$HOME/storage/shared/rclone_$REMOTE"
            mkdir -p "$MOUNT_PATH"
            rclone mount "$REMOTE": "$MOUNT_PATH" --vfs-cache-mode writes --daemon &
            echo "快速掛載完成: $MOUNT_PATH"
        else
            echo "沒有可用的雲端設定"
        fi
        ;;
        
    0)
        ;;
        
    *)
        echo "無效選擇"
        ;;
esac
EOF

    # 建立檔案管理腳本
    cat > $HOME/rclone-manager.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Rclone 檔案管理器

while true; do
    clear
    echo "=== Rclone 檔案管理 ==="
    echo "1) 上傳檔案/資料夾"
    echo "2) 下載檔案/資料夾"
    echo "3) 列出雲端檔案"
    echo "4) 刪除雲端檔案"
    echo "5) 同步資料夾"
    echo "6) 複製/移動檔案"
    echo "7) 搜尋檔案"
    echo "0) 退出"
    
    read -p "請選擇 [0-7]: " choice
    
    case $choice in
        1)
            echo "選擇雲端:"
            rclone listremotes
            read -p "雲端名稱: " remote
            
            echo "本地檔案路徑 (支援萬用字元): "
            ls -la
            read -p "路徑: " local_path
            
            read -p "雲端目標路徑 (預設: /): " remote_path
            remote_path=${remote_path:-/}
            
            rclone copy "$local_path" "${remote}:${remote_path}" -P
            echo "上傳完成"
            read -p "按 Enter 繼續..."
            ;;
            
        2)
            echo "選擇雲端:"
            rclone listremotes
            read -p "雲端名稱: " remote
            
            echo "雲端檔案清單:"
            rclone lsf "${remote}":/
            read -p "檔案路徑: " remote_file
            
            read -p "本地目標路徑 (預設: 當前目錄): " local_path
            local_path=${local_path:-.}
            
            rclone copy "${remote}:${remote_file}" "$local_path" -P
            echo "下載完成"
            read -p "按 Enter 繼續..."
            ;;
            
        3)
            echo "選擇雲端:"
            rclone listremotes
            read -p "雲端名稱: " remote
            
            read -p "查看路徑 (預設: /): " path
            path=${path:-/}
            
            rclone tree "${remote}:${path}" -a
            read -p "按 Enter 繼續..."
            ;;
            
        4)
            echo "選擇雲端:"
            rclone listremotes
            read -p "雲端名稱: " remote
            
            echo "警告：此操作無法復原！"
            read -p "要刪除的檔案路徑: " path
            
            read -p "確認刪除 ${remote}:${path} ? (y/N): " confirm
            if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                rclone delete "${remote}:${path}"
                echo "刪除完成"
            fi
            read -p "按 Enter 繼續..."
            ;;
            
        5)
            echo "雙向同步 (請小心使用)"
            rclone listremotes
            read -p "雲端名稱: " remote
            
            read -p "本地資料夾路徑: " local_dir
            read -p "雲端資料夾路徑: " remote_dir
            
            echo "同步選項:"
            echo "1) 本地 → 雲端"
            echo "2) 雲端 → 本地"
            echo "3) 雙向同步"
            
            read -p "選擇: " sync_type
            
            case $sync_type in
                1) rclone sync "$local_dir" "${remote}:${remote_dir}" -P ;;
                2) rclone sync "${remote}:${remote_dir}" "$local_dir" -P ;;
                3) rclone bisync "$local_dir" "${remote}:${remote_dir}" -P ;;
            esac
            
            read -p "按 Enter 繼續..."
            ;;
            
        0)
            echo "退出"
            break
            ;;
            
        *)
            echo "無效選擇"
            ;;
    esac
done
EOF

    # 建立快速啟動腳本
    cat > $HOME/start-rclone.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Rclone 快速啟動選單

while true; do
    clear
    echo "╔═══════════════════════════════╗"
    echo "║      RCLONE 管理選單         ║"
    echo "╠═══════════════════════════════╣"
    echo "║ 1) 設定雲端帳號              ║"
    echo "║ 2) 掛載/卸載雲端硬碟         ║"
    echo "║ 3) 檔案管理                  ║"
    echo "║ 4) 查看設定                  ║"
    echo "║ 5) 測試連線                  ║"
    echo "║ 6) 建立桌面捷徑              ║"
    echo "║ 7) 查看教學                  ║"
    echo "║ 0) 退出                      ║"
    echo "╚═══════════════════════════════╝"
    
    read -p "請選擇 [0-7]: " choice
    
    case $choice in
        1) bash $HOME/setup-rclone.sh ;;
        2) bash $HOME/mount-rclone.sh ;;
        3) bash $HOME/rclone-manager.sh ;;
        4) 
            echo "設定檔位置: $HOME/.config/rclone/rclone.conf"
            echo "=== 當前設定 ==="
            rclone config show
            read -p "按 Enter 繼續..."
            ;;
        5)
            echo "測試所有雲端連線..."
            rclone listremotes | while read remote; do
                echo "測試 $remote ..."
                rclone lsd "$remote" 2>/dev/null && echo "✓ 正常" || echo "✗ 失敗"
            done
            read -p "按 Enter 繼續..."
            ;;
        6)
            echo "建立桌面捷徑..."
            cat > $HOME/.shortcuts/Rclone << 'SHORTCUT'
#!/data/data/com.termux/files/usr/bin/bash
cd $HOME
bash start-rclone.sh
SHORTCUT
            chmod +x $HOME/.shortcuts/Rclone
            echo "捷徑已建立到 Termux 桌面"
            ;;
        7)
            echo "=== 快速教學 ==="
            echo "1. 先執行「設定雲端帳號」"
            echo "2. 使用「掛載雲端硬碟」掛載到本地"
            echo "3. 使用「檔案管理」上傳/下載檔案"
            echo "4. 檔案會出現在: /sdcard/cloud-storage/"
            echo ""
            echo "常用指令:"
            echo "  rclone config          # 設定"
            echo "  rclone listremotes     # 列出雲端"
            echo "  rclone mount           # 掛載"
            echo "  rclone copy            # 複製"
            read -p "按 Enter 繼續..."
            ;;
        0)
            echo "再見！"
            exit 0
            ;;
        *)
            echo "無效選擇"
            ;;
    esac
done
EOF

    # 設定執行權限
    chmod +x $HOME/setup-rclone.sh
    chmod +x $HOME/mount-rclone.sh
    chmod +x $HOME/rclone-manager.sh
    chmod +x $HOME/start-rclone.sh
    
    echo -e "${GREEN}輔助腳本建立完成！${NC}"
}

# 安裝完成訊息和測試
show_completion() {
    echo -e "${BLUE}[7/7] 安裝完成！進行最後設定...${NC}"
    
    # 建立捷徑目錄
    mkdir -p $HOME/.shortcuts
    
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo -e "${GREEN}          Rclone 安裝完成！               ${NC}"
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}📁 主要腳本：${NC}"
    echo -e "  設定雲端: ${GREEN}./setup-rclone.sh${NC}"
    echo -e "  掛載管理: ${GREEN}./mount-rclone.sh${NC}"
    echo -e "  檔案管理: ${GREEN}./rclone-manager.sh${NC}"
    echo -e "  快速啟動: ${GREEN}./start-rclone.sh${NC}"
    echo ""
    echo -e "${YELLOW}📍 重要路徑：${NC}"
    echo -e "  設定檔: ${GREEN}~/.config/rclone/rclone.conf${NC}"
    echo -e "  掛載點: ${GREEN}~/storage/shared/cloud-storage/${NC}"
    echo ""
    echo -e "${YELLOW}🚀 快速開始：${NC}"
    echo "  1. 執行: ./start-rclone.sh"
    echo "  2. 選擇「1) 設定雲端帳號」"
    echo "  3. 使用 Web GUI 設定 (推薦)"
    echo ""
    echo -e "${YELLOW}⚠️  注意事項：${NC}"
    echo "  • 掛載前確認已授予儲存權限"
    echo "  • Web GUI 需在瀏覽器開啟: http://localhost:53682"
    echo "  • 按 Ctrl+C 停止掛載或 Web GUI"
    echo -e "${GREEN}══════════════════════════════════════════${NC}"
    
    # 測試 rclone 是否正常
    echo -e "${BLUE}測試安裝...${NC}"
    if command -v rclone >/dev/null 2>&1; then
        echo -e "✓ rclone 版本: $(rclone version | head -1)"
    else
        echo -e "✗ rclone 未安裝成功"
    fi
}

# 主安裝流程
main() {
    check_termux
    install_dependencies
    request_storage_permission
    setup_config
    create_helper_scripts
    show_completion
}

# 執行主程式
main "$@"

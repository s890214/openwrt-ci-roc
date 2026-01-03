# 修改默认IP & 固件名称 & 编译署名和时间
# sed -i 's/192.168.1.1/192.168.2.1/g' package/base-files/files/bin/config_generate
# sed -i "s/hostname='.*'/hostname='Roc'/g" package/base-files/files/bin/config_generate
sed -i "s#_('Firmware Version'), (L\.isObject(boardinfo\.release) ? boardinfo\.release\.description + ' / ' : '') + (luciversion || ''),# \
_('Firmware Version'), \
(L.isObject(boardinfo.release) ? boardinfo.release.description + ' / ' : '') + \
'Built by SONG88 $(date "+%Y-%m-%d")',#" feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js

# 移除luci-app-attendedsysupgrade软件包
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")

# 调整NSS驱动q6_region内存区域预留大小（ipq6018.dtsi默认预留85MB，ipq6018-512m.dtsi默认预留55MB，带WiFi必须至少预留54MB，以下分别是改成预留16MB、32MB、64MB和96MB）
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x01000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x02000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x04000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi
# sed -i 's/reg = <0x0 0x4ab00000 0x0 0x[0-9a-f]\+>/reg = <0x0 0x4ab00000 0x0 0x06000000>/' target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq6018-512m.dtsi

# 移除要替换的包
rm -rf feeds/luci/applications/luci-app-argon-config
rm -rf feeds/luci/applications/luci-app-wechatpush
rm -rf feeds/luci/applications/luci-app-appfilter
rm -rf feeds/luci/applications/luci-app-watchcat
rm -rf feeds/luci/applications/luci-app-frpc
rm -rf feeds/luci/applications/luci-app-frps
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/packages/net/open-app-filter
rm -rf feeds/packages/net/ariang
rm -rf feeds/packages/net/frp
rm -rf feeds/packages/lang/golang
rm -rf feeds/packages/utils/watchcat

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

# 下载并更新 clash_meta
update_clash_meta() {
    echo "更新 clash_meta ..."
    mkdir -p files/etc/openclash/core
    CLASH_META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz"
    wget -qO- $CLASH_META_URL | tar xOvz > files/etc/openclash/core/clash_meta
    chmod +x files/etc/openclash/core/clash*
}

fix_nss_ecm_stats() {
    echo "-------------------------------------------------------"
    echo "正在执行 NSS 流量统计修复..."

    # 1. 查找所有匹配的文件路径（从 OpenWrt 源码根目录搜索）
    local file_list=$(find . -name Makefile | grep "/qca-nss-ecm/Makefile")

    # 2. 统计数量 (处理空结果的情况)
    if [ -z "$file_list" ]; then
        local count=0
    else
        local count=$(echo "$file_list" | wc -l)
    fi

    echo "共找到 [ $count ] 个 qca-nss-ecm/Makefile 文件。"

    if [ "$count" -eq 0 ]; then
        echo "警告：未找到任何目标文件，跳过修正！"
        return
    fi

    # 3. 循环处理每一个文件
    # 使用 while read 逐行读取文件路径，防止路径带空格出错（虽然这里不太可能有空格）
    echo "$file_list" | while read -r ecm_makefile; do
        # 跳过空行
        [ -z "$ecm_makefile" ] && continue

        echo "正在检查文件: $ecm_makefile"

        # 4. 幂等性检查：防止重复修改
        if grep -q "ECM_NON_PORTED_TOOLS_SUPPORT" "$ecm_makefile"; then
            echo "  -> 跳过：代码已包含流量统计补丁。"
        else
            # 5. 执行修改
            sed -i 's/EXTRA_CFLAGS+=/EXTRA_CFLAGS+= -DECM_NON_PORTED_TOOLS_SUPPORT -DECM_STATE_OUTPUT_ENABLE -DECM_DB_CONNECTION_CROSS_REFERENCING_ENABLE /g' "$ecm_makefile"

            # 再次检查修改是否成功
            if grep -q "ECM_NON_PORTED_TOOLS_SUPPORT" "$ecm_makefile"; then
                 echo "  -> 成功：编译参数已修正。"
            else
                 echo "  -> 错误：修改失败，请检查 sed 命令。"
            fi
        fi
    done
    echo "-------------------------------------------------------"
}

# ariang & frp & Watchcat & WolPlus & Argon & Aurora & Go & OpenList & Lucky & wechatpush & OpenAppFilter & 集客无线AC控制器 & 雅典娜LED控制
git_sparse_clone ariang https://github.com/laipeng668/packages net/ariang
git_sparse_clone frp https://github.com/laipeng668/packages net/frp
mv -f package/frp feeds/packages/net/frp
git_sparse_clone frp https://github.com/laipeng668/luci applications/luci-app-frpc applications/luci-app-frps
mv -f package/luci-app-frpc feeds/luci/applications/luci-app-frpc
mv -f package/luci-app-frps feeds/luci/applications/luci-app-frps
git_sparse_clone openwrt-23.05 https://github.com/immortalwrt/packages utils/watchcat
mv -f package/watchcat feeds/packages/utils/watchcat
git_sparse_clone openwrt-23.05 https://github.com/immortalwrt/luci applications/luci-app-watchcat
mv -f package/luci-app-watchcat feeds/luci/applications/luci-app-watchcat
git_sparse_clone main https://github.com/VIKINGYFY/packages luci-app-wolplus
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon feeds/luci/themes/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config feeds/luci/applications/luci-app-argon-config
git clone --depth=1 https://github.com/eamonxg/luci-theme-aurora feeds/luci/themes/luci-theme-aurora
git clone --depth=1 https://github.com/eamonxg/luci-app-aurora-config feeds/luci/applications/luci-app-aurora-config
git clone --depth=1 https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 package/openlist2
git clone --depth=1 https://github.com/gdy666/luci-app-lucky package/luci-app-lucky
git clone --depth=1 https://github.com/tty228/luci-app-wechatpush package/luci-app-wechatpush
git clone --depth=1 https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter
git clone --depth=1 https://github.com/lwb1978/openwrt-gecoosac package/openwrt-gecoosac
git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led package/luci-app-athena-led
chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led package/luci-app-athena-led/root/usr/sbin/athena-led

git clone --depth=1 https://github.com/timsaya/openwrt-bandix package/openwrt-bandix
git clone --depth=1 https://github.com/timsaya/luci-app-bandix package/luci-app-bandix

### PassWall & OpenClash ###

# 移除 OpenWrt Feeds 自带的核心库
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall-packages package/passwall-packages

# 下载并更新 clash_meta
update_clash_meta

# 移除 OpenWrt Feeds 过时的LuCI版本
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-openclash
git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall package/luci-app-passwall
git clone --depth=1 https://github.com/xiaorouji/openwrt-passwall2 package/luci-app-passwall2
git clone --depth=1 https://github.com/vernesong/OpenClash package/luci-app-openclash

# 清理 PassWall 的 chnlist 规则文件
echo "baidu.com"  > package/luci-app-passwall/luci-app-passwall/root/usr/share/passwall/rules/chnlist

# 先更新并安装 feeds (确保目录结构完整且是最新版本)
./scripts/feeds update -a
./scripts/feeds install -a

# 最后执行 NSS 流量统计修复 (确保修改的是最终文件)
fix_nss_ecm_stats

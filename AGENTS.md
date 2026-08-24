# sonic170 灯光控制工程 — 交接主文件(快速上手)

> **用途**:每轮会话必读的框架规范(项目背景/工具链/协议/纪律/待办),精简自技术交接手册。
> **历史演进**:来龙去脉、调试史、经验教训见 `C:\Users\kevin-3080\Desktop\sonic交接-历史档案.md`(按需检索,勿全文读)。

---

## 一、项目定位

| 项 | 值 |
|----|----|
| 项目 | sonic170 热插拔键盘灯光系统:网页配置工具 + QMK 固件三区域独立灯控 |
| 网页工具 | **`K:\0AMAC\github-opensource\sonic170-v2\sonic170v2-rgb-control.html`**(单文件、零依赖、WebHID、中英双语,约 1.86MB,含内嵌 VIA json) |
| 固件 | `K:\qmk-k2\keyboards\kindlestar\sonic170hotswap\`(分支 `feat/upgrade-qmk-0.33`) |
| 姊妹版 | `K:\qmk-k2\keyboards\kindlestar\sonic170solder\`(焊接版,PID 0x0072,与 hotswap 同源同步) |
| MCU | STM32F411xE(96MHz;链接脚本名 STM32F401xE_CUSTOM,实际 512KB Flash / 128KB RAM) |
| 灯区 | Pad 矩阵(LED 4-152,13×13 网格 149 有效格)、Side 侧边灯条(LED 1-3)、CapsLock 灯(LED 0) |
| 开源 | GitHub `709208969/sonic170-v2`(MIT)+ Gitee `kevinxu93/sonic170-v2`;网页"检查 GitHub 更新"填 `709208969/sonic170-v2` |

**核心设计原则**:网页一切操作即时生效(设置 change 即发;图案编辑停止 800ms 自动发送;帧动画需点「上传到键盘」)。

**当前状态(2026-08-25)**:
- 固件 **4.9.0**(hotswap 63,748B / solder 62,688B;**cfg 区窗口协议**:value_id 44=元信息(layout_version+cfg_size+写拒绝计数)/45=窗口读/46=窗口写,白名单仅 pad_pattern_cfg 区 56B,读写校验布局版本(RGB_CONTROL_LAYOUT_VERSION=1),写后固件做 mode 回落校验(与 setter 同语义)+激活图案逐字段投影(零副作用,不触发雨滴重 init/动画槽激活);改键/宏走 channel 1 不受影响;真机待验证)
- 网页 **v47.45**(1,880,676B;v47.43 图案配置暂存区 + v47.44 未上传修改提示/传输统计 + **v47.45 窗口协议主流程**:4.9.0+ 固件全量读取 3 条命令零切图案零闪灯,46 批量写接入清除动画;旧固件自动降级 v47.43 切图案流程;待真机验证)
- 磨损评估:正常使用 40 年+,不会变砖(bootloader 不可擦除 + 网页 DFU 可恢复)

---

## 二、环境与工具链

### 固件编译(QMK MSYS bash 脚本方式,勿用内联 -c)
```bash
export MSYSTEM=MINGW64
export PATH=/mingw64/bin:/usr/bin:/bin:$PATH
cd /k/qmk-k2 || exit 1
make kindlestar/sonic170hotswap:via -j18 2>&1 | tail -30
```
solder 版:`make kindlestar/sonic170solder:via -j18`
脚本模板见全局规则(QMK MSYS bash 方式,含 SHELL 导出)。

### 烧录
- 进 DFU:插拔时按住 Esc(bootmagic matrix [0,0])
- `& "C:\Program Files\dfu-util-0.9-win64\dfu-util.exe" -d 0483:df11 -a 0 -s 0x08000000:leave -D <产物.bin>` 或 QMK Toolbox
- 网页内置 DFU:DfuSe 协议(ERASE_SECTOR=0x41、SET_ADDRESS=0x21,非 AN3156)

### 网页验证
- 提取 `<script>` 后 `node --check`(排除 `<script type="application/json">` 数据块)
- HTML 标签配对(div 127/127 最近)
- 改完协议必须 **Ctrl+F5 强刷**(旧缓存索引错位卡死 enqueue 队列)
- 必须 **file:// 双击打开**(http://localhost 与 file:// 的 localStorage 隔离,动画库会"丢失")

### DFU suffix / 版本注入(已配置)
- `DFU_SUFFIX_ARGS` + `BUILD_DATE :=`(时间戳竞态修复)
- `OPT_DEFS += -DFIRMWARE_VERSION_STR=\"$(FIRMWARE_VERSION)\"`(诊断页版本上报)

---

## 三、架构与协议速查

### VIA channel 0 value_id 速查
| 区间 | 用途 |
|------|------|
| 1-11 | 基础 |
| 12-20 | 打字反馈 |
| 21-30 | 总开关 + Pad/Caps 常态 |
| 31-34 | 帧动画流式(只写 RAM,不写 EEPROM) |
| 35 | 播放速率 |
| 36 | 工厂重置 |
| 37 | 设备诊断(v40 起网页不再调用,保留产测) |
| 38/39 | 动画亮度 |
| 40 | 资源/磨损诊断(Flash 容量=**编译期常量**,勿读寄存器) |
| 41 | 动画缓冲读取(块号 **bit15=槽号** 0/1;无 bit15=旧语义读激活槽 RAM) |
| 42 | 清除动画槽(写 0xFFFF magic) |
| **43** | **通信诊断(set/get 计数 + lastSetId)**——新增 value_id 只能从 43 起 |
| 44 | cfg 元信息 get(layout_version u16 + cfg_size + 窗口写拒绝计数 u16) |
| 45 | cfg 窗口读 get(offset+len≤27 → 回显 version+data;版本/越界不符 → version=0xFF) |
| 46 | cfg 窗口写 set(offset+len+version+data≤25;版本不符/越界 → 拒绝计数,不改数据) |

### EEPROM / wear-leveling 布局
- `EECONFIG_KB_DATA_SIZE` = 265(含 per-pattern cfg 56B);帧动画独立区 `ANIM_EEPROM_ADDR=4096`
- **双动画槽定长**:槽1@4096、槽2@30923(各 magic 2B + count 1B + crc 4B + ≤60×447B = 26827B)
- 逻辑空间 **64KB**,backing 128KB = 扇区 7 整块(0x60000-0x80000),`PVD_DIAG_BACKING_BASE=0x08060000`
- **物理上限**:backing 起点由驱动从 Flash 末尾向前数扇区(wear_leveling_efl.c),单扇区 128KB 是硬上限;再扩会撞固件代码区,灾难性——**扩容需全片擦除**

### 帧动画规则(v47 定稿)
- 上传目标 = **当前图案槽**(图案 3/4 → 槽 0/1;上传前网页先切图案);仅图案 3/4 能播放帧动画,无动画时即普通图案
- RAM 缓冲仅 1 份(26.2KB),切槽时 EEPROM 加载(<1ms);老单区动画天然成为槽 1(零迁移)
- 持久化:头部 7B 立即写 + `rgb_animation_save_task()` 由 housekeeping 每轮写 32B
- 清除:`rgb_animation_clear` 在 active_slot<0 时清两个槽

### per-pattern 灯光配置(v47)
- `pad_pattern_cfg[8]×7B`(hue/sat/val/mode/speed + anim_cell/matrix_alpha);切图案投影到全局字段(渲染零改动)
- 雨滴系(21/22)切图案强制重 init(`s_region_effect_last=0xFF`);非动画槽 mode 31 强制回落 0

### Pad 快捷键(v47)
FN1 层 6 键:亮度± / 速度± / 颜色(hue+16 wrap) / 模式循环 0-30(跳过 31);hotswap 在右上导航区,solder 在 row1 4-9 位(布局不同按行号提取)

### 模式编号语义(0-29)
0 单色 / 1 呼吸 / 2 上下循环 / 3 左右循环 / 4 循环全部 / 5 上下渐变 / 6 左右渐变 / 7 彩虹人字纹 / 8 内外循环 / 9 双内外 / 10 风车 / 11 螺旋 / 12 双信标 / 13 彩虹信标 / 14 彩虹风车 / 15 饱和色带 / 16 亮度色带 / 17/18 风车饱和/亮度带 / 19/20 螺旋饱和/亮度带 / 21 雨滴 / 22 彩虹雨滴 / 23 色相呼吸 / 24 色相钟摆 / 25 色相波浪 / 26 像素分形 / 27 像素雨 / 28 星光 / 29 花开
- **30=打字反馈(Flicker,Pad/Side)**、**31=帧动画(Pad)**、**Caps 31=Flicker**、Caps 30=关闭

### 打字反馈子模式(v46.1 定稿)
- Pad 2 闪烁 / 3 逐行渐变 / 4 中间发散 / 7 彩虹循环;Side 2/3/7;Caps 2/7
- **打字反馈仅 Flicker 灯效模式生效**(v46.9);打字色已取消,统一取灯效配置色
- 值域:Pad 0-8、Side/Caps 0-7

### 灯板自绘效果(全部在 rgb_control.c 内,不动 QMK 内核)
- 21/22 雨滴:周期全屏重随机 hue/sat(speed 0-255 → 130-600ms)
- 26 分形:13×13 中心镜像生长;27 像素雨:黑底 + 周期 100-600ms 随机单灯
- 28 星光:每灯固定随机相位 + 全灯明暗闪烁
- **初始化型效果切换时 init 一次**(每帧 init 会导致状态重置/闪烁)

### Side y 轴自绘(v47.1)
模式 5/15/16/24/25 用 `pos=i*128` 竖轴(3 灯 x 全同 32 上 QMK 原算法退化);网页 sideYEffect 同步同公式

### 画布/预览方向
Tab3 画布水平=col、垂直=row、行0=顶;simEffect 坐标 **nx=row=垂直、ny=col=水平**、px=ny*64、py=nx*64

### 设备诊断(value_id 40)
Flash 总容量 512KB(**编译期常量**)/固件占用(链接符号 `__textdata_base__+(_edata-_data)`)/动画占用/剩余/RAM/uptime/版本串/磨损%

### QMK 0.33 命令码(调试手动测试用)
**自定义命令码 = 0x07=SET / 0x08=GET(非标准 VIA 的 0x08/0x09!)**;Console 可调 `sendViaCommand(0x08, 0, 43)` 手动验证

---

## 四、纪律与约束(15 条)

1. **协议禁改**:value_id 1-41 报文结构、typing 12-20、channel 3、`rgb_control_notify_key_press()`;31-34 只写 RAM;新增只能从 43 起
2. **EEPROM**:字段 append;EECONFIG_KB_DATA_SIZE 与 RGB_CONTROL_EEPROM_SIZE 同步;锚点迁移
3. **内核改动最小化**:禁改 animations/*.h、effects.inc(自绘效果全部在 rgb_control.c 内实现)
4. **行为事实禁止脑补**:先 grep 实码
5. **防谎报**:编译 ≠ 完成;真机未测标「未实测」
6. **git**:先 git status;不主动提交
7. **.bat**:unix2dos + iconv GBK
8. **网页即时生效**:除帧动画上传外无手动发送按钮
9. **未定项停手**
10. **文档纪律**:会话结束更新本文件 + 历史档案 + 记录文件大小
11. **诊断纪律**:只许观测(禁止诊断固件真实 Flash 写入)
12. **网页单文件**:开始核对大小/锚点,结束记录
13. **固件版本号纪律**:每次固件改动必须 bump rules.mk FIRMWARE_VERSION(两版一致)——功能 minor+1、修复 patch+1
14. **单板修复必须同步姊妹板**(v46.12 教训:solder 缺修复 → 上传卡死)
15. **网页版本号纪律(v47.1 起)**:每次网页代码任何更新 bump 版本号(十进制 patch+1,每 10 次主版本+1、patch 归 0)——同步更新 `<title>` + `appVersionBadge`。**当前 v47.45**

---

## 五、已知问题与待办

| 项 | 状态 |
|----|------|
| solder 4.8.2 烧录验证 | ⬜ 待烧录 |
| 固件 4.8.2 真机验证(双槽读取/清除单槽/半写清理) | ⬜ 待烧录复测 |
| v47.41 真机复测(双槽动画读取播放/清除图案4不影响图案3/自动重传/版本提示) | ⬜ 待复测 |
| Side y 轴 5/15/16/24/25 观感、Caps 精简回填 | ⬜ 待真机 |
| 磨损% 显示(value_id 40 wear 字段) | ⬜ 待验证 |
| value_id 41 动画同步、拔出检测弹窗真机 | ⬜ 待验证(曾部分验证) |
| 打字显示字形(方案 B) | 待开发:13×13 点阵字库 |
| json 菜单缺失 | VIA 无菜单(用户决定不补) |
| 固件 git 状态 | v2-v47 全部未提交 |
| 杂物清理 | solder 多余 `sonic170_via_hotswap.json`、hotswap `keymap.c.bak`、solder keymap 首行 BOM 无害 |

**注意事项(下轮必记)**:
- 网页必须 file:// 打开 + Ctrl+F5 强刷(标题栏应显示 v47.45)
- **v4.9.0 cfg 窗口协议契约**:偏移 = cfg 区相对偏移(图案 i × 7 + 字段: hue0/sat1/val2/mode3/speed4/animCell5/animMatrix6);`RGB_CONTROL_LAYOUT_VERSION=1`(固件 rgb_control.h + 网页 CFG_LAYOUT_VERSION 双端,布局变更双端同步 +1);窗口写后固件自动 mode 回落(非动画槽 31→0)+ 激活图案逐字段投影(不触发雨滴重 init/动画槽激活);46 写 ≤25B/条;动画上传期间禁 45/46(v7 中止规则);网页与 VIA 不能同时操作(共享 channel 0)
- **v4.9.0 以后不动固件的边界**:图案配置(cfg 区)读写零改动;加 cfg 字段 = 网页单端同步偏移表;加全局字段/新存储区段仍需固件(评估存储预算:64KB 逻辑区已用 ~54KB,剩 ~10KB,超预算=backing 扩容=全片擦除灾难)
- **v47.45 网页窗口主流程**:连接 → 等 fwVersionDetected(3s) → firmwareSupportsWindowProto()(≥4.9.0)→ 44 元信息校验 → 45 读 56B(3 条)→ 缓存;旧固件降级 syncAllPatternConfigsLegacy(切图案流程);清除动画用 46 批量写(旧固件降级 setter)
- **v47.44 用时测量**:连接后日志栏输出每图案 cfg 耗时 + 总计;Console 调 `window.sonicTransportStats()` 看全部命令传输统计(条数/平均/最大/总时长/超时数)——窗口协议全量读取 ~3 条命令 <100ms;超时数>0 说明固件忙(consolidation)曾阻塞
- **v47.44 未上传修改提示**:liveSync 关闭时修改当前图案设置 → 图案提示追加"有未上传到键盘的修改,切换图案将舍弃";上传/清除动画/恢复出厂/导入后自动消失;切图案(舍弃)后消失
- **v47.43 图案配置暂存区**:`patternCfgCache[8]`(连接时 syncAllPatternConfigs 全量读取,切 8 次图案读配置后切回,连接瞬间键盘灯效闪动 1-2s 属正常);切图案 = discardPatternCfgPending(舍弃未应用修改) → 应用缓存目标图案配置(秒切不发命令);无缓存时 liveSync 开启回读固件 / 关闭临时切读兜底(loadPatternCfgWithSwitch);pad 设置事件(mode/亮度/颜色/速度/动画亮度)调 touchPatternCfg 更新缓存 + 待应用标记;上传/清除动画/上传动画/恢复出厂/导入设置成功后 commitPatternCfg 清待应用——**切图案必舍弃待应用,暂存区永远保持与键盘一致**(修复"切图案残留上一图案灯效误覆盖目标图案")
- **v47.43 sendReport 超时保护**:`hidDevice.sendReport` 挂起(固件 consolidation 等 USB 忙)时 7s 超时放弃 + 清 pendingReport,防挂起堆积/迟到回显错配导致 enqueue 8s 超时后队列持续不健康;动画槽图案读取失败(队列超时)3s 后自动重试一次恢复预览
- **v47.42 按槽动画备份**:上传动画自动写入 localStorage `sonic170_anim_slot_backup`(清除动画时删除);重连时固件槽空且有备份 → checkAnimAutoRetrans 自动重传(按当前图案取备份,不依赖用户库 ANIM_CUR_KEY)
- **v47.42 固件版本降级**:fwVersionDetected(连接时 getDevInfo2 记录);firmwareSupportsDualSlot() 判断 <4.8.2 不读槽 0(旧固件 bit15 冲突,槽 0 不可达);syncKeyboardToPageInner 等待版本检测(3s 超时按未知处理)
- **网页内嵌固件 bin 已更新 4.8.2**(FW_DL_B64/FW_DL_B64_SOLDER + 下载名 + EMBED_FW_VERSION 同步);固件更新后需同步更新内嵌 bin(生成脚本:base64 编码 + 解码长度校验)
- v47.41 双槽动画协同:value_id 41 块号编码 `block|0x4000|(slot<<15)`(bit14=EEPROM 标志、bit15=槽号),固件解码必须同步;clearAnimBtn 必须先 setPadPatternIndex(curPat) 再 VID_ANIM_CLEAR;readAnimSlot 有 CRC 校验(损坏数据拒收)
- **enqueue 嵌套死锁教训(v47.32)**:enqueue 任务内禁止再调 enqueue(内层等外层 hidQueue、外层等内层 → 8s 超时打破,连带队列任务集体超时)——入队必须单层,如 `enqueue(getDevInfo2)` 且 getDevInfo2 内部不得 enqueue
- withTimeout 定时器必须在 race 后 clearTimeout,否则任务完成后仍误报超时日志
- 状态同步超时只提示,不回滚控件(syncAllState 超时后自身仍会跑完回填,以键盘真实状态为准);预览灰屏由 animSlotCache 兜底播放
- v47.31 日志栏:上传/图案发送不再清空日志(旧行为丢调试信息),改用日志栏右上「清空」按钮;日志 2000 行上限裁剪时优先保留错误行并插入裁剪提示;滚动条为 #log 专属高对比样式
- v47.30 userModified 机制:连接后后台同步回填与用户操作竞态(用户编辑/上传/设置后,旧值回填覆盖本地 → 上传后预览灰/动画不播放)——任何用户操作后 readWithRetry 返回 null、readPatternSlot 丢弃读回结果
- v47.29 实时同步开关语义变更:默认关闭 = 改动仅本地预览,点「上传到键盘」全量同步;开启 = 立即下发(旧版无差别自动下发)
- 方向预览注意:网页布局列 col ≠ 固件列 b[4](每行偏移不同),方向旋转必须按固件坐标反查布局坐标(FW_TO_LAYOUT)
- 动画上传/大量写入后可能触发 EEPROM consolidation(固件 USB 阻塞 ≤30s)——**网页 enqueue 8s 超时自愈,正常现象勿误判固件故障**
- 连接流程超时:syncAllState 15s / syncKeyboardToPage 20s;队列 disconnect 时重置
- solder keymap 与 hotswap 布局不同(19 列/UG_* 键),修改按行号提取不可直接复制
- value_id 41 的 solder keymap 分支必须与 hotswap 同步(v48 教训)

---

## 六、历史档案检索指引

以下场景**必须**去读 `C:\Users\kevin-3080\Desktop\sonic交接-历史档案.md`(用 grep 定位章节,勿全文读):

| 场景 | 档案关键词 |
|------|-----------|
| 改协议/加 value_id 前 | 纪律、演进记录 |
| 排查"命令不生效/设置失效" | consolidation、教训 34-37、v48.1 |
| 改灯效渲染/预览 | v46 演进、simEffect 轴向、教训 25 |
| EEPROM 扩容/布局变更 | 教训 29/37、v47 扩容 |
| 网页端上传/同步流程 | v42-v48 演进、教训 26/27 |
| 调试固件通信 | value_id 43、命令码 0x07/0x08、v48.1 |
| 想了解"为何这样设计" | 全部演进记录 |

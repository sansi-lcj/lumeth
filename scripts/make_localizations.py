#!/usr/bin/env python3
import glob
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESOURCES = os.path.join(ROOT, "Resources")
CACHE = os.path.join(ROOT, "scripts", "translation-cache.json")

LOCALES = [
    ("en", "en"),
    ("zh-Hans", "zh-CN"),
    ("zh-Hant", "zh-TW"),
    ("ja", "ja"),
    ("ko", "ko"),
    ("fr", "fr"),
    ("de", "de"),
    ("es", "es"),
    ("it", "it"),
    ("pt-BR", "pt"),
    ("ru", "ru"),
    ("ar", "ar"),
    ("hi", "hi"),
    ("th", "th"),
    ("vi", "vi"),
    ("id", "id"),
    ("tr", "tr"),
    ("pl", "pl"),
]

EN = {
    "总览": "Overview",
    "处理器": "Processor",
    "内存": "Memory",
    "内存简": "Memory",
    "网络": "Network",
    "传感器": "Sensors",
    "系统": "System",
    "传感": "Sensors",
    "实时状态与关键指标": "Live status and key metrics",
    "逐核占用、负载与进程": "Per-core usage, load, and processes",
    "内存构成、压力与交换": "Memory composition, pressure, and swap",
    "实时吞吐与链路状态": "Live throughput and link state",
    "温度传感器与散热状态": "Temperature sensors and thermal state",
    "磁盘、图形、电池与本机": "Disk, graphics, battery, and device",
    "面板与刷新": "Panel and refresh",
    "退出流衡": "Quit Lumeth",
    "实时": "Live",
    "正在初始化": "Initializing",
    "采样 %.0f ms": "Sample %.0f ms",
    "本机读取": "On-device",
    "每 %d 秒": "Every %d s",
    "温度": "Temperature",
    "等待传感器": "Waiting for sensor",
    "处理器核心最高": "Hottest CPU core",
    "图形处理器": "GPU",
    "占用 %@": "In use %@",
    "暂不可用": "Unavailable",
    "运行 %@": "Uptime %@",
    "%@ 可用": "%@ free",
    "进程排行": "Top processes",
    "实时态势": "Live overview",
    "处理器总占用": "Total CPU usage",
    "用户 %.1f%%": "User %.1f%%",
    "系统 %.1f%%": "System %.1f%%",
    "负载 %.2f · %.2f · %.2f": "Load %.2f · %.2f · %.2f",
    "%d 性能 + %d 能效": "%d performance + %d efficiency",
    "总占用": "Total usage",
    "用户": "User",
    "空闲": "Idle",
    "负载 1m": "Load 1m",
    "核心矩阵": "Core matrix",
    "等待首个处理器采样…": "Waiting for the first CPU sample…",
    "处理器历史": "CPU history",
    "已用": "Used",
    "共 %@": "of %@",
    "交换 %@ / %@": "Swap %@ / %@",
    "内存构成": "Memory composition",
    "应用": "App",
    "联动": "Wired",
    "压缩": "Compressed",
    "缓存": "Cached",
    "内存历史": "Memory history",
    "详情": "Details",
    "可用": "Available",
    "交换已用": "Swap used",
    "内存压力：%@": "Memory pressure: %@",
    "下载": "Download",
    "累计 %@": "Total %@",
    "上传": "Upload",
    "带宽波形": "Bandwidth",
    "连接": "Connection",
    "网卡": "Interface",
    "链路": "Link",
    "已连接": "Connected",
    "未连接": "Disconnected",
    "在线": "Online",
    "离线": "Offline",
    "采样与吞吐": "Sampling and throughput",
    "接收": "Received",
    "发送": "Sent",
    "采样": "Sample",
    "热度": "Thermal",
    "暂无温度传感器": "No temperature sensors",
    "%d 个传感器 · 无需 root": "%d sensors · no root",
    "风扇转速与控制需要特权 SMC 助手。流衡通过无需 root 的 HID 路径读取温度，不安装后台守护进程。": (
        "Fan control requires a privileged SMC helper. Lumeth reads temperatures "
        "through the root-free HID path and installs no background daemon."
    ),
    "磁盘": "Disk",
    "读取": "Read",
    "写入": "Write",
    "%@ 已用": "%@ used",
    "%@ 总计": "%@ total",
    "利用率": "Utilization",
    "占用": "In use",
    "已分配": "Allocated",
    "此 Mac 暂不提供图形处理器统计。": "GPU statistics are unavailable on this Mac.",
    "电池": "Battery",
    "正在充电": "Charging",
    "已接通电源": "Power adapter",
    "使用电池": "On battery",
    "预计充满 %@": "%@ to full",
    "预计剩余 %@": "%@ remaining",
    "已充满": "Fully charged",
    "循环": "Cycles",
    "健康度": "Health",
    "无内置电池。": "No built-in battery.",
    "关于本机": "About this Mac",
    "主机": "Host",
    "型号": "Model",
    "芯片": "Chip",
    "运行": "Uptime",
    "正在采集进程…": "Collecting processes…",
    "正常": "Normal",
    "偏高": "Elevated",
    "严重": "Critical",
    "未知": "Unknown",
    "存储": "Storage",
    "主板": "Logic board",
    "环境": "Ambient",
    "其他": "Other",
    "%d天 %02d:%02d": "%dd %02d:%02d",
    "计算中…": "Calculating…",
    "流衡": "Lumeth",
    "收起面板": "Collapse panel",
    "处理器核心": "CPU core",
    "主板传感器": "Logic board sensor",
    "SSD 闪存": "SSD flash",
    "环境光": "Ambient light",
    "温标校准": "Temperature calibration",
    "流衡设置": "Lumeth Settings",
    "刘海面板、折叠内容与采样频率": "Notch panel, compact metrics, and sampling",
    "刘海面板": "Notch panel",
    "待机贴合刘海；点击展开完整面板。点击外部或按 Esc 收回。": (
        "Sits against the notch at rest. Click to open the full panel. "
        "Click outside or press Esc to close."
    ),
    "折叠时显示": "Show when compact",
    "占用曲线与百分比": "Usage graph and percentage",
    "内存压力与使用量": "Memory pressure and usage",
    "实时下载与上传速率": "Live download and upload rates",
    "无需权限的最高温度": "Hottest sensor without permissions",
    "刷新间隔": "Refresh interval",
    "%d 秒": "%d s",
    "流衡（Lumeth）只在本机读取系统计数器、IOKit 统计与无需权限的 HID 温度事件。无分析上报，也不发起网络请求。": (
        "Lumeth reads system counters, IOKit statistics, and permission-free HID "
        "temperature events locally. No analytics are uploaded and no network "
        "requests are made."
    ),
    "完成": "Done",
    "最高": "Peak",
    "历史范围": "History range",
    "均值 %@": "Avg %@",
    "峰值 %@": "Peak %@",
    "下载均速 %@ · 峰值 %@": "Down avg %@ · peak %@",
    "上传均速 %@ · 峰值 %@": "Up avg %@ · peak %@",
    "本机地址": "Local address",
    "活跃接口": "Active interfaces",
    "主接口": "Primary",
    "无本机地址": "No local address",
    "CPU 最高": "CPU peak",
    "GPU 最高": "GPU peak",
    "全机平均": "System average",
    "读取峰值 %@": "Read peak %@",
    "写入峰值 %@": "Write peak %@",
    "刘海面板、历史、提醒与采样频率": (
        "Notch panel, history, alerts, and sampling"
    ),
    "智能提醒": "Smart alerts",
    "处理器持续偏高": "Sustained high CPU",
    "超过阈值并持续一段时间后提醒": (
        "Notify after the threshold stays exceeded for a set duration"
    ),
    "内存压力持续偏高": "Sustained memory pressure",
    "内存压力达到偏高或严重时提醒": (
        "Notify when memory pressure reaches elevated or critical"
    ),
    "温度持续偏高": "Sustained high temperature",
    "最高温度传感器超过阈值后提醒": (
        "Notify when the hottest sensor stays above the threshold"
    ),
    "电池电量偏低": "Low battery",
    "使用电池且低于阈值时提醒": (
        "Notify on battery power when the charge falls below the threshold"
    ),
    "处理器阈值": "CPU threshold",
    "温度阈值": "Temperature threshold",
    "电池阈值": "Battery threshold",
    "持续时间": "Duration",
    "处理器负载持续偏高": "Sustained high CPU load",
    "处理器已高于 %@，持续 %@。": "CPU has stayed above %@ for %@.",
    "当前内存压力为 %@，已持续 %@。": "Memory pressure has been %@ for %@.",
    "最高传感器温度为 %@，已持续 %@。": (
        "The hottest sensor has been %@ for %@."
    ),
    "当前电量为 %@，请连接电源。": "Battery is at %@. Connect a power adapter.",
    "提醒使用 macOS 本地通知；如未收到，请在系统设置中允许 Lumeth 通知。": (
        "Alerts use local macOS notifications. If you do not see them, "
        "allow Lumeth notifications in System Settings."
    ),
}

FORMAT_RE = re.compile(
    r"%(?:%|[-+ #0]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|L|z|t|j)?[@diuoxXfFeEgGaAcCsSp])"
)

INFO_DESCRIPTION = (
    "Lumeth only reads local network interface counters to show network activity. "
    "It does not scan or connect to other devices."
)
INFO_COPYRIGHT = (
    "Lumeth · Independent native system monitor. Not affiliated with iStat Menus."
)

ZH_HANT_RULES = [
    ("內存", "記憶體"),
    ("網絡", "網路"),
    ("傳感器", "感測器"),
    ("圖形處理器", "繪圖處理器"),
    ("設置", "設定"),
    ("磁盤", "磁碟"),
    ("用戶", "使用者"),
    ("內置", "內建"),
    ("緩存", "快取"),
    ("進程", "程序"),
    ("連接", "連線"),
    ("網卡", "網路介面"),
    ("聯動", "有線"),
    ("空閒", "閒置"),
    ("主板", "主機板"),
    ("芯片", "晶片"),
    ("型號", "機型"),
    ("存儲", "儲存"),
    ("詳情", "詳細資料"),
    ("採樣", "取樣"),
    ("採集", "收集"),
    ("刷新", "重新整理"),
    ("閃存", "快閃記憶體"),
    ("循環", "循環次數"),
    ("健康度", "健康狀態"),
    ("利用率", "使用率"),
    ("劉海", "瀏海"),
    ("收起面板", "收合面板"),
    ("折疊時顯示", "收合時顯示"),
    ("已充滿", "已充飽"),
    ("預計充滿", "預計充飽"),
    ("已接通電源", "已接上電源"),
    ("熱度", "散熱"),
    ("運行", "執行時間"),
    ("已用", "已使用"),
]

ZH_HANT_OVERRIDES = {
    "总览": "總覽",
    "传感器": "感測器",
    "传感": "感測",
    "内存": "記憶體",
    "内存简": "記憶體",
    "图形处理器": "繪圖處理器",
    "应用": "應用程式",
    "联动": "有線",
    "缓存": "快取",
    "网卡": "網路介面",
    "存储": "儲存",
    "主板": "主機板",
    "循环": "循環次數",
    "健康度": "健康狀態",
    "详情": "詳細資料",
    "流衡": "流衡",
    "流衡设置": "流衡設定",
    "退出流衡": "結束流衡",
    "面板与刷新": "面板與重新整理",
    "刷新间隔": "重新整理間隔",
    "折叠时显示": "收合時顯示",
    "热度": "散熱",
    "刘海面板": "瀏海面板",
    "刘海面板、折叠内容与采样频率": "瀏海面板、收合內容與取樣頻率",
    "待机贴合刘海；点击展开完整面板。点击外部或按 Esc 收回。": "待機時貼合瀏海；點擊展開完整面板。點擊外部或按 Esc 收回。",
    "运行 %@": "執行時間 %@",
    "运行": "執行時間",
    "已充满": "已充飽",
    "预计充满 %@": "預計充飽 %@",
    "已接通电源": "已接上電源",
    "此 Mac 暂不提供图形处理器统计。": "此 Mac 暫不提供繪圖處理器統計。",
    "风扇转速与控制需要特权 SMC 助手。流衡通过无需 root 的 HID 路径读取温度，不安装后台守护进程。": "風扇轉速與控制需要特權 SMC 輔助程式。流衡透過無需 root 的 HID 路徑讀取溫度，不安裝背景常駐程式。",
    "流衡（Lumeth）只在本机读取系统计数器、IOKit 统计与无需权限的 HID 温度事件。无分析上报，也不发起网络请求。": "流衡（Lumeth）只在本機讀取系統計數器、IOKit 統計與無需權限的 HID 溫度事件。無分析上報，也不發起網路請求。",
    "采样与吞吐": "取樣與吞吐",
    "采样 %.0f ms": "取樣 %.0f ms",
    "采样": "取樣",
    "正在采集进程…": "正在收集程序…",
    "历史范围": "歷史區間",
    "活跃接口": "使用中的網路介面",
    "智能提醒": "智慧提醒",
    "本机地址": "本機位址",
    "主接口": "主要介面",
    "全机平均": "全機平均",
    "均值 %@": "平均值 %@",
}

ZH_HANS_OVERRIDES = {
    "内存简": "内存",
}

RAIL_MEMORY = {
    "ja": "メモリ",
    "ko": "메모리",
    "fr": "Mémoire",
    "de": "Speicher",
    "es": "Memoria",
    "it": "Memoria",
    "pt-BR": "Memória",
    "ru": "Память",
    "ar": "ذاكرة",
    "hi": "मेमोरी",
    "th": "หน่วยความจำ",
    "vi": "Bộ nhớ",
    "id": "Memori",
    "tr": "Bellek",
    "pl": "Pamięć",
}

LOCALE_RULES = {
    "ja": [
        ("ルメス", "Lumeth"),
        ("終わり", "完了"),
        ("高架", "高め"),
        ("致命的", "重大"),
        ("%d センサー · ルートなし", "%d 個のセンサー · root 不要"),
    ],
    "ko": [
        ("루메스", "Lumeth"),
        ("회로망", "네트워크"),
        ("비판적인", "심각"),
        ("알려지지 않은", "알 수 없음"),
        ("%d 센서 · 루트 없음", "%d개 센서 · root 불필요"),
    ],
    "fr": [
        ("Luméth", "Lumeth"),
        ("Fait", "Terminé"),
        ("Normale", "Normal"),
        ("Capteurs %d · pas de racine", "%d capteurs · sans root"),
    ],
    "de": [
        ("Erinnerung", "Arbeitsspeicher"),
    ],
    "es": [
        ("%d sensores · sin raíz", "%d sensores · sin root"),
    ],
    "it": [
        ("%d sensori · nessuna radice", "%d sensori · senza root"),
    ],
    "pt-BR": [
        ("%d sensores · sem raiz", "%d sensores · sem root"),
        ("Senta-se contra o entalhe em repouso.", "Fica junto ao entalhe em repouso."),
    ],
    "ru": [
        ("Люмета", "Lumeth"),
        ("Люмет", "Lumeth"),
        ("Нехватка памяти", "Давление памяти"),
        ("%d датчики · нет корня", "%d датчиков · без root"),
        ("Сделанный", "Готово"),
    ],
    "ar": [
        ("لوميث", "Lumeth"),
        ("شديد الأهمية", "حرج"),
        ("%d مجسات · لا يوجد جذر", "%d مستشعرات · بدون root"),
        ("منتهي", "تم"),
    ],
    "hi": [
        ("लुमेथ", "Lumeth"),
        ("याद", "मेमोरी"),
        ("सिंहावलोकन", "अवलोकन"),
        ("ऊपर उठाया हुआ", "उच्च"),
        ("कोई रूट नहीं", "बिना root"),
        ("हो गया", "पूर्ण"),
    ],
    "th": [
        ("ลูเมธ", "Lumeth"),
        ("ไม่มีการรูท", "ไม่ต้องใช้ root"),
    ],
    "vi": [
        ("Ký ức", "Bộ nhớ"),
        ("Ký Ức", "Bộ nhớ"),
        ("Phê bình", "Nghiêm trọng"),
    ],
    "id": [
        ("Ingatan", "Memori"),
        ("Sensor %d · tanpa root", "%d sensor · tanpa root"),
    ],
    "tr": [
        ("%d sensörleri · kök yok", "%d sensör · root yok"),
        ("Tamamlamak", "Tamam"),
    ],
    "pl": [
        ("Edytor", "Procesor"),
        ("Podniesiony", "Podwyższony"),
        ("%d czujniki · brak roota", "%d czujników · bez roota"),
        ("Zrobione", "Gotowe"),
    ],
}

LOCALE_OVERRIDES = {
    "ja": {
        "内存压力：%@": "メモリ負荷: %@",
        "%@ 可用": "%@ 空き",
        "负载 %.2f · %.2f · %.2f": "負荷 %.2f · %.2f · %.2f",
        "处理器核心最高": "CPU コア最高温度",
        "%d天 %02d:%02d": "%d日 %02d:%02d",
        "热度": "熱",
        "流衡设置": "Lumeth 設定",
        "待机贴合刘海；点击展开完整面板。点击外部或按 Esc 收回。": "ノッチに沿って常時表示されます。クリックでパネルを開きます。外側をクリックするか Esc で閉じます。",
        "收起面板": "パネルを閉じる",
        "持续时间": "継続時間",
    },
    "ko": {
        "内存压力：%@": "메모리 압력: %@",
        "%@ 可用": "%@ 사용 가능",
        "负载 %.2f · %.2f · %.2f": "부하 %.2f · %.2f · %.2f",
        "处理器核心最高": "CPU 코어 최고 온도",
        "%d天 %02d:%02d": "%d일 %02d:%02d",
        "热度": "열",
        "待机贴合刘海；点击展开完整面板。点击外部或按 Esc 收回。": "노치에 항상 표시됩니다. 클릭하면 전체 패널이 열립니다. 바깥을 클릭하거나 Esc를 누르면 닫힙니다.",
        "收起面板": "패널 접기",
        "历史范围": "기록 범위",
        "持续时间": "지속 시간",
    },
    "fr": {
        "%@ 可用": "%@ libres",
        "%d天 %02d:%02d": "%dj %02d:%02d",
        "热度": "Thermique",
        "运行 %@": "Durée de fonctionnement %@",
        "待机贴合刘海；点击展开完整面板。点击外部或按 Esc 收回。": "Reste accolé à l’encoche. Cliquez pour ouvrir le panneau complet. Cliquez à l’extérieur ou appuyez sur Échap pour fermer.",
        "收起面板": "Réduire le panneau",
    },
    "de": {
        "%@ 可用": "%@ frei",
        "负载 %.2f · %.2f · %.2f": "Last %.2f · %.2f · %.2f",
        "%d天 %02d:%02d": "%dT %02d:%02d",
        "热度": "Thermik",
        "采样 %.0f ms": "Abtastung %.0f ms",
        "采样与吞吐": "Abtastung und Durchsatz",
        "采样": "Abtastung",
        "收起面板": "Panel einklappen",
        "历史范围": "Verlaufszeitraum",
    },
    "es": {
        "%@ 可用": "%@ disponibles",
        "%d天 %02d:%02d": "%dd %02d:%02d",
        "热度": "Térmica",
        "收起面板": "Contraer panel",
    },
    "it": {
        "%@ 可用": "%@ disponibili",
        "%d天 %02d:%02d": "%dg %02d:%02d",
        "热度": "Termica",
        "进程排行": "Processi principali",
        "收起面板": "Comprimi pannello",
    },
    "pt-BR": {
        "%@ 可用": "%@ livres",
        "负载 %.2f · %.2f · %.2f": "Carga %.2f · %.2f · %.2f",
        "%d天 %02d:%02d": "%dd %02d:%02d",
        "热度": "Térmica",
        "收起面板": "Recolher painel",
    },
    "ru": {
        "内存压力：%@": "Давление памяти: %@",
        "%@ 可用": "%@ свободно",
        "负载 %.2f · %.2f · %.2f": "Нагрузка %.2f · %.2f · %.2f",
        "%d天 %02d:%02d": "%dд %02d:%02d",
        "热度": "Термальное",
        "采样 %.0f ms": "Замер %.0f мс",
        "采样": "Замер",
        "待机贴合刘海；点击展开完整面板。点击外部或按 Esc 收回。": "В режиме ожидания прилегает к вырезу. Нажмите, чтобы открыть панель. Нажмите вне панели или Esc, чтобы закрыть.",
        "收起面板": "Свернуть панель",
    },
    "ar": {
        "%@ 可用": "%@ متاحة",
        "负载 %.2f · %.2f · %.2f": "الحمل %.2f · %.2f · %.2f",
        "处理器总占用": "استخدام CPU",
        "实时态势": "حالة مباشرة",
        "处理器核心最高": "أعلى حرارة CPU",
        "传感": "حساسات",
        "%d天 %02d:%02d": "%d يوم %02d:%02d",
        "热度": "الحرارة",
        "待机贴合刘海；点击展开完整面板。点击外部或按 Esc 收回。": "يلتصق بالشق في وضع السكون. انقر لفتح اللوحة الكاملة. انقر خارجها أو اضغط Esc للإغلاق.",
        "收起面板": "طي اللوحة",
        "历史范围": "نطاق السجل",
    },
    "hi": {
        "%@ 可用": "%@ उपलब्ध",
        "%d天 %02d:%02d": "%dदिन %02d:%02d",
        "热度": "तापीय",
        "待机贴合刘海；点击展开完整面板。点击外部或按 Esc 收回。": "नॉच के साथ हमेशा दिखता है। पूरा पैनल खोलने के लिए क्लिक करें। बाहर क्लिक करें या Esc दबाकर बंद करें।",
        "收起面板": "पैनल समेटें",
    },
    "th": {
        "%@ 可用": "%@ ว่าง",
        "处理器核心最高": "อุณหภูมิแกน CPU สูงสุด",
        "进程排行": "โปรเซสอันดับต้น",
        "%d天 %02d:%02d": "%dวัน %02d:%02d",
        "热度": "ความร้อน",
        "运行 %@": "เวลาทำงาน %@",
        "关于本机": "เกี่ยวกับ Mac เครื่องนี้",
        "待机贴合刘海；点击展开完整面板。点击外部或按 Esc 收回。": "แสดงชิดกับรอยบากตลอดเวลา คลิกเพื่อเปิดแผงเต็ม คลิกด้านนอกหรือกด Esc เพื่อปิด",
        "收起面板": "ย่อแผง",
        "历史范围": "ช่วงเวลาย้อนหลัง",
    },
    "vi": {
        "%@ 可用": "%@ trống",
        "处理器核心最高": "Nhiệt độ lõi CPU cao nhất",
        "进程排行": "Tiến trình hàng đầu",
        "%d天 %02d:%02d": "%dngày %02d:%02d",
        "热度": "Nhiệt",
        "待机贴合刘海；点击展开完整面板。点击外部或按 Esc 收回。": "Luôn bám sát phần khuyết. Nhấn để mở toàn bộ bảng điều khiển. Nhấn ra ngoài hoặc Esc để đóng.",
        "收起面板": "Thu gọn bảng",
    },
    "id": {
        "%@ 可用": "%@ tersedia",
        "负载 %.2f · %.2f · %.2f": "Beban %.2f · %.2f · %.2f",
        "%d天 %02d:%02d": "%dhari %02d:%02d",
        "热度": "Termal",
        "待机贴合刘海；点击展开完整面板。点击外部或按 Esc 收回。": "Menempel pada notch saat diam. Klik untuk membuka panel penuh. Klik di luar atau tekan Esc untuk menutup.",
        "收起面板": "Ciutkan panel",
        "历史范围": "Rentang riwayat",
    },
    "tr": {
        "%@ 可用": "%@ boş",
        "负载 %.2f · %.2f · %.2f": "Yük %.2f · %.2f · %.2f",
        "%d天 %02d:%02d": "%dgün %02d:%02d",
        "热度": "Termal",
        "待机贴合刘海；点击展开完整面板。点击外部或按 Esc 收回。": "Bekleme durumunda çentikle birleşir. Paneli açmak için tıklayın. Dışarı tıklayın veya Esc ile kapatın.",
        "收起面板": "Paneli daralt",
    },
    "pl": {
        "%@ 可用": "%@ wolne",
        "负载 %.2f · %.2f · %.2f": "Obciążenie %.2f · %.2f · %.2f",
        "%d天 %02d:%02d": "%dd %02d:%02d",
        "热度": "Termika",
        "进程排行": "Najaktywniejsze procesy",
        "流衡设置": "Ustawienia Lumeth",
        "待机贴合刘海；点击展开完整面板。点击外部或按 Esc 收回。": "W spoczynku przylega do wycięcia. Kliknij, aby otworzyć panel. Kliknij poza nim lub naciśnij Esc, aby zamknąć.",
        "收起面板": "Zwiń panel",
        "处理器持续偏高": "Utrzymujące się wysokie obciążenie CPU",
    },
}


def source_keys():
    keys = []
    for path in sorted(glob.glob(os.path.join(ROOT, "Sources", "Pulse", "*.swift"))):
        text = open(path, encoding="utf-8").read()
        for match in re.finditer(r'"((?:[^"\\]|\\.)*)"', text):
            value = match.group(1)
            if re.search(r"[\u4e00-\u9fff]", value) and value not in keys:
                keys.append(value)
    return keys


def translate_batch(texts, target):
    query = [("client", "dict-chrome-ex"), ("sl", "en"), ("tl", target)]
    query.extend(("q", text) for text in texts)
    url = "https://translate.googleapis.com/translate_a/t?" + urllib.parse.urlencode(query)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=30) as response:
                payload = json.loads(response.read().decode("utf-8"))
            if isinstance(payload, list) and len(payload) == len(texts):
                return payload
        except Exception as error:
            print(f"  translation retry {attempt + 1}: {error}", file=sys.stderr)
        time.sleep(1.0 + attempt)
    return None


def protect_formats(text):
    tokens = []

    def replace(match):
        tokens.append(match.group(0))
        return f"__FMT{len(tokens) - 1}__"

    protected = FORMAT_RE.sub(replace, text)
    return protected, tokens


def restore_formats(text, tokens):
    result = text
    for index, token in enumerate(tokens):
        marker = f"__FMT{index}__"
        if marker not in result:
            return None
        result = result.replace(marker, token)
    if "__FMT" in result:
        return None
    return result


def translate_locale(keys, target, cache):
    pending = [key for key in keys if key not in cache]
    for start in range(0, len(pending), 18):
        batch = pending[start:start + 18]
        protected = []
        tokens = []
        for key in batch:
            text, found = protect_formats(EN[key])
            protected.append(text)
            tokens.append(found)
        translated = translate_batch(protected, target)
        if translated is None:
            print(f"  failed batch for {target} at {start}", file=sys.stderr)
            continue
        for key, value, found in zip(batch, translated, tokens):
            restored = restore_formats(value, found)
            if restored is None:
                restored = EN[key]
            cache[key] = restored
        time.sleep(0.12)


def translate_text(text, target):
    protected, tokens = protect_formats(text)
    translated = translate_batch([protected], target)
    if not translated:
        return text
    restored = restore_formats(translated[0], tokens)
    return restored or text


def escape(value):
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def write_strings(locale, values):
    folder = os.path.join(RESOURCES, f"{locale}.lproj")
    os.makedirs(folder, exist_ok=True)
    lines = ["/* Lumeth localizations */"]
    for key in sorted(values):
        lines.append(f'"{escape(key)}" = "{escape(values[key])}";')
    with open(os.path.join(folder, "Localizable.strings"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def write_info_plist(locale, description, copyright_text, display_name):
    folder = os.path.join(RESOURCES, f"{locale}.lproj")
    os.makedirs(folder, exist_ok=True)
    values = {
        "CFBundleDisplayName": display_name,
        "CFBundleName": display_name,
        "NSLocalNetworkUsageDescription": description,
        "NSHumanReadableCopyright": copyright_text,
    }
    lines = ["/* Lumeth bundle strings */"]
    for key, value in values.items():
        lines.append(f'"{escape(key)}" = "{escape(value)}";')
    with open(os.path.join(folder, "InfoPlist.strings"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def traditional_values(keys):
    payload = json.dumps({key: key for key in keys}, ensure_ascii=False).encode("utf-8")
    script = os.path.join(ROOT, "scripts", "convert_traditional.swift")
    result = subprocess.run(
        ["swift", script], input=payload, capture_output=True, check=True
    )
    return json.loads(result.stdout.decode("utf-8"))


def polish(locale, key, value):
    if key == "内存简" and locale in RAIL_MEMORY:
        return RAIL_MEMORY[locale]
    value = re.sub(r"\bLumet\b", "Lumeth", value)
    for source, target in LOCALE_RULES.get(locale, []):
        value = value.replace(source, target)
    value = LOCALE_OVERRIDES.get(locale, {}).get(key, value)
    return value


def main():
    keys = source_keys()
    missing = [key for key in keys if key not in EN]
    extra = [key for key in EN if key not in keys]
    if missing:
        print("Missing English translations:", missing, file=sys.stderr)
        sys.exit(1)
    if extra:
        print("Unused English keys:", extra, file=sys.stderr)

    cache = {}
    if os.path.exists(CACHE):
        cache = json.load(open(CACHE, encoding="utf-8"))

    for locale, target in LOCALES:
        if locale == "en":
            values = {key: EN[key] for key in keys}
        elif locale == "zh-Hans":
            values = {key: ZH_HANS_OVERRIDES.get(key, key) for key in keys}
        elif locale == "zh-Hant":
            converted = traditional_values(keys)
            values = {}
            for key in keys:
                value = converted.get(key, key)
                for source, replacement in ZH_HANT_RULES:
                    value = value.replace(source, replacement)
                values[key] = ZH_HANT_OVERRIDES.get(key, value)
        else:
            cache.setdefault(locale, {})
            translate_locale(keys, target, cache[locale])
            values = {
                key: polish(locale, key, cache[locale].get(key, EN[key]))
                for key in keys
            }
        write_strings(locale, values)

        if locale == "zh-Hans":
            description = "流衡只读取本机网卡的流量计数来显示网络活动，不扫描也不连接其他设备。"
            copyright_text = "Lumeth · 独立原生系统监控，与 iStat Menus 无关联。"
            display_name = "流衡"
        elif locale == "zh-Hant":
            description = "流衡只讀取本機網卡的流量計數來顯示網路活動，不掃描也不連線其他裝置。"
            copyright_text = "Lumeth · 獨立原生系統監控，與 iStat Menus 無關聯。"
            display_name = "流衡"
        elif locale == "en":
            description = INFO_DESCRIPTION
            copyright_text = INFO_COPYRIGHT
            display_name = "Lumeth"
        else:
            if "__network_usage" not in cache[locale]:
                cache[locale]["__network_usage"] = translate_text(
                    INFO_DESCRIPTION, target
                )
            if "__copyright" not in cache[locale]:
                cache[locale]["__copyright"] = translate_text(
                    INFO_COPYRIGHT, target
                )
            description = polish(
                locale, "__network_usage", cache[locale]["__network_usage"]
            )
            copyright_text = polish(
                locale, "__copyright", cache[locale]["__copyright"]
            )
            display_name = "Lumeth"
        write_info_plist(locale, description, copyright_text, display_name)
        print(f"{locale}: {len(values)} strings")

    with open(CACHE, "w", encoding="utf-8") as handle:
        json.dump(cache, handle, ensure_ascii=False, indent=2, sort_keys=True)


if __name__ == "__main__":
    main()

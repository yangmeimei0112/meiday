# Original User Request

## 2026-10-08T13:46:18Z

打造一套名為 ChronoHub 的原生跨平台（iOS、Android、Windows、macOS、Web）雙引擎智慧行事曆與時間中樞。本專案為完全免費、自用與朋友圈共享的高水準開源專案，規格與 UX 依大眾級商業旗艦水準設計。系統整合完整帳戶認證體系（零摩擦訪客模式、Email/密碼與 Magic Link 優先，本機實體分庫隔離，多設備 Session 管理），結合「生活協作引擎（TimeTree/FamCal/Cupla 模式：多空間日曆、事件鏡像投射、行程內留言相片、家庭採買分工清單、未定靈感池）」與「個人專注引擎（TickTick/Structured/Sunsama 模式：任務日曆化拖拽、中英混打 NLP、跨平台多態離線 OCR 轉行程、工時負載條、番茄鐘白噪音）」，並實作帶防護欄的「雙軌制錨定排程（Auto-Cascade）」。

Working directory: C:\Users\yaco9\.gemini\antigravity\scratch\smart_calendar_hub
Integrity mode: development

參考規範與詳細規格文件：C:\Users\yaco9\.gemini\antigravity\brain\f27d335d-0335-4f2a-be39-4982970385e9\calendar_app_prd.md

## Requirements

### R1. 使用者認證與本機實體分庫隔離 (Authentication & Account Management)
實作「零摩擦訪客模式（Local-First Guest）」打開即用；第一階段優先實作 Email/密碼與 Magic Link 免密碼認證，後續無縫擴充 Google 與 Apple 社交登入；本機 SQLite 採使用者實體分庫（`guest.db` 與 `user_${uid}.db`）杜絕共用裝置資料外洩；實作訪客資料無痛歸戶與衝突裁決機制；支援多設備在線清單與遠端踢出。

### R2. 跨平台畫布與雙軌抗崩潰排程 (The Anti-Fragile Time Canvas)
採用 Flutter 實作涵蓋月視圖、週視圖與垂直視覺時間軸（Visual Timeline），支援將待辦任務直接拖拽至時間區塊（Time-blocking）。排程採雙軌制（錨定事件鎖定不可推擠，彈性區塊超時自動順延並壓縮緩衝區，若空間不足彈出非阻塞建議橫幅）；內建全域操作復原堆疊（`Ctrl+Z` / `Cmd+Z` Undo）與每日工時負載條（Daily Capacity Bar）。

### R3. 生活協作與事件鏡像投射 (Social Engine & Linked Mirroring)
實作多獨立行事曆空間（個人/伴侶/家庭/小組），支援「事件鏡像投射（同一事件勾選多空間自動關聯同步，免除重複輸入）」；每個行程卡片內建討論留言、相片附件與分工採買清單（Checklist），並具備未定靈感池（Keep）與多人空檔熱力圖。

### R4. 跨平台多態智慧輸入與 GTD 專注套件 (Multimodal Capture & Focus Suite)
支援中英自然語言輸入語意解析（NLP）；實作跨平台多態離線 OCR 拍照識別行程（行動端採用 Google ML Kit，Windows 桌面端採用原生 WinRT `OcrEngine`，0 元成本且離線隱私）；內建任務關聯番茄鐘與白噪音播放；實作三層通知調和機制（在線端秒銷、推播 Collapse ID 覆蓋、喚醒批次對齊）。

### R5. 務實本機優先 (Local-First) 架構與原生生態整合
採用本機 Drift (SQLite) 作為單一真理來源，搭配 Outbox 離線寫入佇列與 LWW 版本戳記；雲端採用 Supabase (PostgreSQL + Realtime + RLS) 達成零成本（Free Tier）即時同步；原生生態層採分工設計：行動端採用 `home_widget` 與今日 JSON 快照共享（記憶體 <5MB），Windows/macOS 桌面端採用 `system_tray` 實作常駐托盤 Mini 浮動日曆與全域速記熱鍵（`Win+Shift+C`）；外部日曆採用行動端中繼代理（Mobile Relay）雙向橋接。

## Fallback Plans (備用方案)
1. **資料同步備用**：若離線佇列遇極端邊界，採用帶 UUID 冪等鍵的批次 RPC 變更隊列（Idempotent RPC Queue），免自架 WAL 中間件。
2. **AI OCR 備用**：若離線 OCR 遇到複雜混亂排版，在設定頁提供使用者自備金鑰（BYOK）接入雲端大模型視覺解析。
3. **外部日曆桌面端備用**：若無手機中繼，桌面端直接採用 Google OAuth 測試模式（支援最多 100 位朋友帳號，免 CASA 審查）。

## Verification Resources
多代理人團隊需於 `test/` 目錄建立自動化驗證套件：
1. `test/unit/`：Auth Token 輪轉與安全儲存單元測試、排程雙軌錨定與緩衝壓縮演算法單元測試、NLP 語意時間解析測試、Outbox 離線佇列 LWW 合併測試、實體分庫切換測試。
2. `test/widget/`：登入/註冊介面流程測試、Flutter 畫布渲染與手勢拖拽 Widget 測試、托盤面板組件測試。
3. `test/integration/`：訪客升級帳號無痛歸戶整合測試、斷網離線寫入後連網增量同步整合測試。

## Acceptance Criteria

### 帳戶安全與跨平台流暢度
- [ ] 支援未登入訪客模式直接使用全功能，登入後本機數據 100% 自動無痛歸戶至新帳號且零遺失；登出時能徹底切換分庫，絕不洩漏上一位使用者的日程。
- [ ] 支援查看所有已登入設備清單，並能成功遠端踢出其他設備 Session。
- [ ] 支援在 iOS、Android、Windows、macOS 與 Web 上一致運行，時間軸縮放與拖拽手勢維持 60fps+ 流暢無掉幀。
- [ ] 執行 `flutter test`，核心排程演算法、Auth 邏輯、Outbox 隊列與 NLP 解析測試通過率為 100%。

### 核心功能與痛點根除
- [ ] 具備「事件鏡像投射」能力，同一事件勾選多個共享空間時，任一空間更新皆能即時反映在所有關聯空間，徹底消除重複輸入。
- [ ] 行動端與 Windows 桌面端均能在完全斷網狀態下，利用本機 OCR 引擎識別相片/截圖文字並自動提取時間填入行程。
- [ ] 彈性排程遇到錨定事件時能正確壓縮緩衝區，當空間不足時能主動提示而不擅自破壞外部既定會議；支援全域 `Ctrl+Z` 復原。
- [ ] Windows 桌面端關閉主視窗能最小化常駐至系統托盤，點擊托盤圖示能在 0.2 秒內彈出 Mini 日曆與待辦核銷視窗。

## 2026-10-09T11:08:55Z

伺服器重啟已恢復。請繼續執行 ChronoHub 開發工作，目前處於 Milestone M1 驗證與推進階段。
已完成 intl 依賴項版本修復、SyncOutboxTable 的 targetTable 衝突修復，以及 build_runner 重新生成 Drift 代碼。
請專案協調團隊繼續推進 M1 對抗審查與質量閘門簽核，並順利推進後續里程碑 M2！

## 2026-10-09T20:35:14Z

配額已重置恢復。請接續進度：M1 已通關結案（159 項全綠且 0 warnings）。請接續推進 Milestone M2（Features #14-#24：月/週/垂直時間軸視圖、Time-blocking 拖拽、Auto-Cascade 雙軌排程、非阻塞衝突橫幅、每日工時負載條、全域 Undo/Redo、Ctrl+K 命令面板、60 秒梳理儀式）。請啟動 Worker 與審查團隊落地 M2 核心引擎與視覺畫布，並部署監控。

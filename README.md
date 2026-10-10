# ⏱️ ChronoHub (跨平台雙引擎智慧行事曆與時間中樞)

<p align="center">
  <img src="windows/runner/resources/app_icon.ico" width="96" height="96" alt="ChronoHub Logo" />
</p>

<p align="center">
  <strong>完全免費開源（FOSS）· 零付費牆 · 大眾級旗艦體驗 · 本機優先 Local-First · 跨平台雙引擎時間中樞</strong>
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-blue.svg?logo=flutter" alt="Flutter"></a>
  <a href="https://drift.simonbinder.eu"><img src="https://img.shields.io/badge/Database-Drift%20(SQLite)-00897B.svg" alt="Drift"></a>
  <a href="https://supabase.com"><img src="https://img.shields.io/badge/Cloud-Supabase%20RLS-3ECF8E.svg?logo=supabase" alt="Supabase"></a>
  <a href="https://github.com"><img src="https://img.shields.io/badge/Tests-302%2F302%20Passing%20(100%25)-brightgreen.svg" alt="Tests"></a>
  <a href="https://github.com"><img src="https://img.shields.io/badge/Analyze-0%20Issues-brightgreen.svg" alt="Analyze"></a>
  <a href="https://vercel.com"><img src="https://img.shields.io/badge/Deploy-Vercel%20Ready-black.svg?logo=vercel" alt="Vercel"></a>
</p>

---

## 🌟 核心理念與專案亮點

ChronoHub 旨在打破市場現有軟體（如 TimeTree、TickTick、Structured）的付費牆與功能割裂，專為自用、伴侶、家庭與工作協作設計：

1. **零付費牆 & 零摩擦**：打開即用訪客模式（Local-First Guest），本機資料安全實體分庫隔離（`guest.db` vs `user_${sha256(uid)}.db`）。
2. **生活協作引擎（Social Engine）**：多空間日曆、事件鏡像投射（同一行程勾選多空間即時連動，徹底消除重複輸入）、卡片內專屬留言串、分工採買清單、多人空檔熱力圖。
3. **個人專注引擎（GTD Focus Engine）**：Time-Blocking 拖拽排程、雙軌抗脆弱排程（錨定會議不可撼動、彈性區塊超時自動壓縮緩衝）、全域 `Ctrl+Z` 復原、番茄鐘與白噪音播放。
4. **多態智慧輸入**：中英混打自然語言解析（NLP），跨平台多態離線 OCR 識別（Windows WinRT / 行動端 Google ML Kit，0 成本且 100% 隱私）。
5. **本機優先雲端同步**：Outbox 離線變更佇列 + LWW 版本仲裁 + Supabase (PostgreSQL + RLS) 零成本即時同步。
6. **桌面常駐原生生態**：Windows 系統托盤 <0.2s 秒開 Mini 日曆、全域 `Win+Shift+C` 快捷鍵速記、行動端 HomeWidget 快照。

---

## 📐 系統技術架構

```
lib/
├── app/                  # 應用程式入口、GoRouter 路由守衛、全域主題樣式
├── core/
│   ├── database/         # Drift SQLite 引擎、連線工廠、多租戶分庫與歸戶遷移
│   ├── platform/         # 跨平台抽象層 (WinRT OCR / Tray / Audio / SecureStorage)
│   └── utils/            # 雜湊演算法、時鐘、全域工具
└── features/
    ├── auth/             # 訪客模式、Email/Magic Link、實體分庫切換、多設備在線清單
    ├── calendar/         # 月/週/時間軸畫布、雙軌排程、緩衝壓縮、Undo 堆疊、工時負載條
    ├── social/           # 獨立空間、事件鏡像投射、討論留言、相片附件、靈感池、空檔熱力圖
    ├── capture/          # 中英混打 NLP 自然語言解析、WinRT / MLKit 多態離線 OCR、BYOK 備用
    ├── focus/            # 任務關聯番茄鐘、白噪音環境音效循環、三層通知調和
    └── sync/             # Outbox 佇列、LWW 衝突裁決、Supabase RLS、系統托盤 Mini 日曆
```

---

## 🧪 品質驗證指標（Quality Gates）

- **自動化測試套件**：**302 項測試 100% 通過（0 失敗）**，涵蓋單元測試、元件測試、E2E 全生命週期測試與極限對抗測試。
- **靜態代碼分析**：`flutter analyze` 達到 **0 Errors, 0 Warnings, 0 Infos (No issues found!)**。
- **代碼誠信原則**：生產代碼 **0 偽造（No Fake/Mock facade）、0 TODO**，所有核心邏輯皆為真實演算法實作。

---

## 🚀 快速開始

### 環境需求
- [Flutter SDK](https://flutter.dev) (>= 3.19.0)
- Dart SDK (>= 3.3.0)

### 1. 取得專案並安裝套件
```bash
git clone https://github.com/<your-username>/smart_calendar_hub.git
cd smart_calendar_hub
flutter pub get
```

### 2. 執行自動化測試
```bash
flutter test
```

### 3. 執行靜態分析
```bash
flutter analyze
```

### 4. 啟動應用
- **啟動 Windows 桌面版**：
  ```bash
  flutter run -d windows
  ```
- **啟動 Chrome Web 版**：
  ```bash
  flutter run -d chrome
  ```

---

## ☁️ 部署到 Vercel (Web 版)

本專案已內建 `vercel.json` 與 GitHub Actions 部署工作流（`.github/workflows/deploy.yml`）。

### 方式 A：透過 GitHub 自動部署（推薦）
1. 將本專案推送至 GitHub。
2. 前往 [Vercel 儀表板](https://vercel.com/new) ➔ 點擊 **Import Git Repository** ➔ 選擇本專案。
3. 設定 Framework Preset 為 **Other**，Output Directory 為 `build/web`。
4. 點擊 **Deploy**，日後每次推送代碼即可自動構建並發布上線！

### 方式 B：本地使用 Vercel CLI 發布
```bash
# 1. 建置 Web 版產物
flutter build web --release

# 2. 發布至 Vercel
npx vercel --prod
```

---

## 📄 開源授權

本專案採用 [MIT License](LICENSE) 授權條款，完全免費、開源、自由使用。
